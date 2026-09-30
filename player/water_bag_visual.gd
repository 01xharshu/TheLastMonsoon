extends Node3D
## Fit the shared leather asset to the hip without changing the world pickup mesh.
const MODEL_SCALE := 0.8
const HIP_ANGLE := PI * 2.0 / 3.0
const HIP_SUPPORT := 0.0575
const BELT_PIN := Vector3(0.0, 0.41, 0.0)
const PROFILE := [Vector2(0.0, 0.0), Vector2(0.065, 0.008), Vector2(0.11, 0.05), Vector2(0.13, 0.12), Vector2(0.125, 0.21), Vector2(0.105, 0.265), Vector2(0.055, 0.29), Vector2(0.032, 0.31), Vector2(0.028, 0.335)]
var fullness := 0.0
var target_fullness := 0.0
var built_fullness := -1.0
var sources: Array[Dictionary] = []
var marker_sources: Dictionary = {}
var body: MeshInstance3D
var cord: MeshInstance3D
var stopper: MeshInstance3D
var pitch := 0.0
var outward := 0.0
@onready var inventory: InventoryComponent = $"../../../InventoryComponent"
@onready var pouch: Node3D = $PouchModel

func _ready() -> void:
	process_priority = 12
	body = pouch.get_node("LeatherBody")
	cord = pouch.get_node("BindingAndLoop/pouch_seams_loop")
	stopper = pouch.get_node("Stopper")
	for node in [body, cord, stopper]:
		var source_transform: Transform3D = pouch.global_transform.affine_inverse() * node.global_transform
		var surfaces: Array = []
		for index in node.mesh.get_surface_count():
			surfaces.append({"arrays": node.mesh.surface_get_arrays(index), "material": node.mesh.surface_get_material(index)})
		sources.append({"node": node, "transform": source_transform, "surfaces": surfaces})
		# Vertices are rebuilt in the pouch's model space, including the stopper.
		node.transform = Transform3D.IDENTITY
	for marker in pouch.find_children("*", "Marker3D", true, false):
		marker_sources[marker] = marker.position
	var keeper := MeshInstance3D.new()
	keeper.name = "SashKeeper"
	var keeper_mesh := BoxMesh.new()
	keeper_mesh.size = Vector3(0.012, 0.075, 0.025)
	keeper.mesh = keeper_mesh
	keeper.position = Vector3(0.0026, 0.008, -0.0015)
	keeper.rotation.y = PI / 6.0
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.24, 0.115, 0.055)
	leather.roughness = 0.9
	keeper.material_override = leather
	add_child(keeper)
	inventory.water_changed.connect(_on_water_changed)
	_on_water_changed(inventory.stored_water_liters, inventory.get_total_water_capacity_liters())
	fullness = target_fullness
	_rebuild()
	set_sway(0.0, 0.0)

func _on_water_changed(liters: float, capacity: float) -> void:
	target_fullness = clampf(liters / maxf(capacity, 0.001), 0.0, 1.0)

func _process(delta: float) -> void:
	fullness = move_toward(fullness, target_fullness, delta * 3.5)
	if absf(fullness - built_fullness) >= 0.025 or (fullness == target_fullness and fullness != built_fullness):
		_rebuild()

func set_sway(pitch_value: float, outward_value: float) -> void:
	pitch = pitch_value
	outward = outward_value
	var weight := lerpf(0.55, 1.0, fullness)
	var swing := Basis.from_euler(Vector3(pitch * weight, 0.0, outward * weight))
	var fitted := swing * Basis(Vector3.UP, HIP_ANGLE).scaled(Vector3.ONE * MODEL_SCALE)
	# Rotate around the top of the carry loop, which is pinned to the sash.
	pouch.transform = Transform3D(fitted, -(fitted * BELT_PIN))

func belt_pin_world() -> Vector3:
	return pouch.to_global(BELT_PIN)

