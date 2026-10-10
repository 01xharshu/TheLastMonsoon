@tool
extends Node3D
signal generated
## Runtime vegetation. Generation is deterministic and never saved into the scene.
## Optional terrain source may implement sample_forest_height(x,z),
## sample_forest_normal(x,z), and sample_forest_biome_mask(x,z).
@export var config: ForestConfig
@export var forest_size: Vector2 = Vector2(60.0, 60.0)
@export var terrain_source: NodePath
@export var path_points: PackedVector2Array = PackedVector2Array([Vector2(-29, 0), Vector2(-10, -2), Vector2(7, 2), Vector2(29, 0)])
@export var generate_in_editor: bool = false
@export var regeneration_key: int = 0:
	set(value):
		regeneration_key = value
		if is_inside_tree() and (not Engine.is_editor_hint() or generate_in_editor): regenerate()

@export var startup_provider: Script # Optional begin/checkpoint/finish loading-session protocol.
const BOULDER = preload("res://environment/forest/assets/rock_reused.glb")
const PLACEHOLDER_PLANTS = preload("res://environment/forest/vegetation/placeholder_plants.gd")
const LAYERS := ["hero", "canopy", "canopy_broad", "small_tree", "dead_tree", "fallen_log", "fern", "shrub", "broadleaf", "tall_grass", "short_grass", "floor", "rock", "debris"]
const BASE_RATE := {"hero": 0.012, "canopy": 0.085, "canopy_broad": 0.025, "small_tree": 0.07, "dead_tree": 0.018, "fallen_log": 0.025, "fern": 0.22, "shrub": 0.24, "broadleaf": 0.20, "tall_grass": 0.30, "short_grass": 0.55, "floor": 0.32, "rock": 0.025, "debris": 0.05}
const TREE_LAYERS := ["hero", "canopy", "canopy_broad", "small_tree", "dead_tree"]

var _noise := FastNoiseLite.new()
var _floor_patch: MeshInstance3D
var _chunks: Node3D
var _meshes: Dictionary = {}
var _species: Dictionary = {}
var _lod_meshes: Dictionary = {}
var _layer_points: Dictionary = {}
var _terrain: Node
var _tree_positions: Array[Vector2] = []
var _counts: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint() and not generate_in_editor: return
	var startup_task: int = startup_provider.begin("Forest") if startup_provider != null else -1
	if startup_provider != null: await startup_provider.wait_for(self, "Landscape scenery")
	await regenerate()
	if startup_provider != null: startup_provider.finish(startup_task)

