extends SceneTree
## Real imported cow: array-presence parity, native pixels and alternating query cost.
const Visual = preload("res://animals/cow_visual.gd")
const Cow = preload("res://assets/animals/cow/household_cow.glb")
var failed := false
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
func median(values: Array[int]) -> int:
	values.sort()
	return values[values.size()/2]
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960,540)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var cow: Node3D = Cow.instantiate()
	scene.add_child(cow)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.18,.23,.28)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .5
	scene.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40,-30,0)
	scene.add_child(sun)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(3,1.7,3)
	camera.look_at(Vector3(0,.8,0))
	camera.make_current()
	var coats: Array[Dictionary] = []
	var surfaces := 0
	for node: MeshInstance3D in cow.find_children("*","MeshInstance3D",true,false):
		for index in node.mesh.get_surface_count():
			var arrays := node.mesh.surface_get_arrays(index)
			var expected: bool = arrays[Mesh.ARRAY_COLOR] != null and not arrays[Mesh.ARRAY_COLOR].is_empty()
			check(expected == ((node.mesh.surface_get_format(index)&Mesh.ARRAY_FORMAT_COLOR)!=0), "Colour-format mismatch: "+str(node.name))
			surfaces += 1
			var material := node.get_active_material(index) as StandardMaterial3D
			if material != null and "grey coat" in material.resource_name:
				coats.append({"node":node,"index":index,"mesh":node.mesh,"expected":expected})
	check(not coats.is_empty(),"No real cow coat surfaces checked")
	Visual.apply(cow)
	for coat in coats:
		var material: ShaderMaterial = coat.node.get_active_material(coat.index)
		check(material.get_shader_parameter("vertex_coat") == coat.expected,"Production coat choice changed")
	# Reference decision from uploaded arrays, preserving the original material.
	for coat in coats: coat.node.get_active_material(coat.index).set_shader_parameter("vertex_coat",coat.expected)
	if DisplayServer.get_name() != "headless":
		for frame in 10: await process_frame
		await RenderingServer.frame_post_draw
		var before := viewport.get_texture().get_image()
		Visual.apply(cow)
		for frame in 10: await process_frame
		await RenderingServer.frame_post_draw
		var after := viewport.get_texture().get_image()
		check(before.get_data() == after.get_data(),"Native cow pixels changed")
		print("COW METADATA PIXEL PARITY | ",before.get_size()," | equal ",before.get_data()==after.get_data())
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--review-dir="):
				var directory := argument.trim_prefix("--review-dir=")
				check(directory.is_absolute_path() and directory.get_file().begins_with("tlm-performance-"),"Review needs temporary runner directory")
				if not failed: after.save_png(directory.path_join("cow_metadata.png"))
	var old_times: Array[int] = []
	var new_times: Array[int] = []
	var consumed := 0
	for round_index in 7:
		for reference in ([true,false] if round_index%2==0 else [false,true]):
			var start := Time.get_ticks_usec()
			for repeat in 20:
				for coat in coats:
					if reference:
						var arrays: Array = coat.mesh.surface_get_arrays(coat.index)
						consumed += int(arrays[Mesh.ARRAY_COLOR]!=null and not arrays[Mesh.ARRAY_COLOR].is_empty())
					else: consumed += int((coat.mesh.surface_get_format(coat.index)&Mesh.ARRAY_FORMAT_COLOR)!=0)
			(old_times if reference else new_times).append(Time.get_ticks_usec()-start)
	print("COW METADATA COST ",JSON.stringify({"surfaces":surfaces,"coats":coats.size(),"iterations_per_round":20,"rounds":7,"array_query_median_us":median(old_times),"metadata_query_median_us":median(new_times),"consumed":consumed,"scope":"query cost only; no whole-world hitch or FPS acceptance"}))
	print("COW METADATA: ","FAIL" if failed else "PASS")
	viewport.queue_free()
	await process_frame
	await root.get_node("SaveManager").quit_game()
