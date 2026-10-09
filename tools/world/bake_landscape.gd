extends SceneTree
## Offline terrain/nature bake. Runtime loads saved meshes; no synchronous generation in gameplay.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const OUT: String = "res://world/suryagarh/generated/"
var layout = Layout.new()
var world := Node3D.new()
var rng := RandomNumberGenerator.new()
var terrain_material: ShaderMaterial
var nature_meshes: Dictionary = {}
var tree_count: int = 0
var rock_count: int = 0
var grass_count: int = 0

func _initialize() -> void:
	call_deferred("bake")

func attach(node: Node, parent: Node) -> void:
	parent.add_child(node)
	node.owner = world

func save_resource(resource: Resource, file: String) -> void:
	var err: Error = ResourceSaver.save(resource, OUT + file, ResourceSaver.FLAG_COMPRESS)
	assert(err == OK, "Failed to save " + file)
	if file == "landscape.scn" and err == OK:
		# Larger Zstandard blocks retain identical resource bytes while keeping the
		# dense grass bake below GitHub's regular Git limit without Git LFS.
		var temporary := OS.get_temp_dir().path_join("tlm-landscape-%d.scn" % OS.get_process_id())
		var result: Dictionary = preload("res://tools/maintenance/recompress_godot_resource.gd").recompress(OUT + file, temporary)
		if result.is_empty():
			DirAccess.remove_absolute(temporary)
			push_error("Lossless landscape recompression failed; original bake retained.")
			quit(1)
			return
		if int(result.after_bytes) >= 100 * 1024 * 1024:
			DirAccess.remove_absolute(temporary)
			push_error("Landscape still exceeds regular Git limit; split resources before committing.")
			quit(1)
			return
		# Copy works when OS temp and the checkout are on different filesystems.
		err = DirAccess.copy_absolute(temporary, ProjectSettings.globalize_path(OUT + file))
		DirAccess.remove_absolute(temporary)
		assert(err == OK, "Failed to install recompressed landscape")
		print("LANDSCAPE LOSSLESS COMPRESSION ", result)

