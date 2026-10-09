extends SceneTree
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var layout = Layout.new()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Node3D = load("res://world/suryagarh/generated/landscape.scn").instantiate()
	viewport.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.47,.59,.68)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.8,.85,.95)
	env.environment.ambient_light_energy = .65
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40,-30,0)
	scene.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 65
	scene.add_child(camera)
	camera.make_current()
	var tall_bank := 0
	var tall_verge := 0
	var bank_trees := 0
	var total := 0
	var root_samples := 0
	var max_root_error := 0.0
	var best := Vector3.ZERO
	var best_score := -INF
	for tile in scene.get_node("NatureTiles").get_children():
		var parts: PackedStringArray = str(tile.name).split("_")
		if parts.size()!=3 or not parts[1].is_valid_int(): continue
		var terrain: MeshInstance3D = scene.get_node("TerrainTiles/Terrain_"+parts[1]+"_"+parts[2])
		var vertices: PackedVector3Array = terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var step: float = vertices[1].x-vertices[0].x
		for batch in tile.get_children():
			if not batch is MultiMeshInstance3D: continue
			var core := str(batch.name).begins_with("GrassCore")
			var tree := str(batch.name).begins_with("BroadleafTrees")
			if not core and not tree: continue
			for i in batch.multimesh.instance_count:
				var tr: Transform3D = batch.multimesh.get_instance_transform(i)
				var p: Vector3 = tile.position+tr.origin
				var bank: float = absf(p.x-layout.river_x(p.z))-layout.river_width(p.z)
				if tree:
					if bank > 5 and bank < 80: bank_trees += 1
					continue
				total += 1
				assert(preload("res://world/suryagarh/grass_blades.gd").placement_allowed(layout,Vector2(p.x,p.z),layout.height(p.x,p.z),layout.road_distance(p.x,p.z)),"Grass violates house/road/crop/water exclusion")
				if i % 16 == 0:
					var surface: Transform3D = preload("res://world/suryagarh/grass_blades.gd").baked_frame(vertices,Vector2(tile.position.x,tile.position.z),Vector2(p.x,p.z),step,Layout.TILE)
					var error: float = absf(p.y-(surface.origin.y-.018))
					max_root_error = maxf(max_root_error,error)
					root_samples += 1
					assert(error < .002,"Grass root detached from rendered terrain")
					assert(surface.basis.z.cross(surface.basis.x).normalized().y >= .779,"Grass on steep cut")
				if tr.basis.y.length()>2.5:
					if bank > 5 and bank < 72:
						tall_bank += 1
						var score: float = tr.basis.y.length()-absf(p.z-150)*.002
						if score > best_score:
							best = p
							best_score = score
					else: tall_verge += 1
	assert(tall_bank>100 and tall_verge>100 and bank_trees>0)
	print("HABITAT PASS tufts=",total," tall_bank=",tall_bank," tall_offroad=",tall_verge," bank_trees=",bank_trees," root_samples=",root_samples," root_error=",max_root_error," view=",best)
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	assert(not output.is_empty(),"Provide temporary --output directory")
	DirAccess.make_dir_recursive_absolute(output)
	camera.position = best+Vector3(-5,1.7,-5)
	camera.look_at(best+Vector3(3,.55,3))
	for i in 12: await process_frame
	RenderingServer.force_draw()
	viewport.get_texture().get_image().save_png(output+"/bank.png")
	camera.position = best+Vector3(-18,6,-18)
	camera.look_at(best)
	for i in 12: await process_frame
	RenderingServer.force_draw()
	viewport.get_texture().get_image().save_png(output+"/wide.png")
	# Controlled motion stimulus exercises the same group used by live carts.
	var wind: Node = root.get_node("WindSystem")
	wind.set_process(false)
	RenderingServer.global_shader_parameter_set("world_wind",Vector3.ZERO)
	camera.position = best+Vector3(-5,1.7,-5)
	camera.look_at(best+Vector3(3,.55,3))
	for i in 8: await process_frame
	RenderingServer.force_draw()
	viewport.get_texture().get_image().save_png(output+"/rest.png")
	var vehicle := Node3D.new()
	scene.add_child(vehicle)
	vehicle.position = best+Vector3(-5,0,0)
	vehicle.add_to_group("cart_parking_vehicles")
	for i in 90:
		vehicle.position.x += .0666667
		await process_frame
	var motion: Node = root.get_node("GrassMotion")
	var peak := 0.0
	for slot in motion.slots: peak = maxf(peak,slot.strength)
	assert(peak > .4,"Moving vehicle did not excite grass")
	RenderingServer.force_draw()
	viewport.get_texture().get_image().save_png(output+"/vehicle.png")
	for i in 180: await process_frame
	var residual := 0.0
	for slot in motion.slots: residual = maxf(residual,slot.strength)
	assert(residual < .02,"Grass did not recover after vehicle stopped")
	RenderingServer.global_shader_parameter_set("world_wind",Vector3(3,1.2,1))
	for i in 8: await process_frame
	RenderingServer.force_draw()
	viewport.get_texture().get_image().save_png(output+"/wind.png")
	print("MOTION PASS moving_strength=",peak," stopped_residual=",residual)
	wind.set_process(true)
	viewport.queue_free()
	await process_frame
	await root.get_node("SaveManager").quit_game(0)