func _radius_at(y: float) -> float:
	if y > 0.335: return 0.0
	for index in range(1, PROFILE.size()):
		var lower: Vector2 = PROFILE[index - 1]
		var upper: Vector2 = PROFILE[index]
		if y <= upper.y:
			var before: Vector2 = PROFILE[maxi(0, index - 2)]
			var after: Vector2 = PROFILE[mini(PROFILE.size() - 1, index + 1)]
			var span := maxf(upper.y - lower.y, 0.001)
			var t := clampf((y - lower.y) / span, 0.0, 1.0)
			var slope_a := (upper.x - before.x) / maxf(upper.y - before.y, 0.001) * span
			var slope_b := (after.x - lower.x) / maxf(after.y - lower.y, 0.001) * span
			return maxf(0.0, (2.0*t*t*t - 3.0*t*t + 1.0)*lower.x + (t*t*t - 2.0*t*t + t)*slope_a + (-2.0*t*t*t + 3.0*t*t)*upper.x + (t*t*t - t*t)*slope_b)
	return 0.028

func _linear_radius_at(y: float) -> float:
	for index in range(1, PROFILE.size()):
		var lower: Vector2 = PROFILE[index - 1]
		var upper: Vector2 = PROFILE[index]
		if y <= upper.y:
			return lerpf(lower.x, upper.x, clampf((y - lower.y) / maxf(upper.y - lower.y, 0.001), 0.0, 1.0))
	return 0.028

func _deform(point: Vector3, is_stopper: bool = false) -> Vector3:
	var radius := _radius_at(point.y)
	var body_weight := 1.0 - smoothstep(0.265, 0.315, point.y)
	var depth_factor := lerpf(lerpf(0.20, 1.0, sqrt(fullness)), 1.0, 1.0 - body_weight)
	# The inward face stays in place. Filling expands the outward face.
	var support := HIP_SUPPORT * smoothstep(0.0, 1.0, clampf((0.41 - point.y) / 0.29, 0.0, 1.0))
	var center_depth := support + radius * 0.5 * depth_factor
	if is_stopper:
		# The wooden stopper keeps its shape and follows the pouch's mouth.
		var mouth_radius := _radius_at(0.335)
		var mouth_support := HIP_SUPPORT * smoothstep(0.0, 1.0, (0.41 - 0.335) / 0.29)
		return point + Vector3(0.0, 0.0, mouth_support + mouth_radius * 0.5)
	var wrinkle := (1.0 - fullness) * body_weight * (0.003 * sin(point.x * 65.0 + point.y * 23.0) + 0.003 * sin(point.x * 35.0 - point.y * 48.0)) * minf(1.0, absf(point.z) / maxf(radius * 0.5, 0.001))
	var result := Vector3(point.x * (1.0 - (1.0 - fullness) * body_weight * 0.04), point.y, point.z * depth_factor + center_depth + wrinkle)
	if point.z < 0.0 and body_weight > 0.5:
		result.z = maxf(result.z, support)
	return result

func _rebuild() -> void:
	built_fullness = fullness
	for source in sources:
		var node: MeshInstance3D = source.node
		if node == body:
			body.mesh = _smooth_body(source.surfaces[0].material)
			continue
		var source_transform: Transform3D = source.transform
		var result := ArrayMesh.new()
		for entry in source.surfaces:
			var arrays: Array = entry.arrays
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for vertex in vertices:
				var point: Vector3 = source_transform * vertex
				if node == cord and point.y < 0.29 and absf(point.x) > _linear_radius_at(point.y) * 0.8:
					point.x *= _radius_at(point.y) / maxf(_linear_radius_at(point.y), 0.001)
				surface.add_vertex(_deform(point, node == stopper))
			for index in indices: surface.add_index(index)
			surface.generate_normals()
			surface.set_material(entry.material)
			surface.commit(result)
		node.mesh = result
	for marker in marker_sources:
		marker.position = _deform(marker_sources[marker])

func _smooth_body(material: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const ROWS := 64
	const COLUMNS := 64
	for row in ROWS + 1:
		var y := 0.335 * float(row) / ROWS
		var radius := _radius_at(y)
		for column in COLUMNS + 1:
			var angle := TAU * float(column) / COLUMNS
			surface.add_vertex(_deform(Vector3(radius * cos(angle), y, radius * 0.5 * sin(angle))))
	for row in ROWS:
		for column in COLUMNS:
			var a := row * (COLUMNS + 1) + column
			var b := a + COLUMNS + 1
			for index in [a, b + 1, b, a, a + 1, b + 1]: surface.add_index(index)
	surface.generate_normals()
	surface.set_material(material)
	return surface.commit()