func bake() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Bake requires a real rendering device to serialize MultiMesh buffers. Run without --headless.")
		quit(1)
		return
	var start: int = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(OUT)
	rng.seed = 1857
	world.name = "Landscape"
	if "--fort-road-patch" in OS.get_cmdline_user_args():
		refresh_fort_road(start)
		return
	if "--grass-only" in OS.get_cmdline_user_args():
		refresh_grass(start)
		return
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = load("res://world/suryagarh/shaders/terrain.gdshader")
	terrain_material.set_shader_parameter("road_mask_tex", bake_road_mask())
	for pair in [["soil", "brown_mud_dry"], ["grass", "aerial_grass_rock"], ["rock", "rock_boulder_dry"]]:
		terrain_material.set_shader_parameter(pair[0] + "_tex", load("res://assets/nature/materials/" + pair[1] + "_diff_1k.jpg"))
		terrain_material.set_shader_parameter(pair[0] + "_normal", load("res://assets/nature/materials/" + pair[1] + "_nor_gl_1k.jpg"))
	save_resource(terrain_material, "terrain_material.tres")
	for slug in ["island_tree_02", "boulder_01"]:
		var model: Node = load("res://assets/nature/models/" + slug + ".glb").instantiate()
		var instances: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
		assert(not instances.is_empty())
		var mesh_instance: MeshInstance3D = instances[0] as MeshInstance3D
		nature_meshes[slug] = mesh_instance.mesh
		# Explicit material bounds for leaf shadows/roughness, no alpha blending.
		for s in mesh_instance.mesh.get_surface_count():
			var mat: StandardMaterial3D = mesh_instance.mesh.surface_get_material(s) as StandardMaterial3D
			if mat:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR if "leaves" in mat.resource_name else BaseMaterial3D.TRANSPARENCY_DISABLED
				mat.alpha_scissor_threshold = 0.35
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				mat.roughness = 0.88
		model.free()
	nature_meshes["grass_bermuda_01"] = preload("res://world/suryagarh/grass_blades.gd").make_mesh()
	nature_meshes["grass_detail"] = preload("res://world/suryagarh/grass_blades.gd").make_mesh(true)
	var terrain := Node3D.new()
	terrain.name = "TerrainTiles"
	attach(terrain, world)
	var nature := Node3D.new()
	nature.name = "NatureTiles"
	attach(nature, world)
	for tz in 12:
		for tx in 12:
			var origin := Vector2(-Layout.HALF + tx * Layout.TILE, -Layout.HALF + tz * Layout.TILE)
			bake_tile(origin, tx, tz, terrain)
			bake_nature(origin, tx, tz, nature)
		print("BAKE ROW ", tz + 1, "/12")
	bake_water()
	bake_horizon()
	var sites := Node3D.new()
	sites.name = "FutureSiteReserves"
	attach(sites, world)
	for site_name in Layout.SITES:
		var p: Vector2 = Layout.SITES[site_name]
		var marker := Marker3D.new()
		marker.name = site_name.replace(" ", "_")
		marker.position = Vector3(p.x, layout.height(p.x, p.y), p.y)
		marker.set_meta("status", "Terrain reservation only; no building or gameplay implemented")
		attach(marker, sites)
	var packed := PackedScene.new()
	assert(packed.pack(world) == OK)
	save_resource(packed, "landscape.scn")
	var report := {"area_km2": Layout.SIZE * Layout.SIZE / 1000000.0, "dimensions_m": [Layout.SIZE, Layout.SIZE],
		"tiles": 144, "terrain_spacing_m": Layout.STEP, "fort_tile_spacing_m": 1.5, "trees": tree_count, "rocks": rock_count,
		"grass_clumps": grass_count, "seed": 1857, "bake_seconds": (Time.get_ticks_msec() - start) / 1000.0,
		"architecture": "Resident terrain with automatic mesh LOD; spatial MultiMesh batches and visibility ranges. No runtime world streaming yet."}
	var file := FileAccess.open("res://docs/world/bake_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("LANDSCAPE BAKE PASS ", JSON.stringify(report))
	world.free()
	quit()

func bake_road_mask() -> ImageTexture:
	# Layout is the sole route authority; the terrain shader samples this raster
	# instead of maintaining a second hand-written copy of every road equation.
	const PIXELS := 1024
	var image := Image.create(PIXELS, PIXELS, false, Image.FORMAT_L8)
	for z in PIXELS:
		for x in PIXELS:
			var p := (Vector2(x+0.5,z+0.5)/PIXELS-Vector2.ONE*0.5)*Layout.SIZE
			var d: float = layout.road_distance(p.x,p.y)
			image.set_pixel(x,z,Color(1.0-smoothstep(2.0,4.8,d),0,0))
	var texture := ImageTexture.create_from_image(image)
	save_resource(texture,"road_mask.res")
	return texture

func bake_tile(origin: Vector2, tx: int, tz: int, parent: Node3D) -> void:
	# Keep the fort and its hairpin access at 1.5 m collision samples.
	var grid_size: int = 96 if tx in [9,10] and tz in [3,4] else Layout.GRID
	var step_size: float = Layout.TILE / grid_size
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var heights := PackedFloat32Array()
	var indices := PackedInt32Array()
	for z in grid_size + 1:
		for x in grid_size + 1:
			var p := origin + Vector2(x, z) * step_size
			var h: float = layout.height(p.x, p.y)
			var n: Vector3 = layout.normal(p.x, p.y)
			vertices.append(Vector3(x * step_size, h, z * step_size))
			normals.append(n)
			var tangent: Vector3 = Vector3(n.y, -n.x, 0).normalized()
			tangents.append_array(PackedFloat32Array([tangent.x, tangent.y, tangent.z, 1.0]))
			uvs.append(p / 8.0)
			heights.append(h / step_size)
	for z in grid_size:
		for x in grid_size:
			var a: int = z * (grid_size + 1) + x
			var b: int = a + 1
			var c: int = a + grid_size + 1
			indices.append_array(PackedInt32Array([a, b, c, b, c + 1, c]))
	# Skirts hide LOD differences between independently simplified neighboring tiles.
	for edge in 4:
		for k in grid_size:
			var a: int
			var b: int
			match edge:
				0: a = k; b = k + 1
				1: a = k * (grid_size + 1) + grid_size; b = (k + 1) * (grid_size + 1) + grid_size
				2: a = grid_size * (grid_size + 1) + k + 1; b = a - 1
				_: a = (k + 1) * (grid_size + 1); b = k * (grid_size + 1)
			var ia: int = vertices.size()
			for id in [a, b]:
				vertices.append(vertices[id] - Vector3(0, 5, 0))
				normals.append(normals[id]); uvs.append(uvs[id])
				tangents.append_array(PackedFloat32Array([1, 0, 0, 1]))
			indices.append_array(PackedInt32Array([a, ia, b, b, ia, ia + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, terrain_material)
	importer.generate_lods(60.0, 60.0, [])
	var mesh: ArrayMesh = importer.get_mesh()
	save_resource(mesh, "tile_%02d_%02d.res" % [tx, tz])
	var tile := MeshInstance3D.new()
	tile.name = "Terrain_%02d_%02d" % [tx, tz]
	tile.mesh = mesh
	tile.position = Vector3(origin.x, 0, origin.y)
	tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	attach(tile, parent)
	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	attach(body, tile)
	var shape := HeightMapShape3D.new()
	shape.map_width = grid_size + 1
	shape.map_depth = grid_size + 1
	shape.map_data = heights
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.scale = Vector3.ONE * step_size
	collision.position = Vector3(Layout.TILE / 2, 0, Layout.TILE / 2)
	attach(collision, body)

func multimesh_batch(mesh: Mesh, transforms: Array[Transform3D], parent: Node3D, batch_name: String, distance: float) -> void:
	if transforms.is_empty(): return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size(): mm.set_instance_transform(i, transforms[i])
	assert(mm.buffer.size() == transforms.size() * 12, "MultiMesh transforms were not stored")
	var instance := MultiMeshInstance3D.new()
	instance.name = batch_name
	instance.multimesh = mm
	instance.lod_bias = 8.0 if batch_name == "BroadleafTrees" else 1.0
	instance.visibility_range_end = distance
	instance.visibility_range_end_margin = 4.0 if batch_name.begins_with("Grass") else 25.0
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if batch_name.begins_with("Grass") else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	attach(instance, parent)

func bake_nature(origin: Vector2, tx: int, tz: int, parent: Node3D) -> void:
	var tile := Node3D.new()
	tile.name = "Nature_%02d_%02d" % [tx, tz]
	tile.position = Vector3(origin.x, 0, origin.y)
	attach(tile, parent)
	var trees: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	for i in 34:
		var p := origin + Vector2(rng.randf_range(4, 140), rng.randf_range(4, 140))
		var h: float = layout.height(p.x, p.y)
		if layout.built_area(p.x,p.y): continue
		if absf(p.x - 620.0) < 11.0 and p.y > -160.0 and p.y < -120.0: continue
		var village_dist: float = p.distance_to(Vector2(-310, 230))
		if h < 2.6 or layout.road_distance(p.x, p.y) < 9 or village_dist < 85: continue
		var field: float = layout.field_mask(p.x, p.y)
		if field > 0.5 and rng.randf() > 0.04: continue
		if p.x < 100 and rng.randf() > 0.25: continue
		if layout.normal(p.x, p.y).y < 0.80: continue
		var size: float = rng.randf_range(1.5, 3.1)
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(size, size * rng.randf_range(0.9, 1.2), size))
		trees.append(Transform3D(basis, Vector3(p.x - origin.x, h - 0.12, p.y - origin.y)))
		var body := StaticBody3D.new()
		body.position = Vector3(p.x - origin.x, h + size * 0.8, p.y - origin.y)
		attach(body, tile)
		var shape := CylinderShape3D.new()
		shape.radius = size * 0.11
		shape.height = size * 1.8
		var collision := CollisionShape3D.new()
		collision.shape = shape
		attach(collision, body)
	for i in 12:
		var p := origin + Vector2(rng.randf_range(2, 142), rng.randf_range(2, 142))
		var h: float = layout.height(p.x, p.y)
		if layout.built_area(p.x,p.y) or layout.road_distance(p.x, p.y) < 7 or layout.field_mask(p.x, p.y) > 0.3 or p.distance_to(Vector2(-310,230)) < 100: continue
		if h < -1.0 or (h < 15 and rng.randf() > 0.35): continue
		var size: float = rng.randf_range(0.45, 1.8)
		var transform := Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(size, size * 0.8, size)), Vector3(p.x - origin.x, h - size * 0.4, p.y - origin.y))
		rocks.append(transform)
		var body := StaticBody3D.new()
		body.transform = transform
		attach(body, tile)
		var collision := CollisionShape3D.new()
		collision.shape = (nature_meshes["boulder_01"] as Mesh).create_convex_shape(true, true)
		attach(collision, body)
	multimesh_batch(nature_meshes["island_tree_02"], trees, tile, "BroadleafTrees", 1400)
	multimesh_batch(nature_meshes["boulder_01"], rocks, tile, "Boulders", 650)
	tree_count += trees.size()
	rock_count += rocks.size()
	bake_grass(origin,tx,tz,tile)

