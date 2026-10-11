extends SceneTree
## Native near/far appearance and packed-record parity; no retained test output.
const Compact = preload("res://world/suryagarh/broadleaf_render_records.gd")
const Trunks = preload("res://world/suryagarh/tree_trunk_collision.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=="headless": push_error("Compaction pixels require native rendering");quit(1);return
	var packed: PackedScene=load("res://world/suryagarh/generated/landscape.scn")
	var state := packed.get_state()
	var source: MultiMesh
	var candidate: MultiMesh
	for node in state.get_node_count():
		if not str(state.get_node_name(node)).begins_with("BroadleafTrees"): continue
		for property in state.get_node_property_count(node):
			if state.get_node_property_name(node,property)!=&"multimesh": continue
			var mesh: MultiMesh=state.get_node_property_value(node,property)
			var reduced := Compact.compact(mesh)
			if reduced.instance_count>0 and reduced.instance_count<mesh.instance_count: source=mesh;candidate=reduced;break
		if source!=null: break
	assert(source!=null,"No sparse established broadleaf batch found")
	var stride := 12+(4 if source.use_colors else 0)+(4 if source.use_custom_data else 0)
	var slots: PackedInt32Array=candidate.get_meta("render_source_slots")
	var original := source.buffer
	var reduced := candidate.buffer
	for index in slots.size():
		for component in stride: assert(reduced[index*stride+component]==original[slots[index]*stride+component],"Compaction changed retained rendering input")
	assert(candidate.mesh==source.mesh and candidate.get_aabb()==source.get_aabb(),"Compaction changed geometry/bounds")
	var originals := Trunks.instance_transforms(source)
	var retained := Trunks.instance_transforms(candidate)
	var active: Array[Transform3D]=[]
	for transform in originals:
		if not is_zero_approx(transform.basis.determinant()): active.append(transform)
	assert(active==retained,"Compaction changed physical tree transforms")
	var viewport := SubViewport.new()
	viewport.size=Vector2i(960,540)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.mesh_lod_threshold=1.0
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var batch := MultiMeshInstance3D.new()
	batch.multimesh=source
	batch.lod_bias=8.0
	world.add_child(batch)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-45,-30,0)
	sun.shadow_enabled=true
	world.add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.2,.3,.4)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=.5
	world.add_child(environment)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	var center: Vector3=retained[0].origin
	var pixels_exact := true
	for distance in [17.0,120.0]:
		camera.position=center+Vector3(distance*.6,8,distance)
		camera.look_at(center+Vector3.UP*5)
		var images: Array[Image]=[]
		var counts: Array=[]
		for mesh in [source,candidate,source]:
			batch.multimesh=mesh
			for frame in 30: await process_frame
			await RenderingServer.frame_post_draw
			images.append(viewport.get_texture().get_image())
			counts.append(viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
		var equal := images[0].get_data()==images[1].get_data()
		var repeat_equal := images[0].get_data()==images[2].get_data()
		pixels_exact=pixels_exact and equal
		print("GEOMETRY COMPACTION PIXELS ",JSON.stringify({"distance":distance,"equal":equal,"repeat_equal":repeat_equal,"visible_primitives":counts,"candidate_metrics":images[0].compute_image_metrics(images[1],false),"repeat_metrics":images[0].compute_image_metrics(images[2],false)}))
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--review-dir="):
				var directory := argument.trim_prefix("--review-dir=")
				assert(directory.is_absolute_path() and directory.get_file().begins_with("tlm-performance-"))
				for index in images.size(): images[index].save_png(directory.path_join("compact_"+str(int(distance))+"_"+str(index)+".png"))
	print("GEOMETRY COMPACTION INPUT PARITY PASS ",JSON.stringify({"original_records":source.instance_count,"retained_records":candidate.instance_count,"exact_buffers":true,"exact_bounds":true,"physical_transforms_equal":true,"native_near_far_pixels_equal":pixels_exact,"visual_acceptance":"manual quantified review required if pixels differ"}))
	viewport.queue_free()
	await process_frame
	await root.get_node("SaveManager").quit_game()
