extends "res://characters/npcs/households/household_npc_actor.gd"
## Grounded service idle with hand targets on an actual mixing vessel.
var work_time := 0.0
var left_contact: Marker3D
var right_contact: Marker3D
var spoon: Node3D

func _ready() -> void:
	super._ready()
	preload("res://characters/npcs/households/fort_staff_clothing.gd").new().dress(self)
	if household_job != "Cook": return
	left_contact = get_parent().get_node("FortKitchen/CookContactL")
	right_contact = get_parent().get_node("FortKitchen/CookContactR")
	spoon = Node3D.new()
	spoon.name="MixingSpoon"
	add_child(spoon)
	var handle := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius=.009
	mesh.bottom_radius=.014
	mesh.height=.25
	mesh.radial_segments=8
	handle.mesh=mesh
	var material := StandardMaterial3D.new()
	material.albedo_color=Color(.27,.15,.065)
	material.roughness=.9
	handle.material_override=material
	handle.position=Vector3(0,-.10,0)
	spoon.add_child(handle)
	var scoop := MeshInstance3D.new()
	var scoop_mesh := SphereMesh.new()
	scoop_mesh.radius=.023
	scoop_mesh.height=.012
	scoop.mesh=scoop_mesh
	scoop.material_override=material
	scoop.position.y=-.22
	spoon.add_child(scoop)

func _process(delta: float) -> void:
	super._process(delta)
	if _skeleton == null or left_contact == null: return
	work_time += delta
	# Express the lean in world space so an imported rig's bone roll cannot reverse it.
	var spine: int = _skeleton.find_bone("spine_02")
	var pose := _skeleton.get_bone_global_pose(spine)
	var forward := right_contact.global_position-global_position
	forward.y=0
	var axis := Vector3.UP.cross(forward.normalized()).normalized()
	var desired_world := Basis(axis,.42)*_skeleton.global_basis*pose.basis
	var desired := _skeleton.global_basis.inverse()*desired_world
	var parent := _skeleton.get_bone_parent(spine)
	if parent >= 0: desired=_skeleton.get_bone_global_pose(parent).basis.inverse()*desired
	_skeleton.set_bone_pose_rotation(spine,desired.orthonormalized().get_rotation_quaternion())
	_skeleton.force_update_all_bone_transforms()
	var target := right_contact.global_position+Vector3(sin(work_time*2.2)*.025,0,cos(work_time*2.2)*.025)
	solve_hand_contact("l",left_contact.global_position)
	solve_hand_contact("r",target)
	for index in _finger_rest:
		var name := _skeleton.get_bone_name(index)
		var curl := .65 if name.ends_with("_r") else .28
		if name.begins_with("thumb"): curl *= .45
		_skeleton.set_bone_pose_rotation(index,_finger_rest[index]*Quaternion(_finger_pitch[index],curl))
	spoon.global_position=target
	spoon.global_rotation=Vector3(.15,0,.08)