func bake_grass(origin: Vector2,tx: int,tz: int,tile: Node3D) -> void:
	# 18 m batches keep nearby detail from drawing whole 36 m patches.
	var terrain_tile: MeshInstance3D = world.get_node("TerrainTiles/Terrain_%02d_%02d" % [tx,tz])
	var ground_vertices: PackedVector3Array = terrain_tile.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var sampling_step := ground_vertices[1].x-ground_vertices[0].x
	var grass_rng := RandomNumberGenerator.new()
	grass_rng.seed = 1857+tx*149+tz*1879
	for gz in 8:
		for gx in 8:
			var grass: Array[Transform3D] = []
			for i in 384:
				var p := origin + Vector2(gx*18+grass_rng.randf_range(0,18),gz*18+grass_rng.randf_range(0,18))
				var h: float = layout.height(p.x,p.y)
				var road_distance: float = layout.road_distance(p.x,p.y)
				var grass_rules = preload("res://world/suryagarh/grass_blades.gd")
				if not grass_rules.placement_allowed(layout,p,h,road_distance): continue
				var cover: float = grass_rules.habitat_density(layout,p,road_distance)
				if grass_rng.randf() > cover: continue
				var size := Vector3(grass_rng.randf_range(.85,1.2),grass_rng.randf_range(.7,1.25),grass_rng.randf_range(.85,1.2))
				var habitat: float = preload("res://world/suryagarh/grass_blades.gd").habitat_height(layout,p,road_distance)
				size.y *= habitat
				# Long growth spreads into wider, bending tussocks rather than thin poles.
				var spread: float = 1.0+(habitat-1.0)*.65
				size.x *= spread
				size.z *= spread
				var frame := preload("res://world/suryagarh/grass_blades.gd").baked_frame(ground_vertices,origin,p,sampling_step,Layout.TILE)
				var ground_normal: Vector3 = frame.basis.z.cross(frame.basis.x).normalized()
				if ground_normal.y < .78: continue # Bare steep cuts and rock faces.
				frame.origin -= Vector3(origin.x,.018,origin.y)
				frame.basis = frame.basis*Basis(Vector3.UP,grass_rng.randf_range(0,TAU)).scaled(size)
				grass.append(frame)
			grass_count += grass.size()
			multimesh_batch(nature_meshes["grass_bermuda_01"],grass,tile,"GrassCore_%d_%d" % [gx,gz],85)
			multimesh_batch(nature_meshes["grass_detail"],grass,tile,"GrassDetail_%d_%d" % [gx,gz],45)