func regenerate() -> void:
	if config == null: return
	if is_instance_valid(_floor_patch):
		remove_child(_floor_patch)
		_floor_patch.queue_free()
	if is_instance_valid(_chunks):
		remove_child(_chunks)
		_chunks.queue_free()
	_chunks = Node3D.new()
	_chunks.name = "GeneratedChunks_Runtime"
	add_child(_chunks)
	_terrain = get_node_or_null(terrain_source) if not terrain_source.is_empty() else null
	_noise.seed = config.seed
	_noise.frequency = config.biome_noise_scale
	_noise.fractal_octaves = 3
	if _terrain != null and _terrain.has_method("prepare_forest_area"):
		await _terrain.call("prepare_forest_area")
	_tree_positions.clear()
	if _terrain != null and _terrain.has_method("sample_forest_existing_tree_points"):
		for point in _terrain.call("sample_forest_existing_tree_points"):
			_tree_positions.append(point)
	_counts.clear()
	_layer_points.clear()
	_ensure_wind()
	await _make_meshes()
	var buckets: Dictionary = {}
	var x0 := floori(-forest_size.x * 0.5)
	var x1 := ceili(forest_size.x * 0.5)
	var z0 := floori(-forest_size.y * 0.5)
	var z1 := ceili(forest_size.y * 0.5)
	for gx in range(x0, x1):
		if startup_provider != null: await startup_provider.checkpoint(self, "Preparing the forest…")
		for gz in range(z0, z1):
			for layer_index in LAYERS.size():
				var layer: String = LAYERS[layer_index]
				var rng := _cell_rng(gx, gz, layer_index)
				var p := Vector2(gx + rng.randf(), gz + rng.randf())
				if absf(p.x) >= forest_size.x * 0.5 or absf(p.y) >= forest_size.y * 0.5: continue
				var height := _height(p)
				if height < config.min_height or height > config.max_height: continue
				if _slope(p) > config.max_slope: continue
				var definition: ForestSpecies = _species.get(layer)
				if definition != null:
					if height < definition.height_range.x or height > definition.height_range.y: continue
					if _slope(p) > definition.max_slope: continue
				var density := _density(p, layer) * _layer_density(layer)
				if definition != null: density *= definition.density_multiplier
				if rng.randf() >= minf(1.0, BASE_RATE[layer] * density): continue
				if layer in TREE_LAYERS:
					var separated := true
					for previous in _tree_positions:
						if previous.distance_to(p) < config.minimum_tree_separation:
							separated = false
							break
					if not separated: continue
					_tree_positions.append(p)
				if definition != null and definition.minimum_separation > 0.0:
					if not _has_space(layer, p, definition.minimum_separation): continue
				var transform := _placement_transform(layer, p, height, rng)
				var cx := floori((p.x + forest_size.x * 0.5) / config.chunk_size)
				var cz := floori((p.y + forest_size.y * 0.5) / config.chunk_size)
				var key := Vector2i(cx, cz)
				if not buckets.has(key): buckets[key] = {}
				if not buckets[key].has(layer): buckets[key][layer] = []
				buckets[key][layer].append(transform)
				_counts[layer] = _counts.get(layer, 0) + 1
				if layer in ["hero", "canopy", "canopy_broad"] and (definition == null or definition.receives_attachments) and rng.randf() < config.shelf_fungus_probability:
					if not buckets[key].has("shelf_fungus"): buckets[key]["shelf_fungus"] = []
					var attachment := _fungus_transform(transform, rng, definition)
					buckets[key]["shelf_fungus"].append(attachment)
					_counts["shelf_fungus"] = _counts.get("shelf_fungus", 0) + 1
	var signature := PackedStringArray()
	for key in buckets:
		for layer in buckets[key]:
			for placement in buckets[key][layer]: signature.append(layer + str(placement))
	signature.sort()
	set_meta("placement_signature", hash(signature))
	for key in buckets:
		_make_chunk(key, buckets[key])
		if startup_provider != null: await startup_provider.checkpoint(self, "Preparing the forest…")
	if config.terrain_floor_overlay and _terrain != null:
		_floor_patch = MeshInstance3D.new()
		_floor_patch.set_script(preload("res://environment/forest/scripts/forest_floor_patch.gd"))
		_floor_patch.name = "ForestFloor_Runtime"
		add_child(_floor_patch)
		await _floor_patch.rebuild(self)
	set_meta("forest_counts", _counts.duplicate())
	generated.emit()

func _ensure_wind() -> void:
	if Engine.is_editor_hint(): return
	var scene_root := get_tree().root
	if scene_root.get_node_or_null("WindSystem") != null or scene_root.get_node_or_null("ForestWindFallback") != null: return
	if scene_root.has_meta("forest_wind_fallback_created"): return
	scene_root.set_meta("forest_wind_fallback_created", true)
	# Inspect the local project setting, never query all renderer globals at runtime.
	if not ProjectSettings.has_setting("shader_globals/world_wind"):
		RenderingServer.global_shader_parameter_add("world_wind", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3(1.3, 0, 0.52))
	var driver := Node.new()
	driver.set_script(preload("res://environment/forest/scripts/forest_wind_fallback.gd"))
	driver.name = "ForestWindFallback"
	scene_root.add_child.call_deferred(driver)

func _cell_rng(gx: int, gz: int, layer_index: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(gx, gz, layer_index)) ^ config.seed
	return rng

func _density(p: Vector2, layer: String = "") -> float:
	var noise_value := _noise.get_noise_2d(p.x, p.y)
	var cluster := 0.28 + 0.72 * smoothstep(config.biome_threshold - 0.2, config.biome_threshold + 0.35, noise_value)
	var mask := 1.0
	if _terrain != null and _terrain.has_method("sample_forest_biome_mask"):
		mask = clampf(_terrain.call("sample_forest_biome_mask", p.x, p.y), 0.0, 1.0)
	var clearance := config.tree_path_clearance if layer in TREE_LAYERS else (1.2 if layer == "fallen_log" else 0.0)
	var definition: ForestSpecies = _species.get(layer)
	if definition != null: clearance = maxf(clearance, definition.extra_path_clearance)
	return cluster * mask * _corridor_density(p, clearance) * config.overall_density

func _layer_density(layer: String) -> float:
	match layer:
		"hero": return config.hero_density
		"canopy": return config.canopy_density
		"canopy_broad": return config.canopy_density
		"small_tree": return config.small_tree_density
		"dead_tree": return config.dead_tree_density
		"fallen_log": return config.fallen_log_density
		"fern": return config.fern_density
		"shrub": return config.shrub_density
		"broadleaf": return config.broadleaf_density
		"tall_grass": return config.tall_grass_density
		"short_grass": return config.short_grass_density
		"floor": return config.floor_density
		"rock": return config.rock_density
		"debris": return config.debris_density
	return 0.0

