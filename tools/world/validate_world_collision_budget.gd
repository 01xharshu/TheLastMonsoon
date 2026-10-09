extends SceneTree
## Load without current_scene, then prove the final road markers have collision.
var failed := false
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var world: Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	for frame in 4: await physics_frame
	var flags: Node3D=world.get_node("RoadsideFlags")
	check(flags.ready_for_review and flags.placements.size()==8,"Roadside flags did not finish installation")
	var space:=world.get_world_3d().direct_space_state
	for marker in flags.placements:
		var centre: Vector3=marker.global_position+Vector3.UP*.7
		var query:=PhysicsRayQueryParameters3D.create(centre-Vector3.RIGHT*.4,centre+Vector3.RIGHT*.4,1)
		var hit:=space.intersect_ray(query)
		check(not hit.is_empty() and hit.collider==marker,"Flag physics body missing: "+str(marker.name))
	var count:=world.find_children("*","PhysicsBody3D",true,false).size()+world.find_children("*","Area3D",true,false).size()
	var limit: int=ProjectSettings.get_setting("physics/jolt_physics_3d/limits/max_bodies")
	check(count<limit,"World exceeded its physics-body budget")
	print("WORLD COLLISION BUDGET: ","FAIL" if failed else "PASS"," | collision objects ",count," / ",limit," | eight roadside colliders checked; current_scene unset")
	await root.get_node("SaveManager").quit_game(1 if failed else 0)
