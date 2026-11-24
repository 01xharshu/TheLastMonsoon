extends RefCounted
## Mount key poses share a clock with the horse's travel and tack contacts.
const DURATION := 1.65
const BRACE := 0.24
const RISE := 0.49
const CROSS := 0.70
const STRADDLE := 0.86

# Columns after time: pelvis, lower spine, upper spine, head, near thigh,
# near calf, far thigh, far calf. X is pitch, Y yaw, Z roll in rig space.
const POSES := [
	[0.0, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO],
	[BRACE, Vector3(.02,.09,.035), Vector3(.14,.04,.055), Vector3(.05,0,.025), Vector3(-.09,.15,-.08), Vector3(-.35,0,.08), Vector3(.55,0,0), Vector3(-.12,0,-.05), Vector3(.24,0,0)],
	[RISE, Vector3(.08,.12,.15), Vector3(.63,.06,.28), Vector3(.24,0,.12), Vector3(-.15,.06,0), Vector3(-.24,0,.25), Vector3(.35,0,0), Vector3(.48,0,-.32), Vector3(.75,0,0)],
	[CROSS, Vector3(.14,.10,.04), Vector3(.57,.07,.15), Vector3(.28,0,.07), Vector3(-.16,0,0), Vector3(-.32,.15,.48), Vector3(.68,0,0), Vector3(.48,0,-1.05), Vector3(.77,0,0)],
	[STRADDLE, Vector3(.04,.04,0), Vector3(.24,0,0), Vector3(.10,0,0), Vector3(-.07,0,0), Vector3(-.35,.22,.55), Vector3(.90,0,0), Vector3(-.32,-.20,-.58), Vector3(.88,0,0)],
	[1.0, Vector3.ZERO, Vector3(.06,0,0), Vector3.ZERO, Vector3(.03,0,0), Vector3(-.35,.22,.55), Vector3(.90,0,0), Vector3(-.35,-.22,-.55), Vector3(.90,0,0)]
]

static func rein_pickup(t: float) -> float:
	return smoothstep(.74, 1.0, t)

static func configure(graph: AnimationNodeBlendTree, library: AnimationLibrary, rig: Skeleton3D, idle: Animation, base_layer: String) -> void:
	var sides := AnimationNodeBlendSpace1D.new()
	sides.blend_mode = AnimationNodeBlendSpace1D.BLEND_MODE_DISCRETE
	for side in ["l", "r"]:
		var clip_name: String = "horse_mount_" + side
		library.add_animation(clip_name, _make_clip(rig, idle, side))
		var clip := AnimationNodeAnimation.new()
		clip.animation = "motion/" + clip_name
		sides.add_blend_point(clip, -1.0 if side == "l" else 1.0, -1, side)
	graph.add_node("horse_mount_side", sides)
	graph.add_node("horse_mount_seek", AnimationNodeTimeSeek.new())
	graph.add_node("horse_mount", AnimationNodeBlend2.new())
	graph.connect_node("horse_mount_seek", 0, "horse_mount_side")
	graph.connect_node("horse_mount", 0, base_layer)
	graph.connect_node("horse_mount", 1, "horse_mount_seek")

