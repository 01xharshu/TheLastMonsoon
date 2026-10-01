extends RefCounted
## Temporary additive acting shapes on duplicated meshes; source GLB stays intact.
var entries: Array[Dictionary] = []

func configure(model: Node3D) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if str(node.name) not in ["Arjun_MakeHuman_Body", "Arjun_Eyebrows", "Moustache strand"]: continue
		var original: ArrayMesh = node.mesh as ArrayMesh
		if original == null or original.get_blend_shape_count() > 0: continue
		var mesh := ArrayMesh.new()
		mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_RELATIVE
		mesh.add_blend_shape("opening_sad")
		mesh.add_blend_shape("opening_murmur")
		for surface in original.get_surface_count():
			var base: Array = original.surface_get_arrays(surface)
			var vertices: PackedVector3Array = base[Mesh.ARRAY_VERTEX]
			var shapes: Array[Array] = []
			for action in ["sad", "murmur"]:
				var shape: Array = []
				shape.resize(Mesh.ARRAY_MAX)
				var offsets := PackedVector3Array()
				offsets.resize(vertices.size())
				for i in vertices.size():
					var p := vertices[i]
					if node.name == "Arjun_Eyebrows" and action == "sad":
						offsets[i].y = lerpf(0.0045,-0.0025,smoothstep(0.015,0.052,absf(p.x)))
					elif node.name == "Arjun_MakeHuman_Body" and p.z > 0.12:
						var brow := exp(-pow((p.y-1.622)/0.012,2)) * exp(-pow(p.x/0.065,4))
						var mouth := exp(-pow((p.y-1.523)/0.010,2)) * exp(-pow(p.x/0.035,4))
						if action == "sad":
							offsets[i].y = brow*lerpf(0.003,-0.0015,smoothstep(0.015,0.052,absf(p.x))) - mouth*0.002*smoothstep(0.010,0.025,absf(p.x))
						else:
							offsets[i].y = -mouth*0.0025*(1.0-smoothstep(1.523,1.535,p.y))
							offsets[i].z = mouth*0.001
				shape[Mesh.ARRAY_VERTEX] = offsets
				if base[Mesh.ARRAY_NORMAL] != null:
					var normals := PackedVector3Array()
					normals.resize(vertices.size())
					shape[Mesh.ARRAY_NORMAL] = normals
				if base[Mesh.ARRAY_TANGENT] != null:
					var tangents := PackedFloat32Array()
					tangents.resize(vertices.size()*4)
					shape[Mesh.ARRAY_TANGENT] = tangents
				shapes.append(shape)
			mesh.add_surface_from_arrays(original.surface_get_primitive_type(surface),base,shapes)
			mesh.surface_set_material(surface,original.surface_get_material(surface))
		node.mesh = mesh
		entries.append({"node":node,"original":original})

func update(t: float) -> void:
	var sad := smoothstep(13.0,14.5,t)*(1.0-smoothstep(20.0,22.0,t))
	var speech := smoothstep(15.0,15.2,t)*(1.0-smoothstep(16.35,16.61,t))
	var lips := speech*(0.30+0.70*pow(sin((t-15.0)*13.0),2))
	for entry in entries:
		entry.node.set_blend_shape_value(0,sad)
		entry.node.set_blend_shape_value(1,lips)

func restore() -> void:
	for entry in entries:
		if is_instance_valid(entry.node): entry.node.mesh = entry.original
	entries.clear()
