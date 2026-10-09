extends RefCounted
## Remove only the outfit's boots/details; the complete MPFB body stays intact.
var hidden: Array[MeshInstance3D] = []
var originals: Dictionary = {}

func barefoot(model: Node3D) -> void:
	for node in model.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		var label := str(mesh.name)
		if label.begins_with("Arjun_Boot_") or label.begins_with("Boot outsole"):
			if mesh.visible:
				hidden.append(mesh)
				mesh.hide()
		elif label in ["Arjun_Detail_Leather seams and welt", "Arjun_Detail_Aged brass hardware"]:
			originals[mesh] = mesh.mesh
			mesh.mesh = _without_boot_details(mesh, model)

func restore() -> void:
	for node in hidden:
		if is_instance_valid(node): node.show()
	for node in originals:
		if is_instance_valid(node): node.mesh = originals[node]
	hidden.clear()
	originals.clear()

func _without_boot_details(node: MeshInstance3D, model: Node3D) -> ArrayMesh:
	var result := ArrayMesh.new()
	var frame := model.global_transform.affine_inverse()*node.global_transform
	for surface in node.mesh.get_surface_count():
		var arrays: Array = node.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for index in vertices.size(): indices.append(index)
		var retained := PackedInt32Array()
		for triangle in range(0,indices.size(),3):
			var centre := (frame*vertices[indices[triangle]]+frame*vertices[indices[triangle+1]]+frame*vertices[indices[triangle+2]])/3.0
			if centre.y > .49:
				retained.append_array(indices.slice(triangle,triangle+3))
		if retained.is_empty(): continue
		arrays[Mesh.ARRAY_INDEX] = retained
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},node.mesh.surface_get_format(surface)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		result.surface_set_material(result.get_surface_count()-1,node.mesh.surface_get_material(surface))
	return result