static func _make_clip(rig: Skeleton3D, idle: Animation, near: String) -> Animation:
	var far := "r" if near == "l" else "l"
	var mirror := 1.0 if near == "l" else -1.0
	var clip := Animation.new()
	clip.length = DURATION
	var bones := ["pelvis", "spine_01", "spine_02", "head", "thigh_" + near, "calf_" + near, "thigh_" + far, "calf_" + far,
		"upperarm_" + near, "lowerarm_" + near, "upperarm_" + far, "lowerarm_" + far, "foot_" + near, "foot_" + far, "hand_" + near, "hand_" + far]
	for column in bones.size():
		var bone: String = bones[column]
		var index := rig.find_bone(bone)
		var path := NodePath("Arjun_Rig/Skeleton3D:" + bone)
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, path)
		clip.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		var idle_track := idle.find_track(path, Animation.TYPE_ROTATION_3D)
		var base: Quaternion = idle.track_get_key_value(idle_track, 0) if idle_track >= 0 else rig.get_bone_pose_rotation(index)
		var axes := rig.get_bone_global_rest(index).basis.orthonormalized().inverse()
		for beat in POSES:
			var t: float = beat[0]
			var angle := Vector3.ZERO
			if column < 8:
				angle = beat[column + 1]
			elif bone.begins_with("upperarm"):
				angle = Vector3(-.70, 0, -.34 if column == 8 else .34) * smoothstep(0, BRACE, t)
			elif bone.begins_with("lowerarm"):
				angle.x = -.55 * smoothstep(0, BRACE, t)
			var rotation := base * Quaternion(axes * Vector3.RIGHT, angle.x) * Quaternion(axes * Vector3.UP, angle.y * mirror) * Quaternion(axes * Vector3.BACK, angle.z * mirror)
			clip.rotation_track_insert_key(track, t * DURATION, rotation)
	return clip


static func prepare_trousers(model: Node3D) -> Array[MeshInstance3D]:
	var trousers: Array[MeshInstance3D] = []
	for node: MeshInstance3D in model.find_children("*DrapedTrousers*", "MeshInstance3D", true, false):
		var source := node.mesh
		if source == null or source.get_blend_shape_count() != 0: continue
		var fitted := ArrayMesh.new()
		fitted.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
		fitted.add_blend_shape("Stirrup and swing clearance")
		for surface in source.get_surface_count():
			var arrays := source.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in points.size():
				var height := points[i].y
				# Ease the thigh and knee folds. Keep the gathered waist and boot cuff pinned.
				var ease := .033 * smoothstep(.28, .45, height) * (1.0 - smoothstep(.75, .94, height))
				points[i] += Vector3(normals[i].x, 0, normals[i].z).normalized() * ease
			var shape := []
			shape.resize(Mesh.ARRAY_MAX)
			shape[Mesh.ARRAY_VERTEX] = points
			shape[Mesh.ARRAY_NORMAL] = normals
			shape[Mesh.ARRAY_TANGENT] = arrays[Mesh.ARRAY_TANGENT]
			fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [shape], {}, source.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			fitted.surface_set_material(surface, source.surface_get_material(surface))
		node.mesh = fitted
		trousers.append(node)
	return trousers

static func prepare_upper(model: Node3D) -> MeshInstance3D:
	var node := model.find_child("Arjun_Kurta_Upper", true, false) as MeshInstance3D
	if node == null or node.mesh == null or node.mesh.get_blend_shape_count() != 0: return null
	var source := node.mesh
	var fitted := ArrayMesh.new()
	fitted.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	fitted.add_blend_shape("Saddle reach sleeve ease")
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in points.size():
			var point := points[i]
			var sleeve := smoothstep(.25, .33, absf(point.x)) * (1.0 - smoothstep(.40, .45, absf(point.x)))
			var height := smoothstep(1.07, 1.16, point.y) * (1.0 - smoothstep(1.40, 1.49, point.y))
			points[i] += normals[i].normalized() * (.045 * sleeve * height)
		var shape := []
		shape.resize(Mesh.ARRAY_MAX)
		shape[Mesh.ARRAY_VERTEX] = points
		shape[Mesh.ARRAY_NORMAL] = normals
		shape[Mesh.ARRAY_TANGENT] = arrays[Mesh.ARRAY_TANGENT]
		fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [shape], {}, source.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		fitted.surface_set_material(surface, source.surface_get_material(surface))
	node.mesh = fitted
	return node

