extends RefCounted
## Temporary additive acting shapes on duplicated meshes; source GLB stays intact.
var entries: Array[Dictionary] = []
var speech_envelope: Array = []

func configure(model: Node3D) -> void:
	speech_envelope = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/opening/arjun_murmur_envelope.json")).amplitudes
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if str(node.name) not in ["Arjun_MakeHuman_Body", "Arjun_Eyebrows", "Moustache strand"]: continue
		var original: ArrayMesh = node.mesh as ArrayMesh
		if original == null or original.get_blend_shape_count() > 0: continue
		var mesh := ArrayMesh.new()
		# Absolute shapes preserve valid unit normals/tangents. Zero normal
		# deltas cannot be represented by the renderer's octahedral encoding.
		mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
		mesh.add_blend_shape("opening_sad")
		mesh.add_blend_shape("opening_murmur")
		mesh.add_blend_shape("opening_sleep_lids")
		for surface in original.get_surface_count():
			var base: Array = original.surface_get_arrays(surface)
			var vertices: PackedVector3Array = base[Mesh.ARRAY_VERTEX]
			var shapes: Array[Array] = []
			for action in ["sad", "murmur", "sleep"]:
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
						elif action == "murmur":
							offsets[i].y = -mouth*0.0025*(1.0-smoothstep(1.523,1.535,p.y))
							offsets[i].z = mouth*0.001
						elif p.z > .136 and p.z < .153:
							# Bring the existing MakeHuman lid rims together over the eye;
							# preserve all body vertices, skinning and source geometry.
							var eye := exp(-pow((absf(p.x)-.0295)/.018,4))
							var lid := smoothstep(1.593,1.599,p.y)*(1.0-smoothstep(1.613,1.620,p.y))
							var face := smoothstep(.136,.143,p.z)*(1.0-smoothstep(.147,.153,p.z))
							offsets[i].y = (1.6056-p.y)*eye*lid*face
							offsets[i].z = .003*eye*lid*face
				var shaped := vertices.duplicate()
				for i in shaped.size(): shaped[i] += offsets[i]
				shape[Mesh.ARRAY_VERTEX] = shaped
				if base[Mesh.ARRAY_NORMAL] != null:
					shape[Mesh.ARRAY_NORMAL] = base[Mesh.ARRAY_NORMAL]
				if base[Mesh.ARRAY_TANGENT] != null:
					shape[Mesh.ARRAY_TANGENT] = base[Mesh.ARRAY_TANGENT]
				shapes.append(shape)
			mesh.add_surface_from_arrays(original.surface_get_primitive_type(surface),base,shapes)
			mesh.surface_set_material(surface,original.surface_get_material(surface))
		node.mesh = mesh
		entries.append({"node":node,"original":original})

func update(t: float) -> void:
	var sad := smoothstep(13.0,14.5,t)*(1.0-smoothstep(20.0,22.0,t))
	var speech := smoothstep(15.0,15.2,t)*(1.0-smoothstep(16.35,16.61,t))
	var sample := clampf((t-15.0)/.02,0,maxf(0,speech_envelope.size()-1))
	var lower := int(sample)
	var amplitude: float = lerpf(speech_envelope[lower],speech_envelope[mini(lower+1,speech_envelope.size()-1)],sample-lower) if not speech_envelope.is_empty() else 0.0
	var lips := speech*amplitude
	lips = maxf(lips,.15*pow(sin(clampf((t-6.05)/.45,0,1)*PI),2))
	var blink := 0.0
	for begin in [2.8,7.0,13.4,16.8,20.4]:
		if t >= begin and t < begin+.18:
			blink = pow(sin((t-begin)/.18*PI),2)
	for entry in entries:
		entry.node.set_blend_shape_value(0,sad)
		entry.node.set_blend_shape_value(1,lips)
		entry.node.set_blend_shape_value(2,maxf(blink,smoothstep(26.5,28.0,t)))

func restore() -> void:
	for entry in entries:
		if is_instance_valid(entry.node): entry.node.mesh = entry.original
	entries.clear()