func bake_water() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 1000:
		var z: float = -1440.0 + k * 8.0
		var points: Array[Vector3] = []
		for dz in [0.0, 8.0]:
			var zz: float = z + dz
			for side in [-1.0, 1.0]:
				points.append(Vector3(layout.river_x(zz) + side * (layout.river_width(zz) + 36), Layout.WATER_LEVEL, zz))
		for id in [0, 1, 2, 1, 3, 2]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(points[id].x, points[id].z) / 8)
			st.add_vertex(points[id])
	st.generate_tangents()
	var material := ShaderMaterial.new()
	material.shader = load("res://world/suryagarh/shaders/river.gdshader")
	st.set_material(material)
	var water := MeshInstance3D.new()
	water.name = "RiverSurface"
	water.mesh = st.commit()
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.set_meta("swimming_status", "Surface swimming enabled; transparent water and riverbed collision")
	attach(water, world)

func bake_horizon() -> void:
	# Coarse non-playable continuation keeps the map edge out of the ground-level skyline.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-4320, 4320, 96):
		for x in range(-4320, 4320, 96):
			if x >= -864 and x < 864 and z >= -864 and z < 864: continue
			for offset in [Vector2(0,0),Vector2(96,0),Vector2(0,96),Vector2(96,0),Vector2(96,96),Vector2(0,96)]:
				var p: Vector2 = Vector2(x,z) + offset
				st.set_normal(layout.normal(p.x,p.y))
				st.set_uv(p/8)
				st.add_vertex(Vector3(p.x,layout.height(p.x,p.y),p.y))
	st.generate_tangents()
	st.set_material(terrain_material)
	var horizon := MeshInstance3D.new()
	horizon.name = "DistantTerrain_NoCollision"
	horizon.mesh = st.commit()
	horizon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	attach(horizon, world)

