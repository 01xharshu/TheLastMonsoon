extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(12, .2, 12)
	floor_shape.shape = floor_box
	floor_shape.position.y = -.1
	floor_body.add_child(floor_shape)
	stage.add_child(floor_body)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file(ProjectSettings.globalize_path("res://characters/npcs/dev/dev_idle_candidate.glb"),state)==OK)
	var actor := CharacterBody3D.new()
	actor.set_script(load("res://characters/npcs/dev/dev_candidate.gd"))
	var figure := document.generate_scene(state) as Node3D
	figure.name = "Visual"
	actor.add_child(figure)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .24
	capsule.height = 1.72
	collision.shape = capsule
	collision.position.y = .86
	actor.add_child(collision)
	stage.add_child(actor)
	for frame in 15: await physics_frame
	assert(actor.is_on_floor())
	actor.call("face_direction",Vector3.RIGHT)
	for frame in 90: await physics_frame
	assert(absf(actor.rotation.y-PI/2)<.02)
	assert(float(actor.get("turn_blend"))<.02)
	actor.call("play_uniform_guard")
	for frame in 15: await physics_frame
	assert(bool((actor.get("motion_tree") as AnimationTree).get("parameters/guard/active")))
	for frame in 150: await physics_frame
	assert(not bool((actor.get("motion_tree") as AnimationTree).get("parameters/guard/active")))
	actor.set("walking",true)
	var origin := actor.position
	for frame in 120: await physics_frame
	assert(actor.position.distance_to(origin)>1.0)
	actor.set("walking",false)
	for frame in 30: await physics_frame
	assert(float(actor.get("blend"))<.01)
	assert(actor.is_on_floor())
	print("DEV_UNIFORM_TREE PASS: idle/walk/turn/guard recovery; floor support; travel ",actor.position.distance_to(origin))
	quit(0)
