extends RefCounted
## Add hip ease to the existing tunic during a deep window lift.
## Restore the original garment on landing or release; retain body and foundation.
var replacements: Array[Dictionary] = []

func apply(model: Node3D, progress := 0.0) -> void:
	if not replacements.is_empty():
		_update_fold(progress)
		return
	var node := model.find_child("Arjun_Kurta_SplitHem",true,false) as MeshInstance3D
	if node == null: return
	var source := node.mesh
	var fitted := ArrayMesh.new()
	fitted.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	fitted.add_blend_shape("Window gathered hem")
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices.size():
			var point := vertices[vertex]
			var ease := .035*smoothstep(.78,.92,point.y)*(1.0-smoothstep(1.0,1.055,point.y))
			var outward := Vector3(point.x,0,point.z-.02).normalized()
			vertices[vertex] = point+outward*ease
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var folded := vertices.duplicate()
		for vertex in folded.size():
			var loose := 1.0-smoothstep(.74,1.015,folded[vertex].y)
			folded[vertex].y += .085*loose
			folded[vertex].x *= 1.0-.06*loose
			folded[vertex].z = .02+(folded[vertex].z-.02)*(1.0-.06*loose)
		var shape := []
		shape.resize(Mesh.ARRAY_MAX)
		shape[Mesh.ARRAY_VERTEX] = folded
		shape[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL]
		shape[Mesh.ARRAY_TANGENT] = arrays[Mesh.ARRAY_TANGENT]
		fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[shape],{},source.surface_get_format(surface)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		fitted.surface_set_material(surface,source.surface_get_material(surface))
	replacements.append({"node":weakref(node),"source":source,"fitted":fitted})
	node.mesh = fitted
	_prepare_sash(model)
	_update_fold(progress)

func _prepare_sash(model: Node3D) -> void:
	for candidate in model.find_children("*","MeshInstance3D",true,false):
		var node := candidate as MeshInstance3D
		if not str(node.name).begins_with("Sash hanging tail") and str(node.name) not in ["Arjun_Detail_Faded madder-red sash","Arjun_Detail_Muted ochre sash thread"]: continue
		var source := node.mesh
		var fitted := ArrayMesh.new()
		fitted.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
		fitted.add_blend_shape("Window gathered sash")
		for surface in source.get_surface_count():
			var arrays := source.surface_get_arrays(surface)
			var folded: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
			for vertex in folded.size():
				var loose := 1.0-smoothstep(.68,1.02,folded[vertex].y)
				folded[vertex].y += .055*loose
				folded[vertex].z += .018*sin(loose*PI)
			var shape := []
			shape.resize(Mesh.ARRAY_MAX)
			shape[Mesh.ARRAY_VERTEX] = folded
			shape[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL]
			shape[Mesh.ARRAY_TANGENT] = arrays[Mesh.ARRAY_TANGENT]
			fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[shape],{},source.surface_get_format(surface)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			fitted.surface_set_material(surface,source.surface_get_material(surface))
		replacements.append({"node":weakref(node),"source":source,"fitted":fitted})
		node.mesh = fitted

func _update_fold(progress: float) -> void:
	var gather := smoothstep(.16,.38,progress)*(1.0-smoothstep(.68,.90,progress))
	for entry in replacements:
		var node: MeshInstance3D = entry.node.get_ref()
		if node != null and node.mesh == entry.fitted: node.set_blend_shape_value(0,gather)

func restore() -> void:
	for entry in replacements:
		var node: MeshInstance3D = entry.node.get_ref()
		if node != null and node.mesh == entry.fitted: node.mesh = entry.source
	replacements.clear()