static func prepare_hem(model: Node3D) -> MeshInstance3D:
	var node := model.find_child("Arjun_Kurta_SplitHem", true, false) as MeshInstance3D
	if node == null or node.mesh == null or node.mesh.get_blend_shape_count() != 0: return null
	var source := node.mesh
	var fitted := ArrayMesh.new()
	fitted.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	fitted.add_blend_shape("Saddle swing hem ease")
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in points.size():
			var point := points[i]
			var ease := .045 * smoothstep(.75, .91, point.y) * (1.0 - smoothstep(1.035, 1.09, point.y))
			points[i] += Vector3(point.x, 0, point.z - .02).normalized() * ease
		var shape := []
		shape.resize(Mesh.ARRAY_MAX)
		shape[Mesh.ARRAY_VERTEX] = points
		shape[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL]
		shape[Mesh.ARRAY_TANGENT] = arrays[Mesh.ARRAY_TANGENT]
		fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [shape], {}, source.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		fitted.surface_set_material(surface, source.surface_get_material(surface))
	node.mesh = fitted
	return node

static func prepare_elbow_lining(model: Node3D, rig: Skeleton3D) -> MeshInstance3D:
	var body := model.find_child("Arjun_MakeHuman_Body", true, false) as MeshInstance3D
	var upper := model.find_child("Arjun_Kurta_Upper", true, false) as MeshInstance3D
	if body == null or upper == null or body.skin == null: return null
	var arms := []
	for side in ["l", "r"]:
		arms.append([rig.get_bone_global_rest(rig.find_bone("upperarm_" + side)).origin,
			rig.get_bone_global_rest(rig.find_bone("lowerarm_" + side)).origin])
	# A single dark fabric sample avoids interpolating across atlas islands on
	# the body-derived lining. The cloth shader supplies the fine weave.
	var upper_arrays := upper.mesh.surface_get_arrays(0)
	var upper_uvs: PackedVector2Array = upper_arrays[Mesh.ARRAY_TEX_UV]
	var fabric_uv := upper_uvs[0]
	var material := upper.get_active_material(0) as ShaderMaterial
	if material != null:
		var atlas := material.get_shader_parameter("base_atlas") as Texture2D
		if atlas != null:
			var atlas_image := atlas.get_image()
			if atlas_image != null and not atlas_image.is_empty():
				if atlas_image.is_compressed(): atlas_image.decompress()
				var best := INF
				for uv in upper_uvs:
					var color := atlas_image.get_pixel(clampi(int(uv.x * atlas_image.get_width()), 0, atlas_image.get_width() - 1), clampi(int(uv.y * atlas_image.get_height()), 0, atlas_image.get_height() - 1))
					var score := absf((color.r + color.g + color.b) / 3.0 - .035)
					if score < best:
						best = score
						fabric_uv = uv
	var lining := ArrayMesh.new()
	for surface in body.mesh.get_surface_count():
		var arrays := body.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var triangles := PackedInt32Array()
		for triangle in range(0, indices.size(), 3):
			var a := indices[triangle]
			var b := indices[triangle + 1]
			var c := indices[triangle + 2]
			for arm in arms:
				var start: Vector3 = arm[0]
				var end: Vector3 = arm[1]
				if Geometry3D.get_closest_point_to_segment(vertices[a], start, end).distance_to(vertices[a]) < .105 and Geometry3D.get_closest_point_to_segment(vertices[b], start, end).distance_to(vertices[b]) < .105 and Geometry3D.get_closest_point_to_segment(vertices[c], start, end).distance_to(vertices[c]) < .105:
					triangles.append_array(PackedInt32Array([a, b, c]))
					break
		if triangles.is_empty(): continue
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var mapped := {}
		for i in triangles:
			if mapped.has(i): continue
			mapped[i] = true
			uvs[i] = fabric_uv
			vertices[i] += normals[i] * .012
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_INDEX] = triangles
		lining.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, body.mesh.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		lining.surface_set_material(lining.get_surface_count() - 1, upper.get_active_material(0))
	if lining.get_surface_count() == 0: return null
	var node := MeshInstance3D.new()
	node.name = "SaddleReachElbowLining"
	node.mesh = lining
	node.skin = body.skin
	body.get_parent().add_child(node)
	node.transform = body.transform
	node.skeleton = body.skeleton
	node.visible = false
	return node
