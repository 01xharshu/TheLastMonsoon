extends Node3D
## Small paper cartridge carried by the left palm during the loading gesture.
var hand_offset := Transform3D.IDENTITY

func setup(palm_offset: Vector3, palm_basis: Basis) -> void:
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.64, 0.55, 0.39)
	paper.roughness = 0.96
	var fold := StandardMaterial3D.new()
	fold.albedo_color = Color(0.45, 0.37, 0.25)
	fold.roughness = 0.98
	var body := MeshInstance3D.new()
	body.name = "PaperTube"
	var tube := CylinderMesh.new()
	tube.top_radius = 0.009
	tube.bottom_radius = 0.010
	tube.height = 0.065
	tube.radial_segments = 12
	body.mesh = tube
	body.material_override = paper
	add_child(body)
	var sealed_end := MeshInstance3D.new()
	sealed_end.name = "FoldedEnd"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.003
	cone.bottom_radius = 0.009
	cone.height = 0.014
	cone.radial_segments = 12
	sealed_end.mesh = cone
	sealed_end.material_override = fold
	sealed_end.position.y = 0.039
	add_child(sealed_end)
	hand_offset = Transform3D(palm_basis, palm_offset + palm_basis * Vector3(0.0, 0.035, -0.045))
	set_as_top_level(true)
	visible = false

func update_loading(selected_weapon: int, stowed_weapon: bool, progress: float, weapon: Node3D = null) -> void:
	var loading: Dictionary = preload("res://player/enfield_loading_sequence.gd").state(progress)
	visible = selected_weapon == 1 and not stowed_weapon and loading.cartridge_visible
	if not visible: return
	var rig := get_parent() as Skeleton3D
	if weapon:
		# Paper is physical size, independent of the imported gun's scale.
		var pose: Transform3D = weapon.global_transform * loading.cartridge
		pose.basis = pose.basis.orthonormalized()
		global_transform = pose
		return
	var hand := rig.get_bone_global_pose(rig.find_bone("hand_l"))
	var pose := hand * hand_offset
	var index := rig.get_bone_global_pose(rig.find_bone("index_02_l")).origin
	var thumb := rig.get_bone_global_pose(rig.find_bone("thumb_02_l")).origin
	pose.origin = (index + thumb) * 0.5 + pose.basis.y * 0.022
	global_transform = rig.global_transform * pose
