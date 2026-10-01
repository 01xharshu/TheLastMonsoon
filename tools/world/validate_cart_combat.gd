extends SceneTree
const Trace = preload("res://combat/ballistic_trace.gd")
var failures: Array[String] = []
func check(condition: bool, label: String) -> void:
	if not condition: failures.append(label); push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var cart := preload("res://vehicles/family_carriage_candidate.gd").new()
	world.add_child(cart)
	for i in 3: await physics_frame
	check(cart.combat.horses.size()==2,"two individual horses")
	check(cart.combat.panes.size()==4,"four breakable panes")
	var dummy := preload("res://tools/weapons/damage_dummy.gd").new()
	world.add_child(dummy)
	dummy.position = Vector3(.48,2.39,2.75)
	var shape := CollisionShape3D.new()
	var capsule := SphereShape3D.new(); capsule.radius=.2
	shape.shape=capsule; dummy.add_child(shape)
	for i in 3: await physics_frame
	var space := world.get_world_3d().direct_space_state
	var hit := Trace.shoot(space,self,Vector3(4,2.39,2.75),Vector3(-4,2.39,2.75),60.0,[])
	check(not hit.is_empty() and hit.collider==dummy,"window shot reaches occupant target")
	check(is_equal_approx(dummy.damage_received,55.0),"one damage event through pane")
	check(cart.combat.panes.any(func(pane): return pane.broken),"side pane breaks")
	var old_hits: float = dummy.damage_received
	Trace.shoot(space,self,Vector3(4,1.65,2.75),Vector3(-4,1.65,2.75),60.0,[])
	check(dummy.damage_received==old_hits,"opaque lower door blocks shots")
	var horse: Node = cart.combat.horses[0]
	horse.take_damage(60.0)
	check(not horse.dead and cart.can_move(),"nonlethal horse hit")
	horse.take_damage(60.0)
	check(horse.dead and not cart.can_move(),"one dead horse stops paired coach")
	cart.set_forward_motion(4.0,.2)
	check(not horse.animation.is_playing(),"dead horse animation stays stopped")
	await create_timer(1.5).timeout
	check(horse.death_finished,"horse fall completes")
	var report := {"passed":failures.is_empty(),"failures":failures,"scope":"paired horse health, glass penetration and opaque coach collision; occupant death/world routes checked separately"}
	FileAccess.open("res://docs/world/cart_combat_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CART COMBAT: ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
