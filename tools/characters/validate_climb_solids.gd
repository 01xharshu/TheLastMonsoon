extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var wall := StaticBody3D.new()
	wall.position = Vector3(.7,2.4,0)
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4,4.8,4)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	scene.add_child(wall)
	var actor := CharacterBody3D.new()
	actor.position = Vector3(-.85,.95,0)
	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	var standing := CapsuleShape3D.new()
	standing.radius = .4
	standing.height = 1.8
	collider.shape = standing
	actor.add_child(collider)
	scene.add_child(actor)
	for i in 3: await physics_frame
	var solid := preload("res://player/climb_collision.gd").new()
	solid.begin(actor,.9)
	await physics_frame
	var entered: bool = solid.move_to(actor,Vector3(.8,.95,0),.9)
	if entered or actor.position.x > -.279 or actor.collision_mask != 1:
		push_error("CLIMB SOLIDS: body entered wall or disabled collision")
		quit(1)
		return
	if solid.finish(actor):
		push_error("CLIMB SOLIDS: standing shape expanded into wall")
		quit(1)
		return
	solid.move_to(actor,Vector3(-.85,5.35,0),.9)
	await physics_frame
	if not solid.move_to(actor,Vector3(.8,5.35,0),.9):
		push_error("CLIMB SOLIDS: clear crouched mantle was blocked")
		quit(1)
		return
	if solid.finish(actor):
		push_error("CLIMB SOLIDS: stood before legs cleared coping")
		quit(1)
		return
	solid.move_to(actor,Vector3(.8,5.75,0),.9)
	await physics_frame
	if not solid.finish(actor) or collider.shape != standing:
		push_error("CLIMB SOLIDS: standing collision was not restored")
		quit(1)
		return
	print("CLIMB SOLIDS PASS | solid wall blocks sweep; crouch clears top; standing expansion requires clearance")
	quit()
