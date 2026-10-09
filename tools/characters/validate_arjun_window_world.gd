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
	var open_windows := 0
	var paired := 0
	for portal in windows:
		if portal.get_parent().get_meta("window_access","") != "open": continue
		open_windows += 1
		var both := true
		for direction in [-1.0,1.0]:
			var crossed := false
			for lane in [0.0,.5,-.5]:
				if await _cross(actor,climb,portal,direction,lane):
					crossed = true
					break
			if not crossed:
				print("WINDOW WORLD blocked: ",portal.get_path()," side=",direction)
				both = false
		if both: paired += 1
	var passed := open_windows >= 8 and paired == open_windows
	print("WINDOW WORLD: ","PASS" if passed else "FAIL"," | registered=",windows.size()," open=",open_windows," crossed_both_ways=",paired)
	world.queue_free()
	for frame in 3: await get_tree().physics_frame
	get_tree().quit(0 if passed else 1)

func _cross(actor: CharacterBody3D, climb: Node, portal: Node3D, direction: float, lane: float) -> bool:
	var normal: Vector3 = portal.global_basis.x.normalized()*direction
	var at: Vector3 = portal.global_position+normal*.9+portal.global_basis.z.normalized()*lane
	var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP,at-Vector3.UP*2.0)
	query.exclude = [actor.get_rid()]
	var floor_hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if floor_hit.is_empty(): return false
	actor.global_position = Vector3(at.x,floor_hit.position.y+.94,at.z)
	actor.velocity = Vector3.ZERO
	actor.visual_root.global_rotation.y = atan2(-normal.x,-normal.z)
	await get_tree().physics_frame
	if not climb.window.try_start(actor): return false
	for frame in 240:
		climb.window.advance(actor,1.0/30.0)
		if not climb.window.active: break
	if climb.window.active or actor.collision_mask == 0 or actor.get_meta("climbing",false):
		push_error("WINDOW WORLD: crossing failed to restore collision")
		get_tree().quit(1)
		return false
	return (actor.global_position-portal.global_position).dot(normal) < -.8
