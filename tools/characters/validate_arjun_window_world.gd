extends Node3D
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := preload("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	add_child(world)
	for i in 4: await get_tree().physics_frame
	var actor: CharacterBody3D = world.get_node("Player")
	actor.set_physics_process(false)
	var climb: Node = actor.get_node("ClimbComponent")
	climb.set_physics_process(false)
	var windows := get_tree().get_nodes_in_group("climbable_windows")
	var accepted := 0
	for portal in windows:
		var normal: Vector3 = portal.global_basis.x.normalized()
		var at: Vector3 = portal.global_position+normal*.9
		var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP,at-Vector3.UP*2.0)
		query.exclude = [actor.get_rid()]
		var floor_hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
		if floor_hit.is_empty(): continue
		actor.global_position = Vector3(at.x,floor_hit.position.y+.94,at.z)
		actor.visual_root.global_rotation.y = atan2(-normal.x,-normal.z)
		if not climb.window.try_start(actor): continue
		accepted += 1
		for frame in 97: climb.window.advance(actor,1.0/30.0)
		if actor.collision_mask==0 or actor.get_meta("climbing",false):
			push_error("WINDOW WORLD: state restore failed")
			get_tree().quit(1)
			return
	print("WINDOW WORLD: ","PASS" if windows.size()==8 and accepted>0 else "FAIL"," | registered=",windows.size()," traversable=",accepted)
	get_tree().quit(0 if windows.size()==8 and accepted>0 else 1)