func refresh_grass(start: int) -> void:
	# Preserve every existing tree, rock, collision, route and reserved plot.
	world.free()
	world = load(OUT+"landscape.scn").instantiate()
	nature_meshes["grass_bermuda_01"] = preload("res://world/suryagarh/grass_blades.gd").make_mesh()
	nature_meshes["grass_detail"] = preload("res://world/suryagarh/grass_blades.gd").make_mesh(true)
	for tile in world.get_node("NatureTiles").get_children():
		var parts: PackedStringArray = str(tile.name).split("_")
		if parts.size()!=3 or parts[0]!="Nature" or not parts[1].is_valid_int() or not parts[2].is_valid_int(): continue
		for child in tile.get_children():
			if str(child.name).begins_with("Grass"): child.free()
		bake_grass(Vector2(tile.position.x,tile.position.z),int(parts[1]),int(parts[2]),tile)
		print("GRASS TILE ",tile.name)
	var packed := PackedScene.new()
	assert(packed.pack(world)==OK)
	save_resource(packed,"landscape.scn")
	var report := {"tufts":grass_count,"core_blades":6,"near_detail_blades":18,"batch_width_m":18,"core_fade_m":[48,70],"detail_fade_m":[18,30],"simulation_nodes":0,"root_burial_m":.018,"bake_seconds":(Time.get_ticks_msec()-start)/1000.0,"scope":"grass-only; other landscape content retained"}
	print("GRASS BAKE PASS ",JSON.stringify(report))
	world.free()
	quit()

func refresh_fort_road(start: int) -> void:
	# Grade edits are confined to tile 9,4. Retain every other world tile/site.
	world.free()
	world = load(OUT+"landscape.scn").instantiate()
	terrain_material = load(OUT+"terrain_material.tres")
	for batch in world.get_node("NatureTiles").find_children("*","MultiMeshInstance3D",true,false):
		if str(batch.name).begins_with("GrassCore"): nature_meshes["grass_bermuda_01"] = batch.multimesh.mesh
		elif str(batch.name).begins_with("GrassDetail"): nature_meshes["grass_detail"] = batch.multimesh.mesh
		if nature_meshes.has("grass_bermuda_01") and nature_meshes.has("grass_detail"): break
	var origin := Vector2(-Layout.HALF+9*Layout.TILE,-Layout.HALF+4*Layout.TILE)
	var old_tile: MeshInstance3D = world.get_node("TerrainTiles/Terrain_09_04")
	var old_vertices: PackedVector3Array = old_tile.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var step := old_vertices[1].x-old_vertices[0].x
	old_tile.free()
	bake_tile(origin,9,4,world.get_node("TerrainTiles"))
	var new_tile: MeshInstance3D = world.get_node("TerrainTiles/Terrain_09_04")
	var vertices: PackedVector3Array = new_tile.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var boundary_error := 0.0
	for i in old_vertices.size():
		var point: Vector3 = old_vertices[i]
		if point.x==0 or point.x==Layout.TILE or point.z==0 or point.z==Layout.TILE:
			boundary_error = maxf(boundary_error,absf(vertices[i].y-point.y))
	assert(boundary_error < .0001,"Road patch changed an external tile edge")
	var nature: Node3D = world.get_node("NatureTiles/Nature_09_04")
	var shifted := 0
	var max_shift := 0.0
	for node in nature.get_children():
		if str(node.name).begins_with("Grass"):
			node.free()
			continue
		if node is MultiMeshInstance3D:
			for i in node.multimesh.instance_count:
				var pose: Transform3D = node.multimesh.get_instance_transform(i)
				var point := origin+Vector2(pose.origin.x,pose.origin.z)
				var old_y: float = preload("res://world/suryagarh/grass_blades.gd").baked_frame(old_vertices,origin,point,step,Layout.TILE).origin.y
				var new_y: float = preload("res://world/suryagarh/grass_blades.gd").baked_frame(vertices,origin,point,step,Layout.TILE).origin.y
				pose.origin.y += new_y-old_y
				node.multimesh.set_instance_transform(i,pose)
				max_shift = maxf(max_shift,absf(new_y-old_y))
				if absf(new_y-old_y) > .00001: shifted += 1
		elif node is StaticBody3D:
			var point := origin+Vector2(node.position.x,node.position.z)
			var old_y: float = preload("res://world/suryagarh/grass_blades.gd").baked_frame(old_vertices,origin,point,step,Layout.TILE).origin.y
			var new_y: float = preload("res://world/suryagarh/grass_blades.gd").baked_frame(vertices,origin,point,step,Layout.TILE).origin.y
			node.position.y += new_y-old_y
	bake_grass(origin,9,4,nature)
	var packed := PackedScene.new()
	assert(packed.pack(world)==OK)
	save_resource(packed,"landscape.scn")
	var report := {"tile":"09_04","boundary_height_change_m":boundary_error,"shifted_nature_instances":shifted,"maximum_nature_height_adjustment_m":max_shift,"grass_tufts_in_tile":grass_count,"bake_seconds":(Time.get_ticks_msec()-start)/1000.0,"scope":"one existing terrain tile/collision and its rooted vegetation; all other tiles and sites retained"}
	FileAccess.open("res://docs/world/fort_road_patch_2026-10-08.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("FORT ROAD PATCH ",JSON.stringify(report))
	world.free()
	quit()
