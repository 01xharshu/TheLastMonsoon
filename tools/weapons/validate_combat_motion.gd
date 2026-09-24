extends SceneTree
## Mechanical regression only; the current Arjun appearance is owner-rejected.
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ")+label)
	if not value: failures += 1
func run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 5: await physics_frame
	var actor: CharacterBody3D = world.get_node("Player")
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	var combat: Node = actor.get_node("CombatInput")
	var slash: Node = actor.get_node("TalwarSlash")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	actor.inventory.add_item("talwar",1)
	visual.equipment.stowed = false
	visual.equipment.selected = 0
	visual.equipment._refresh()
	check(slash.available(),"land combat is available")
	check(visual.equipment.owns(0),"sword in inventory")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	combat._unhandled_input(click)
	check(combat.pending_single and slash.elapsed >= slash.DURATION,"first click waits for double-click window")
	combat._unhandled_input(click)
	check(not combat.pending_single and combat.kick_time >= 0.0 and slash.elapsed >= slash.DURATION,"double click kicks without slashing")
	combat.kick_time = -1.0
	visual.kick_phase = -1.0
	combat._unhandled_input(click)
	combat._process(combat.DOUBLE_CLICK_SECONDS+.01)
	check(slash.elapsed < slash.DURATION,"single click starts sword slash")
	slash._process(.35)
	check(visual.slash_phase >= 0.0,"sword strike phase reaches visual")
	for phase in [.1,.25,.4,.55,.7,.85]:
		visual.slash_phase=phase
		visual._process(1.0/60.0)
		print("SWORD TIP ",phase," ",visual.equipment.talwar_hand.to_global(Vector3(.78,.06,0))-actor.global_position)
	var marker := StaticBody3D.new()
	marker.set_script(load("res://world/suryagarh/cuttable_flag.gd"))
	world.add_child(marker)
	marker.global_position = actor.global_position+Vector3(0,0,-2)
	var flag: Node3D = load("res://assets/props/flags/eic/prop_eic_checkpoint_flag_01.glb").instantiate()
	marker.add_child(flag)
	flag.scale = Vector3.ONE*.55
	marker.bind_visual()
	var pole_collision := CollisionShape3D.new()
	var pole_shape := CylinderShape3D.new()
	pole_shape.radius = .05
	pole_shape.height = 2.475
	pole_collision.shape = pole_shape
	marker.add_child(pole_collision)
	check(marker.cut_flag(),"first flag strike splits pole")
	check(marker.fallen_top != null and marker.fallen_top is RigidBody3D,"upper pole becomes falling rigid body")
	check(marker.find_child("BrokenPoleStump",false,false) != null,"lower stump remains")
	check(not marker.cut_flag(),"flag cannot award a second cut")
	for i in 15: await physics_frame
	check(marker.fallen_top.global_position.y < marker.global_position.y+1.9,"severed upper pole falls")
	print("COMBAT MOTION ","PASS" if failures==0 else "FAIL "+str(failures))
	quit(1 if failures else 0)
