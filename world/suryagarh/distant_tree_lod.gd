extends Node
## Render-only candidate. Refresh on camera travel and preserve near detail.
const REFRESH_DISTANCE := 2.0
const NEAR_DISTANCE := 45.0
var batches: Array[Array] = []
var last_eye := Vector3.INF
var refreshes := 0
var writes := 0
var reduced := 0
var last_refresh_usec := 0
var near_restores := 0

func configure(world: Node3D) -> void:
	for landscape in [world.get_node("Landscape"), world.get_node("WildernessExpansion")]:
		for node: MultiMeshInstance3D in landscape.find_children("BroadleafTrees*", "MultiMeshInstance3D", true, false):
			if node.lod_bias > 1.0:
				batches.append([node, node.global_transform * node.get_aabb(), node.lod_bias])

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var eye := camera.global_position
	if last_eye.is_finite() and eye.distance_squared_to(last_eye) < REFRESH_DISTANCE * REFRESH_DISTANCE:
		return
	var started := Time.get_ticks_usec()
	last_eye = eye
	refreshes += 1
	reduced = 0
	var boundary := NEAR_DISTANCE + REFRESH_DISTANCE
	for batch in batches:
		var node: MultiMeshInstance3D = batch[0]
		if not is_instance_valid(node):
			continue
		var bounds: AABB = batch[1]
		var far := eye.distance_squared_to(eye.clamp(bounds.position, bounds.end)) > boundary * boundary
		var bias: float = 1.0 if far else batch[2]
		if far:
			reduced += 1
		if node.lod_bias != bias:
			if not far: near_restores += 1
			node.lod_bias = bias
			writes += 1
	last_refresh_usec = Time.get_ticks_usec() - started
