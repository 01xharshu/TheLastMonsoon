extends Node3D
## Camera-local arms reuse Arjun's skin, rig poses, and held equipment.
## The world body never rotates in response to this view model.
const Equipment = preload("res://player/arjun_equipment.gd")
var source: Node3D
var skeleton: Skeleton3D
var equipment: Node3D
var arm_mesh_count := 0

func setup(character: Node3D) -> void:
	source = character
	var model = preload("res://characters/arjun/arjun.glb").instantiate()
	add_child(model)
	model.rotation.y = PI
	model.position = Vector3(0, -1.46, -0.28)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	for animation in model.find_children("*", "AnimationPlayer", true, false):
		animation.stop()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		_keep_arms(node)
	equipment = Equipment.new()
	add_child(equipment)
	equipment.inventory = source.actor.inventory
	equipment.setup(skeleton)
	# Update after the world animation has applied its weapon grip.
	process_priority = 10

func _keep_arms(node: MeshInstance3D) -> void:
	if node.skin == null:
		node.hide()
		return
	var arm_binds: Dictionary = {}
	for i in node.skin.get_bind_count():
		var bone := String(node.skin.get_bind_name(i))
		if bone.begins_with("lowerarm_") or bone.begins_with("hand_") or bone.begins_with("thumb_") or bone.begins_with("index_") or bone.begins_with("middle_") or bone.begins_with("ring_") or bone.begins_with("pinky_"):
			arm_binds[i] = true
	var mesh := ArrayMesh.new()
	for surface in node.mesh.get_surface_count():
		var arrays := node.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		if weights.is_empty(): continue
		var count: int = weights.size() / vertices.size()
		var keep := PackedByteArray()
		keep.resize(vertices.size())
		for v in vertices.size():
			var arm_weight := 0.0
			for w in count:
				if arm_binds.has(joints[v * count + w]): arm_weight += weights[v * count + w]
			keep[v] = 1 if arm_weight > 0.55 else 0
		if indices.is_empty():
			for v in vertices.size(): indices.append(v)
		var filtered := PackedInt32Array()
		for triangle in range(0, indices.size(), 3):
			if keep[indices[triangle]] and keep[indices[triangle + 1]] and keep[indices[triangle + 2]]:
				filtered.append_array(indices.slice(triangle, triangle + 3))
		if filtered.is_empty(): continue
		arrays[Mesh.ARRAY_INDEX] = filtered
		var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if count == 8 else 0
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		mesh.surface_set_material(mesh.get_surface_count() - 1, node.get_active_material(surface))
	if mesh.get_surface_count() == 0:
		node.hide()
	else:
		node.mesh = mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arm_mesh_count += 1

func _process(_delta: float) -> void:
	if not visible or skeleton == null: return
	for i in skeleton.get_bone_count():
		skeleton.set_bone_pose_rotation(i, source.skeleton.get_bone_pose_rotation(i))
		skeleton.set_bone_pose_position(i, source.skeleton.get_bone_pose_position(i))
	equipment.selected = source.equipment.selected
	equipment.stowed = source.equipment.stowed
	equipment._refresh()
	# Only held weapons belong in the camera view; carried weapons stay on the body.
	equipment.talwar_waist.hide()
	equipment.enfield_back.hide()
