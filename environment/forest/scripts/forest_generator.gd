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

const ISLAND_TREE = preload("res://assets/nature/models/island_tree_02.glb")
const MANGO_TREE = preload("res://environment/vegetation/mango_tree/mango_tree_01.glb")
const BOULDER = preload("res://assets/nature/models/boulder_01.glb")
const PLACEHOLDER_PLANTS = preload("res://environment/forest/vegetation/placeholder_plants.gd")
const LAYERS := ["hero", "canopy", "canopy_broad", "small_tree", "dead_tree", "fallen_log", "shrub", "broadleaf", "tall_grass", "short_grass", "floor", "rock", "debris"]
const BASE_RATE := {"hero": 0.012, "canopy": 0.085, "canopy_broad": 0.025, "small_tree": 0.07, "dead_tree": 0.006, "fallen_log": 0.006, "shrub": 0.24, "broadleaf": 0.20, "tall_grass": 0.30, "short_grass": 0.55, "floor": 0.32, "rock": 0.025, "debris": 0.05}
const TREE_LAYERS := ["hero", "canopy", "canopy_broad", "small_tree", "dead_tree"]

var _noise := FastNoiseLite.new()
var _chunks: Node3D
var _meshes: Dictionary = {}
var _terrain: Node
var _tree_positions: Array[Vector2] = []
var _counts: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint() and not generate_in_editor: return
	regenerate()

func regenerate() -> void:
	if config == null: return
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
		_terrain.call("prepare_forest_area")
	_tree_positions.clear()
	if _terrain != null and _terrain.has_method("sample_forest_existing_tree_points"):
		for point in _terrain.call("sample_forest_existing_tree_points"):
			_tree_positions.append(point)
	_counts.clear()
	_make_meshes()
	var buckets: Dictionary = {}
	var x0 := floori(-forest_size.x * 0.5)
	var x1 := ceili(forest_size.x * 0.5)
	var z0 := floori(-forest_size.y * 0.5)
	var z1 := ceili(forest_size.y * 0.5)
	for gx in range(x0, x1):
		for gz in range(z0, z1):
			for layer_index in LAYERS.size():
				var layer: String = LAYERS[layer_index]
				var rng := _cell_rng(gx, gz, layer_index)
				var p := Vector2(gx + rng.randf(), gz + rng.randf())
				if absf(p.x) >= forest_size.x * 0.5 or absf(p.y) >= forest_size.y * 0.5: continue
				var height := _height(p)
				if height < config.min_height or height > config.max_height: continue
				if _slope(p) > config.max_slope: continue
				var density := _density(p, layer) * _layer_density(layer)
				if rng.randf() >= minf(1.0, BASE_RATE[layer] * density): continue
				if layer in TREE_LAYERS:
					var separated := true
					for previous in _tree_positions:
						if previous.distance_to(p) < config.minimum_tree_separation:
							separated = false
							break
					if not separated: continue
					_tree_positions.append(p)
				var transform := _placement_transform(layer, p, height, rng)
				var cx := floori((p.x + forest_size.x * 0.5) / config.chunk_size)
				var cz := floori((p.y + forest_size.y * 0.5) / config.chunk_size)
				var key := Vector2i(cx, cz)
				if not buckets.has(key): buckets[key] = {}
				if not buckets[key].has(layer): buckets[key][layer] = []
				buckets[key][layer].append(transform)
				_counts[layer] = _counts.get(layer, 0) + 1
				if layer in ["hero", "canopy", "canopy_broad"] and rng.randf() < config.shelf_fungus_probability:
					if not buckets[key].has("shelf_fungus"): buckets[key]["shelf_fungus"] = []
					var attachment := _fungus_transform(transform, rng)
					buckets[key]["shelf_fungus"].append(attachment)
					_counts["shelf_fungus"] = _counts.get("shelf_fungus", 0) + 1
	for key in buckets:
		_make_chunk(key, buckets[key])
	set_meta("forest_counts", _counts.duplicate())
	generated.emit()

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
	return cluster * mask * _corridor_density(p, clearance) * config.overall_density

func _layer_density(layer: String) -> float:
	match layer:
		"hero": return config.hero_density
		"canopy": return config.canopy_density
		"canopy_broad": return config.canopy_density
		"small_tree": return config.small_tree_density
		"dead_tree": return config.dead_tree_density
		"fallen_log": return config.fallen_log_density
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

