extends RefCounted
## CPU skin samples for a fixture only; never used in the gameplay update loop.
static func bounds(actor: Node3D, rig: Skeleton3D=null, mesh_filter: String="*") -> Dictionary:
	if rig==null:rig=actor._skeleton
	var result: Dictionary={}
	for node in actor.find_children(mesh_filter,"MeshInstance3D",true,false):
		if node.skin==null:continue
		var palette: Array[Transform3D]=[]
		for bind in node.skin.get_bind_count():
			var index: int=rig.find_bone(node.skin.get_bind_name(bind)) if node.skin.get_bind_name(bind)!=&"" else node.skin.get_bind_bone(bind)
			palette.append(rig.global_transform*rig.get_bone_global_pose(index)*node.skin.get_bind_pose(bind))
		var min_y:=INF;var max_y:=-INF;var minimum_point:=Vector3.INF
		for surface in node.mesh.get_surface_count():
			var arrays: Array=node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var morphs: Array=node.mesh.surface_get_blend_shape_arrays(surface)
			for shape in node.mesh.get_blend_shape_count():
				var amount: float=node.get_blend_shape_value(shape)
				if is_zero_approx(amount):continue
				var positions: PackedVector3Array=morphs[shape][Mesh.ARRAY_VERTEX]
				var base_positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				for index in vertices.size():
					vertices[index]+=(positions[index] if node.mesh.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_RELATIVE else positions[index]-base_positions[index])*amount
			var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			var slots: int=weights.size()/vertices.size()
			for vertex in vertices.size():
				var point:=Vector3.ZERO
				for slot in slots:
					var offset:=vertex*slots+slot
					if weights[offset]>0:point+=(palette[bones[offset]]*vertices[vertex])*weights[offset]
				if point.y<min_y:minimum_point=point
				min_y=minf(min_y,point.y);max_y=maxf(max_y,point.y)
		result[str(node.name)]={"minimum_y":min_y,"maximum_y":max_y,"minimum_point":minimum_point}
	return result
