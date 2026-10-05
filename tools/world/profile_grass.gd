extends SceneTree
## Paired actual baked-landscape render profile; no NPC simulation is included.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280,720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var label := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	var report_tag := OS.get_environment("TLM_GRASS_PROFILE_TAG")
	if report_tag.is_empty(): report_tag = label
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var landscape_path := "/tmp/tlm_grass_before_landscape.scn" if label == "before" else "res://world/suryagarh/generated/landscape.scn"
	if label == "before" and not OS.get_environment("TLM_GRASS_BASELINE").is_empty(): landscape_path = OS.get_environment("TLM_GRASS_BASELINE")
	assert(FileAccess.file_exists(landscape_path),"Before profile requires the saved pre-edit landscape snapshot")
	var landscape: Node3D = load(landscape_path).instantiate()
	if label == "before": restore_baseline_shader(landscape)
	scene.add_child(landscape)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(.39,.48,.56)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(.78,.84,.93)
	environment.ambient_light_energy = .45
	env.environment = environment
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-32,0)
	sun.light_energy = 1.0
	scene.add_child(sun)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.fov = 65
	camera.far = 1500
	camera.make_current()
	var layout := Layout.new()
	var views := [
		["close",Vector3(-500,layout.height(-500,-300)+.6,-300),Vector3(-497,layout.height(-497,-303)+.12,-303)],
		["walk_height",Vector3(-500,layout.height(-500,-300)+1.65,-300),Vector3(-480,layout.height(-480,-320)+.15,-320)],
		["wide",Vector3(-510,layout.height(-510,-300)+8,-300),Vector3(-460,layout.height(-460,-350),-350)]
	]
	var results: Array = []
	for view in views:
		camera.position = view[1]
		camera.look_at(view[2])
		for i in 30: await process_frame
		var frame: Array[float] = []
		var gpu: Array[float] = []
		var cpu: Array[float] = []
		var tick := Time.get_ticks_usec()
		for i in 120:
			await process_frame
			var now := Time.get_ticks_usec()
			frame.append((now-tick)/1000.0)
			tick = now
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid()))
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()))
		RenderingServer.force_draw()
		var path: String = "res://docs/world/captures/grass_2026-10-05/"+report_tag+"_"+view[0]+".png"
		assert(viewport.get_texture().get_image().save_png(path)==OK)
		frame.sort(); gpu.sort(); cpu.sort()
		var row := {"view":view[0],"median_frame_ms":frame[60],"p95_frame_ms":frame[114],"median_gpu_ms":gpu[60],"median_render_cpu_ms":cpu[60],"primitives":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),"draw_calls":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)}
		results.append(row)
		print("GRASS PROFILE ",JSON.stringify(row))
	var total := 0
	var batches := 0
	for batch in landscape.get_node("NatureTiles").find_children("*","MultiMeshInstance3D",true,false):
		if str(batch.name).begins_with("Grass"):
			total += batch.multimesh.instance_count
			batches += 1
	var root_samples := 0
	var max_root_error := 0.0
	var root_batch := 0
	var space := scene.get_world_3d().direct_space_state
	for batch in landscape.get_node("NatureTiles").find_children("*","MultiMeshInstance3D",true,false):
		if not str(batch.name).begins_with("GrassCore"): continue
		root_batch += 1
		if root_batch % 8 != 0: continue
		var pose: Transform3D = batch.global_transform*batch.multimesh.get_instance_transform(0)
		var roots: Dictionary = {Vector3.ZERO:true}
		for v in batch.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			if absf(v.y) < .00001: roots[v] = true
		for v in roots:
			var point: Vector3 = pose*v
			var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP*2)
			var hit := space.intersect_ray(ray)
			if not hit.is_empty() and hit.collider.name == "GroundCollision":
				max_root_error = maxf(max_root_error,absf(point.y+.018-hit.position.y))
				root_samples += 1
	var report := {"label":label,"renderer":RenderingServer.get_current_rendering_driver_name(),"device":RenderingServer.get_video_adapter_name(),"resolution":[1280,720],"grass_instance_records":total,"grass_batches":batches,"root_samples":root_samples,"maximum_root_surface_error_m":max_root_error,"views":results,"scope":"actual baked terrain/nature; no buildings, humans or active gameplay; isolated rendering comparison, not full-game FPS"}
	FileAccess.open("res://docs/world/grass_"+label+"_profile.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	quit()

func restore_baseline_shader(landscape: Node3D) -> void:
	# Exact shader from the recorded Oct-01 candidate; external shader changed later.
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled, diffuse_burley;
void vertex() {
 vec3 rooted = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 float weight = clamp(VERTEX.y / 0.28,0.0,1.0);
 float breeze = sin(TIME*1.7+rooted.x*.73+rooted.z*.51);
 VERTEX.xz += vec2(0.8,0.35)*breeze*0.018*weight*weight;
}
void fragment() {
 ALBEDO = COLOR.rgb * mix(0.52,0.92,smoothstep(0.0,0.75,UV.y));
 ROUGHNESS = 0.94;
 SPECULAR = 0.12;
}"""
	for batch in landscape.get_node("NatureTiles").find_children("*","MultiMeshInstance3D",true,false):
		if str(batch.name).begins_with("Grass"):
			var mat := batch.multimesh.mesh.surface_get_material(0) as ShaderMaterial
			if mat: mat.shader = shader