func _placement_transform(layer: String, p: Vector2, height: float, rng: RandomNumberGenerator) -> Transform3D:
	var scales := config.tree_scale_range if layer in TREE_LAYERS else config.plant_scale_range
	var size := rng.randf_range(scales.x, scales.y)
	if layer == "hero": size *= 1.0
	if layer == "canopy": size *= 2.5 # Existing island tree is only 3.4 m tall.
	if layer == "canopy_broad": size *= 0.75
	if layer == "small_tree": size *= 1.3
	if layer == "dead_tree": size *= 1.0
	if layer == "tall_grass": size *= 2.2
	var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
	if layer in ["fallen_log", "debris"]:
		basis = basis.rotated(Vector3.FORWARD, PI * 0.5)
		if layer == "fallen_log": size *= 1.8
	var origin := Vector3(p.x, height, p.y)
	return Transform3D(basis.scaled(Vector3.ONE * size), origin)

func _fungus_transform(tree: Transform3D, rng: RandomNumberGenerator) -> Transform3D:
	var tree_scale := tree.basis.get_scale().x
	var angle := rng.randf_range(0.0, TAU)
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * (0.38 * tree_scale)
	var size := rng.randf_range(0.22, 0.45) * tree_scale
	var origin := tree.origin + offset + Vector3.UP * rng.randf_range(0.7, 2.2) * tree_scale
	return Transform3D(Basis(Vector3.UP, angle).scaled(Vector3.ONE * size), origin)

func _make_chunk(key: Vector2i, layers: Dictionary) -> void:
	var chunk := Node3D.new()
	chunk.name = "Chunk_%02d_%02d" % [key.x, key.y]
	_chunks.add_child(chunk)
	for layer in layers:
		var transforms: Array = layers[layer]
		for mesh_index in _meshes[layer].size():
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = _meshes[layer][mesh_index]
			mm.instance_count = transforms.size()
			for i in transforms.size(): mm.set_instance_transform(i, transforms[i])
			var batch := MultiMeshInstance3D.new()
			batch.name = "%s_Part%d" % [layer.capitalize().replace(" ", ""), mesh_index]
			batch.multimesh = mm
			batch.visibility_range_end = _visibility_distance(layer)
			chunk.add_child(batch)
		if config.enable_collisions and layer in TREE_LAYERS + ["rock", "fallen_log"]:
			for transform in transforms: _add_collision(chunk, layer, transform)

func _visibility_distance(layer: String) -> float:
	if layer in ["floor", "short_grass", "debris"]: return config.near_distance
	if layer in ["tall_grass", "broadleaf", "shrub"]: return config.medium_distance
	return config.far_distance

func _add_collision(chunk: Node3D, layer: String, transform: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.position = transform.origin
	var shape := CollisionShape3D.new()
	var scale_value := transform.basis.get_scale().x
	if layer == "rock":
		var sphere := SphereShape3D.new()
		sphere.radius = 0.55 * scale_value
		shape.shape = sphere
		shape.position.y = 0.5 * scale_value
	elif layer == "fallen_log":
		var box := BoxShape3D.new()
		box.size = Vector3(3.0, 0.55, 0.7) * scale_value
		shape.shape = box
		shape.rotation.y = transform.basis.get_euler().y
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
	_meshes["hero"] = _scene_meshes(MANGO_TREE)
	_meshes["canopy"] = _scene_meshes(ISLAND_TREE)
	_meshes["canopy_broad"] = _meshes["hero"]
	_meshes["small_tree"] = _meshes["canopy"]
	_meshes["dead_tree"] = [_placeholder_cylinder(Color(0.31, 0.27, 0.22), 4.2, 0.28)]
	_meshes["fallen_log"] = [_placeholder_cylinder(Color(0.27, 0.23, 0.19), 3.5, 0.28)]
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

func _scene_meshes(scene: PackedScene) -> Array[Mesh]:
	var root := scene.instantiate()
	var result: Array[Mesh] = []
	for child in root.find_children("*", "MeshInstance3D", true, false):
		result.append((child as MeshInstance3D).mesh)
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
