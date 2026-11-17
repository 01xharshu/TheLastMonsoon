extends RefCounted
## Small seat correctives in the garment's bind space. The rig still deforms
## the resulting fabric and leather through the existing skin weights.

var garments: Array[Dictionary] = []
var previous_weight := 0.0

func configure(model: Node3D, stance_records: Array[Dictionary]) -> void:
	for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var label := str(node.name)
		var boot := label.begins_with("Arjun_Boot_")
		var sash := label.begins_with("Sash hanging tail") or label in [
			"Arjun_Detail_Faded madder-red sash", "Arjun_Detail_Muted ochre sash thread"
		]
		if not boot and not sash:
			continue
		var source := node.mesh
		if source == null or source.get_blend_shape_count() != 0:
			continue
		var stance_record := {}
		for record in stance_records:
			if record.node == node and record.normal == source:
				stance_record = record
				break
		garments.append({
			"node": node, "source": source, "mesh": _make_corrective(source, boot),
			"stance_record": stance_record
		})

func update(weight: float) -> void:
	if weight == previous_weight:
		return
	previous_weight = weight
	for garment in garments:
		var node: MeshInstance3D = garment.node
		var record: Dictionary = garment.stance_record
		if weight > 0.0:
			if not record.is_empty():
				record.normal = garment.mesh
			if node.mesh == garment.source:
				node.mesh = garment.mesh
			if node.mesh == garment.mesh:
				node.set_blend_shape_value(0, weight)
		else:
			if not record.is_empty():
				record.normal = garment.source
			if node.mesh == garment.mesh:
				node.mesh = garment.source

func _make_corrective(source: Mesh, boot: bool) -> ArrayMesh:
	var fitted := ArrayMesh.new()
	fitted.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	fitted.add_blend_shape("Seat boot opening" if boot else "Seat sash drape")
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
		for index in points.size():
			var point := points[index]
			if boot:
				# Give the cotton room to gather inside the leather opening.
				# The lower shaft, ankle, vamp and sole keep their authored shape.
				var rim := smoothstep(.218, .297, point.y)
				var from_axis := Vector3(point.x - signf(point.x)*.195, 0, point.z-.006)
				point += from_axis.normalized() * (.012 * rim)
			else:
				# Keep the knot fixed and guide both tails and their trim away
				# from the outer thigh with the same continuous displacement.
				var loose := 1.0-smoothstep(.67, 1.025, point.y)
				# As the thigh turns horizontal, negative bind-space Z
				# lets the free end drop below the upper fold.
				point += Vector3(-.04, .038, lerpf(.014, -.065, loose))*loose
			points[index] = point
		var shape := []
		shape.resize(Mesh.ARRAY_MAX)
		shape[Mesh.ARRAY_VERTEX] = points
		shape[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL]
		shape[Mesh.ARRAY_TANGENT] = arrays[Mesh.ARRAY_TANGENT]
		fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [shape], {}, source.surface_get_format(surface)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		fitted.surface_set_material(surface, source.surface_get_material(surface))
	return fitted
