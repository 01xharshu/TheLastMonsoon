extends SceneTree
## Run with Godot --headless --path . --script tools/characters/validate_animation.gd
func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	var player = world.get_node("Player")
	var visual = player.get_node("VisualRoot/CharacterVisual")
	player.set_physics_process(false)
	world.set_physics_process(false)
	for i in 5: await physics_frame
	assert(visual.bones.has("hand_r"))
	var p: Vector3 = player.position
	player.position = Vector3(world.layout.river_x(0), -0.3, 0)
	world._physics_process(0.016)
	assert(player.is_swimming)
	for i in 60: visual._process(1.0 / 60.0)
	assert(visual.swim_blend > 0.99)
	assert(not visual.weapon.visible)
	player.velocity = Vector3.ZERO
	player._apply_gravity(0.1)
	assert(player.velocity.y > 0, "Buoyancy must lift a submerged player")
	player.position.y = 3.0
	world._physics_process(0.016)
	assert(not player.is_swimming, "A bridge above deep water must not activate swimming")
	player.position = p
	for i in 60: visual._process(1.0 / 60.0)
	assert(visual.weapon.visible)
	assert(visual.swim_blend < 0.01)
	for i in visual.skeleton.get_bone_count():
		assert(visual.skeleton.get_bone_pose_rotation(i).is_normalized())
	print("ANIMATION / WATER TRANSITIONS: PASS")
	quit()