func _corridor_density(p: Vector2, extra_clearance: float = 0.0) -> float:
	if path_points.size() < 2: return 1.0
	var nearest := INF
	for i in range(path_points.size() - 1):
		var a := path_points[i]
		var ab := path_points[i + 1] - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		nearest = minf(nearest, p.distance_to(a + ab * t))
	return smoothstep(config.path_exclusion_radius + extra_clearance, config.path_exclusion_radius + extra_clearance + maxf(config.path_feather, 0.001), nearest)

func _height(p: Vector2) -> float:
	if _terrain != null and _terrain.has_method("sample_forest_height"):
		return _terrain.call("sample_forest_height", p.x, p.y)
	return 0.0

func _slope(p: Vector2) -> float:
	if _terrain != null and _terrain.has_method("sample_forest_normal"):
		var normal: Vector3 = _terrain.call("sample_forest_normal", p.x, p.y)
		return 1.0 - normal.normalized().y
	var h := _height(p)
	var gradient := Vector2(_height(p + Vector2(0.5, 0)) - h, _height(p + Vector2(0, 0.5)) - h).length() * 2.0
	return 1.0 - 1.0 / sqrt(1.0 + gradient * gradient)

func _has_space(layer: String, p: Vector2, separation: float) -> bool:
	if not _layer_points.has(layer): _layer_points[layer] = {}
	var grid: Dictionary = _layer_points[layer]
	var cell := Vector2i(floori(p.x / separation), floori(p.y / separation))
	for x in range(-1, 2):
		for z in range(-1, 2):
			for previous in grid.get(cell + Vector2i(x, z), []):
				if p.distance_to(previous) < separation: return false
	if not grid.has(cell): grid[cell] = []
	grid[cell].append(p)
	return true

func _normal(p: Vector2) -> Vector3:
	if _terrain != null and _terrain.has_method("sample_forest_normal"):
		return (_terrain.call("sample_forest_normal", p.x, p.y) as Vector3).normalized()
	return Vector3.UP

func _placement_transform(layer: String, p: Vector2, height: float, rng: RandomNumberGenerator) -> Transform3D:
	var definition: ForestSpecies = _species.get(layer)
	var scales := config.tree_scale_range if layer in TREE_LAYERS else config.plant_scale_range
	if definition != null:
		# Global scale controls multiply species-specific authored scale.
		scales *= definition.scale_range
	var size := rng.randf_range(scales.x, scales.y)
	if definition == null:
		if layer == "canopy": size *= 2.5
		if layer == "canopy_broad": size *= 0.75
		if layer == "small_tree": size *= 1.3
		if layer == "tall_grass": size *= 2.2
	var normal := _normal(p)
	var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
	if definition != null and definition.align_to_ground:
		basis = Basis(Quaternion(Vector3.UP, normal)) * basis
	if layer in ["fallen_log", "debris"]:
		basis = basis * Basis(Vector3.FORWARD, PI * 0.5)
	if definition != null:
		height += definition.ground_offset * size
		if definition.root_radius > 0.0:
			# Embed the root apron to its lowest sampled terrain contact.
			var lowest := height
			for i in 8:
				var angle := TAU * i / 8.0
				lowest = minf(lowest, _height(p + Vector2(cos(angle), sin(angle)) * definition.root_radius * size))
			height = lowest - 0.06 * size
	var origin := Vector3(p.x, height, p.y)
	if layer == "fallen_log" and definition != null:
		origin -= basis.y * definition.collision_height * size * 0.5
	return Transform3D(basis.scaled(Vector3.ONE * size), origin)

func _fungus_transform(tree: Transform3D, rng: RandomNumberGenerator, definition: ForestSpecies = null) -> Transform3D:
	var tree_scale := tree.basis.get_scale().x
	var angle := rng.randf_range(0.0, TAU)
	var radius := definition.collision_radius * 0.76 if definition != null else 0.3
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * (radius * tree_scale) + Vector3(0.1, 0, 0) * tree_scale
	var size := rng.randf_range(0.22, 0.45) * tree_scale
	var origin := tree.origin + offset + Vector3.UP * rng.randf_range(0.7, 2.2) * tree_scale
	return Transform3D(Basis(Vector3.UP, -angle - PI * 0.5).scaled(Vector3.ONE * size), origin)

