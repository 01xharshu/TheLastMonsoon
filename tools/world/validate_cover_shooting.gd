extends SceneTree
## Actual player and pistol: an aimed shot clears low cover but not a tall wall.
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var clock: Node = load("res://world/suryagarh/systems/game_time_system.gd").new()
	clock.name = "GameTimeSystem"
	stage.add_child(clock)
	var floor := StaticBody3D.new()
	stage.add_child(floor)
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(30,.4,30)
	var floor_collision := CollisionShape3D.new()
	floor_collision.shape = floor_shape
	floor_collision.position.y = -.2
	floor.add_child(floor_collision)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	stage.add_child(actor)
	actor.position = Vector3(0,1,0)
	for i in 30: await physics_frame
	var wall := StaticBody3D.new()
	wall.name = "CoverWall"
	stage.add_child(wall)
	wall.position = Vector3(0,0,-.95)
	var shape := BoxShape3D.new()
	shape.size = Vector3(3,.90,.25)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = .45
	wall.add_child(collision)
	actor.get_node("CameraPivot").global_rotation = Vector3.ZERO
	actor.inventory.add_item("pistol",1)
	var equipment: Node3D = actor.get_node("VisualRoot/CharacterVisual").equipment
	equipment.select_weapon(3)
	var stance: Node = actor.get_node("StealthStance")
	for i in 5: await physics_frame
	var acquired: bool = stance.try_cover()
	if not acquired or stance.cover_body != wall: print("COVER PROBE ", {"can_change":stance.can_change(),"on_floor":actor.is_on_floor(),"actor":actor.global_position,"wall":wall.global_position,"facing":-actor.get_node("CameraPivot").global_basis.z,"body":stance.cover_body})
	check(acquired and stance.cover_body == wall,"Player did not take the low wall as cover")
	Input.action_press("aim")
	for i in 45: await physics_frame
	var camera: Camera3D = actor.get_node("CameraPivot/SpringArm3D/Camera3D")
	var dummy = load("res://tools/weapons/damage_dummy.gd").new()
	stage.add_child(dummy)
	var dummy_collision := CollisionShape3D.new()
	var target_shape := SphereShape3D.new()
	target_shape.radius = .6
	dummy_collision.shape = target_shape
	dummy.add_child(dummy_collision)
	dummy.global_position = camera.global_position - camera.global_basis.z*9.0
	for i in 5: await physics_frame
	var pistol: Node = actor.get_node("PistolCombat")
	check(pistol.aiming and pistol.fire(),"Pistol did not fire from low cover")
	check(dummy.damage_received > 0.0,"Aimed pistol shot did not reach the target over low cover")
	var low_damage: float = dummy.damage_received
	var grip: Dictionary = equipment.held_contact_errors()
	check(float(grip.pistol_palm_m) < .025,"Cover pose detached the pistol from the firing hand")
	shape.size.y = 2.5
	collision.position.y = 1.25
	for i in 5: await physics_frame
	dummy.damage_received = 0.0
	check(pistol.fire(),"Pistol did not fire toward the tall wall")
	check(is_zero_approx(dummy.damage_received),"Pistol shot passed through the tall wall")
	Input.action_release("aim")
	print("COVER SHOOTING ", JSON.stringify({"passed":failures.is_empty(),"low_cover_damage":low_damage,"tall_wall_damage":dummy.damage_received,"pistol_palm_m":grip.pistol_palm_m,"failures":failures}))
	await root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
