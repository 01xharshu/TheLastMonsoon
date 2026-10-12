extends RefCounted
## Player-owned window corrections; retain full body/foundation and original clothes.
var replacements: Array[Dictionary] = []
var fitted_cache := {}
var meshes_built := 0

func apply(model: Node3D, progress := 0.0) -> void:
	if replacements.is_empty():
		for candidate in model.find_children("*","MeshInstance3D",true,false):
			var node := candidate as MeshInstance3D
			var tunic := str(node.name) == "Arjun_Kurta_SplitHem"
			var sash := str(node.name).begins_with("Sash hanging tail") or str(node.name) in ["Arjun_Detail_Faded madder-red sash","Arjun_Detail_Muted ochre sash thread"]
			if not tunic and not sash: continue
			var source := node.mesh
			if source == null: continue
			if not fitted_cache.has(source):
				# Bound retained alternatives if an outfit changes during this player's life.
				if fitted_cache.size() >= 16: fitted_cache.erase(fitted_cache.keys()[0])
				fitted_cache[source] = _build(source,tunic)
				meshes_built += 1
			var fitted: ArrayMesh = fitted_cache[source]
			replacements.append({"node":weakref(node),"source":source,"fitted":fitted})
			node.mesh = fitted
	var gather := smoothstep(.16,.38,progress)*(1.0-smoothstep(.68,.90,progress))
	for entry in replacements:
		var node: MeshInstance3D = entry.node.get_ref()
		if node != null and node.mesh == entry.fitted: node.set_blend_shape_value(0,gather)

func _build(source: Mesh, tunic: bool) -> ArrayMesh:
	var fitted := ArrayMesh.new()
	fitted.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	fitted.add_blend_shape("Window gathered hem" if tunic else "Window gathered sash")
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if tunic:
			for vertex in vertices.size():
				var point := vertices[vertex]
				var ease := .035*smoothstep(.78,.92,point.y)*(1.0-smoothstep(1.0,1.055,point.y))
				vertices[vertex] = point+Vector3(point.x,0,point.z-.02).normalized()*ease
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var folded := vertices.duplicate()
		for vertex in folded.size():
			var loose := 1.0-smoothstep(.74 if tunic else .68,1.015 if tunic else 1.02,folded[vertex].y)
			folded[vertex].y += (.085 if tunic else .055)*loose
			if tunic:
				folded[vertex].x *= 1.0-.06*loose
				folded[vertex].z = .02+(folded[vertex].z-.02)*(1.0-.06*loose)
			else: folded[vertex].z += .018*sin(loose*PI)
		var shape := []
		shape.resize(Mesh.ARRAY_MAX)
		shape[Mesh.ARRAY_VERTEX] = folded
		shape[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL]
		shape[Mesh.ARRAY_TANGENT] = arrays[Mesh.ARRAY_TANGENT]
		fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[shape],{},source.surface_get_format(surface)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		fitted.surface_set_material(surface,source.surface_get_material(surface))
	return fitted

func restore() -> void:
	for entry in replacements:
		var node: MeshInstance3D = entry.node.get_ref()
		if node != null and node.mesh == entry.fitted: node.mesh = entry.source
	replacements.clear()