func _make_chunk(key: Vector2i, layers: Dictionary) -> void:
	var chunk := Node3D.new()
	chunk.name = "Chunk_%02d_%02d" % [key.x, key.y]
	var corner := Vector2(key) * config.chunk_size - forest_size * 0.5
	var extent := Vector2(minf(config.chunk_size, forest_size.x * 0.5 - corner.x), minf(config.chunk_size, forest_size.y * 0.5 - corner.y))
	var center := corner + extent * 0.5
	chunk.position = Vector3(center.x, _height(center), center.y)
	_chunks.add_child(chunk)
	for layer in layers:
		var transforms: Array = layers[layer]
		var lods: Array = _lod_meshes.get(layer, [_meshes[layer]])
		var maximum := _visibility_distance(layer)
		for band in lods.size():
			var begin := 0.0 if band == 0 else (config.near_distance if band == 1 else config.medium_distance)
			if begin >= maximum: continue
			var end := maximum
			if band < lods.size() - 1: end = minf(maximum, config.near_distance if band == 0 else config.medium_distance)
			for mesh_index in lods[band].size():
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = lods[band][mesh_index]
				mm.instance_count = transforms.size()
				for i in transforms.size():
					var local: Transform3D = transforms[i]
					local.origin -= chunk.position
					mm.set_instance_transform(i, local)
				var batch := MultiMeshInstance3D.new()
				batch.name = "%s_LOD%d_Part%d" % [layer.capitalize().replace(" ", ""), band, mesh_index]
				batch.multimesh = mm
				batch.extra_cull_margin = config.wind_strength * 0.8
				if layer not in TREE_LAYERS + ["rock", "fallen_log"]:
					if not config.groundcover_shadows or band > 0:
						batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				batch.visibility_range_begin = begin
				batch.visibility_range_end = end
				batch.visibility_range_begin_margin = config.lod_fade_margin if band > 0 else 0.0
				batch.visibility_range_end_margin = config.lod_fade_margin
				batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				chunk.add_child(batch)
		if config.enable_collisions and layer in TREE_LAYERS + ["rock", "fallen_log"]:
			for transform in transforms:
				var local: Transform3D = transform
				local.origin -= chunk.position
				_add_collision(chunk, layer, local)

func _visibility_distance(layer: String) -> float:
	if layer in ["floor", "short_grass", "debris"]: return config.near_distance
	if layer in ["tall_grass", "broadleaf", "shrub", "fern"]: return config.medium_distance
	return config.far_distance

