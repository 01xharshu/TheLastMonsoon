extends SceneTree
const Trunks = preload("res://world/suryagarh/tree_trunk_collision.gd")
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failed = true; push_error(message)
func body(parent: Node3D, label: String, at: Vector3, size: Vector3) -> StaticBody3D:
	var value := StaticBody3D.new()
	value.name = label
	value.position = at
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	value.add_child(collision)
	parent.add_child(value)
	return value
func run() -> void:
	for extra in [0,1,2]:
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_colors = extra > 0
		batch.use_custom_data = extra > 1
		batch.instance_count = 24
		for index in batch.instance_count:
			batch.set_instance_transform(index,Transform3D(Basis(Vector3.UP,index*.17).scaled(Vector3(.7,1.3,2)),Vector3(index*2,3,index*-4)))
		var decoded := Trunks.instance_transforms(batch)
		for index in batch.instance_count:
			check(decoded[index] == batch.get_instance_transform(index),"Packed tree transform changed with color/custom stride")
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var ground := body(world,"GroundCollision",Vector3(0,-.5,0),Vector3(100,1,100))
	var exclusions: Array[RID] = []
	for index in 4000:
		var obstacle := body(world,"Scenery",Vector3(index%80-40,1,index/80-25),Vector3(.5,2,.5))
		exclusions.append(obstacle.get_rid())
	Trunks.configure_terrain_support(world)
	check(ground.collision_layer & 1 == 1,"Terrain lost gameplay collision layer")
	await physics_frame
	await physics_frame
	var original := PhysicsRayQueryParameters3D.new()
	original.exclude = exclusions
	original.collision_mask = 1
	var filtered := PhysicsRayQueryParameters3D.new()
	filtered.collision_mask = Trunks.TERRAIN_SUPPORT_LAYER
	var expected: Array = []
	var actual: Array = []
	var queries: Array[Vector3] = []
	for index in 100: queries.append(Vector3(index%10-5,20,index/10-5))
	var space := world.get_world_3d().direct_space_state
	var started := Time.get_ticks_usec()
	for point in queries:
		original.from = point
		original.to = point-Vector3.UP*50
		expected.append(space.intersect_ray(original))
	var original_us := Time.get_ticks_usec()-started
	started = Time.get_ticks_usec()
	for point in queries:
		filtered.from = point
		filtered.to = point-Vector3.UP*50
		actual.append(space.intersect_ray(filtered))
	var filtered_us := Time.get_ticks_usec()-started
	for index in queries.size():
		check(not expected[index].is_empty() and not actual[index].is_empty(),"Terrain support ray missed")
		if expected[index].is_empty() or actual[index].is_empty(): continue
		check(expected[index].position == actual[index].position and expected[index].normal == actual[index].normal and expected[index].rid == actual[index].rid,"Terrain-only ray changed support")
	print("TERRAIN SUPPORT ",JSON.stringify({"status":"FAIL" if failed else "PASS","queries":queries.size(),"excluded_bodies":exclusions.size(),"original_us":original_us,"filtered_us":filtered_us}))
	await root.get_node("SaveManager").quit_game(1 if failed else 0)