func _add_collision(chunk: Node3D, layer: String, transform: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.transform = transform
	var definition: ForestSpecies = _species.get(layer)
	var shape := CollisionShape3D.new()
	var scale_value := 1.0 # Body transform already carries the instance scale.
	if definition != null and definition.collision_radius > 0.0:
		var capsule := CapsuleShape3D.new()
		capsule.radius = definition.collision_radius
		capsule.height = maxf(definition.collision_height, capsule.radius * 2.0)
		shape.shape = capsule
		shape.position.y = capsule.height * 0.5
	elif layer == "rock":
		var sphere := SphereShape3D.new()
		sphere.radius = 0.55 * scale_value
		shape.shape = sphere
		shape.position.y = 0.5 * scale_value
	elif layer == "fallen_log":
		var box := BoxShape3D.new()
		box.size = Vector3(3.0, 0.55, 0.7) * scale_value
		shape.shape = box
		shape.position.y = 0.3 * scale_value
	else:
		var cylinder := CylinderShape3D.new()
		cylinder.radius = (0.55 if layer == "hero" else 0.35) * scale_value
		cylinder.height = (3.0 if layer == "hero" else 2.4) * scale_value
		shape.shape = cylinder
		shape.position.y = cylinder.height * 0.5
	body.add_child(shape)
	chunk.add_child(body)

func _make_meshes() -> void:
	_meshes.clear()
	_species.clear()
	_lod_meshes.clear()
	_meshes["hero"] = [_placeholder_cylinder(Color(0.3, 0.25, 0.18), 9.0, 0.6)]
	_meshes["canopy"] = [_placeholder_cylinder(Color(0.3, 0.25, 0.18), 3.4, 0.3)]
	_meshes["canopy_broad"] = _meshes["hero"]
	_meshes["small_tree"] = _meshes["canopy"]
	_meshes["dead_tree"] = [_placeholder_cylinder(Color(0.31, 0.27, 0.22), 4.2, 0.28)]
	_meshes["fallen_log"] = [_placeholder_cylinder(Color(0.27, 0.23, 0.19), 3.5, 0.28)]
	_meshes["fern"] = [PLACEHOLDER_PLANTS.make_cluster(16, 0.55, 0.1, 0.5, Color(0.18, 0.30, 0.10), config.wind_strength)]
	_meshes["shrub"] = [PLACEHOLDER_PLANTS.make_cluster(18, 0.68, 0.13, 0.55, Color(0.20, 0.34, 0.13), config.wind_strength)]
	_meshes["broadleaf"] = [PLACEHOLDER_PLANTS.make_cluster(7, 0.34, 0.24, 0.35, Color(0.30, 0.42, 0.16), config.wind_strength)]
	_meshes["tall_grass"] = [PLACEHOLDER_PLANTS.make_cluster(14, 0.72, 0.05, 0.24, Color(0.30, 0.42, 0.17), config.wind_strength)]
	_meshes["short_grass"] = [PLACEHOLDER_PLANTS.make_cluster(10, 0.25, 0.04, 0.09, Color(0.27, 0.38, 0.14), config.wind_strength)]
	_meshes["floor"] = [PLACEHOLDER_PLANTS.make_cluster(6, 0.16, 0.07, 0.14, Color(0.24, 0.32, 0.12), config.wind_strength)]
	_meshes["rock"] = _scene_meshes(BOULDER)
	_meshes["debris"] = [_placeholder_cylinder(Color(0.29, 0.23, 0.16), 0.8, 0.05)]
	var fungus := SphereMesh.new()
	fungus.radius = 0.75
	fungus.height = 0.18
	fungus.radial_segments = 10
	fungus.rings = 3
	fungus.material = _material(Color(0.68, 0.59, 0.42))
	_meshes["shelf_fungus"] = [fungus]
	for resource in config.species:
		if startup_provider != null: await startup_provider.checkpoint(self, "Preparing the forest…")
		var definition := resource as ForestSpecies
		if definition == null or definition.near_scene == null: continue
		_species[definition.layer] = definition
		var near := _scene_meshes(definition.near_scene)
		var medium := _scene_meshes(definition.medium_scene) if definition.medium_scene != null else near
		var far := _scene_meshes(definition.far_scene) if definition.far_scene != null else medium
		_meshes[definition.layer] = near
		_lod_meshes[definition.layer] = [near, medium, far]

func _scene_meshes(scene: PackedScene) -> Array[Mesh]:
	var root := scene.instantiate()
	var result: Array[Mesh] = []
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		var baked := Transform3D.IDENTITY
		var cursor: Node = instance
		while cursor != null:
			if cursor is Node3D: baked = (cursor as Node3D).transform * baked
			if cursor == root: break
			cursor = cursor.get_parent()
		for surface_index in instance.mesh.get_surface_count():
			var surface := SurfaceTool.new()
			surface.append_from(instance.mesh, surface_index, baked)
			var material := instance.get_active_material(surface_index)
			if material is StandardMaterial3D and "Leaves" in str(material.resource_name):
				var foliage := ShaderMaterial.new()
				foliage.shader = preload("res://environment/forest/shaders/foliage.gdshader")
				foliage.set_shader_parameter("wind_strength", config.wind_strength)
				foliage.set_shader_parameter("wind_uv_reversed", true)
				foliage.set_shader_parameter("foliage_uv_scale", Vector2(0.18, 0.36))
				foliage.set_shader_parameter("foliage_uv_offset", Vector2(0.16, 0.02))
				foliage.set_shader_parameter("albedo_texture", preload("res://environment/forest/assets/textures/leaves_albedo.png"))
				foliage.set_shader_parameter("use_albedo_texture", true)
				foliage.set_shader_parameter("normal_texture", preload("res://environment/forest/assets/textures/leaves_normal.jpg"))
				foliage.set_shader_parameter("use_normal_texture", true)
				foliage.set_shader_parameter("roughness_texture", preload("res://environment/forest/assets/textures/leaves_arm.jpg"))
				foliage.set_shader_parameter("use_roughness_texture", true)
				material = foliage
			elif material is StandardMaterial3D and "Forest_Bark" in str(material.resource_name):
				var bark := ShaderMaterial.new()
				bark.shader = preload("res://environment/forest/shaders/bark.gdshader")
				bark.set_shader_parameter("bark_color", preload("res://environment/forest/assets/textures/bark_brown_02_diff_2k.jpg"))
				bark.set_shader_parameter("bark_normal", preload("res://environment/forest/assets/textures/bark_brown_02_nor_gl_2k.jpg"))
				bark.set_shader_parameter("bark_roughness", preload("res://environment/forest/assets/textures/bark_brown_02_rough_2k.jpg"))
				material = bark
			surface.set_material(material)
			result.append(surface.commit())
	root.free()
	return result

func _placeholder_cylinder(color: Color, height: float, radius: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.7
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.material = _material(color)
	return mesh

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material
