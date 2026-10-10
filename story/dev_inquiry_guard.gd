extends "res://characters/npcs/thana/thana_officer.gd"
## Existing complete MPFB private; shared Enfield carry, no additional firing AI.
const BUTT_CONTACT:=Vector3(-.362,-.054,0) # Exported butt-plate rear centre.
var cinematic_style:=""
var cinematic_phase:=0.0
var cinematic_target:=Vector3.ZERO
var cinematic_palms: Dictionary={}
var cinematic_carry:=false
var rifle: Node3D
func _ready() -> void:
	process_priority=95
	super._ready()
	rifle=preload("res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb").instantiate()
	rifle.name="GuardEnfield";add_child(rifle)
func _process(delta: float) -> void:
	super._process(delta)
	if rifle==null or _skeleton==null:return
	if get_meta("dead",false) or get_meta("knocked_out",false):return
	rifle.show()
	if not cinematic_style.is_empty():
		cinematic_attack(cinematic_style,cinematic_phase,cinematic_target)
		return
	if cinematic_carry:pose_carry()
	if not cinematic_palms.is_empty():
		var back_basis:=global_basis*Basis(Vector3(-.25,.968,0).normalized(),Vector3.FORWARD,Vector3(-.25,.968,0).normalized().cross(Vector3.FORWARD))
		rifle.global_transform=Transform3D(back_basis.scaled(Vector3.ONE*.85),to_global(Vector3(.16,.8,-.23)))
		for side in cinematic_palms:solve_hand_contact(side,cinematic_palms[side]);set_grip(side,.6)
		return
	if duty_state in ["restraint","escort","fight"]:
		var back_basis:=global_basis*Basis(Vector3(-.25,.968,0).normalized(),Vector3.FORWARD,Vector3(-.25,.968,0).normalized().cross(Vector3.FORWARD))
		rifle.global_transform=Transform3D(back_basis.scaled(Vector3.ONE*.85),to_global(Vector3(.16,.8,-.23)))
		return
	var barrel: Vector3=(global_basis.z*.32+Vector3.UP*.947).normalized()
	var side:=barrel.cross(Vector3.UP).normalized()
	var basis:=Basis(barrel,side.cross(barrel).normalized(),side)
	var contact:=to_global(Vector3(-.22,.98,.16))
	rifle.global_transform=Transform3D(basis.scaled(Vector3.ONE*.85),contact-basis*(Vector3(-.09,-.045,0)*.85))
	# The custody controller owns the hands during restraint and escort.
	solve_hand_contact("r",contact);set_grip("r",.35)
	solve_hand_contact("l",rifle.to_global(Vector3(.20,-.032,0)));set_grip("l",.35)

func pose_carry() -> void:
	_skeleton.set_bone_pose_position(foot_plant.pelvis,foot_plant.pelvis_position+foot_plant.pelvis_down*.22)
	_skeleton.force_update_all_bone_transforms()
	for side in ["l","r"]:
		var target: Vector3=_skeleton.to_global(_skeleton.get_bone_global_rest(_bones["foot_"+side]).origin)
		foot_plant._solve(foot_plant.legs[side],_skeleton.to_local(target))

# Called by the cinematic director after the locomotion graph has evaluated.
# Each attack has anticipation, a single contact moment and recovery.
func cinematic_attack(style: String, phase: float, target: Vector3) -> Vector3:
	cinematic_style=style;cinematic_phase=phase;cinematic_target=target
	var reach := smoothstep(.20,.48,phase)*(1.0-smoothstep(.58,1.0,phase))
	_skeleton.set_bone_pose_rotation(_bones["spine_02"],_base_rotations.spine_02*Quaternion(_pitch_axes.spine_02,.08+.16*reach))
	_skeleton.force_update_all_bone_transforms()
	if style=="rifle":
		# The stock follows the contact arc; both palms stay on the same weapon.
		var stock_rest:=to_global(Vector3(-.25,1.35,.28))
		var stock:=stock_rest.lerp(target,reach)
		var barrel: Vector3=(global_basis.z*(-.75+.45*reach)+Vector3.UP*(.65-.4*reach)).normalized()
		var side:=barrel.cross(Vector3.UP).normalized()
		var frame:=Basis(barrel,side.cross(barrel).normalized(),side)
		rifle.global_transform=Transform3D(frame.scaled(Vector3.ONE*.85),stock-frame*BUTT_CONTACT*.85)
		solve_hand_contact("r",rifle.to_global(Vector3(-.09,-.045,0)))
		solve_hand_contact("l",rifle.to_global(Vector3(.20,-.032,0)))
		set_grip("r",.8);set_grip("l",.8)
		return rifle.to_global(BUTT_CONTACT)
	if style=="kick":
		for pair in [["thigh_r",-1.25*reach],["calf_r",.55*(1.0-reach)],["foot_r",.12*reach]]:
			var bone: String=pair[0]
			_skeleton.set_bone_pose_rotation(_bones[bone],_base_rotations[bone]*Quaternion(_pitch_axes[bone],pair[1]))
		_skeleton.force_update_all_bone_transforms()
		var foot: int=_bones["foot_r"]
		# Reuse the existing two-bone contact solver for the striking ankle.
		var rest: Vector3=_skeleton.to_global(_skeleton.get_bone_global_pose(foot).origin)
		foot_plant._solve(foot_plant.legs["r"],_skeleton.to_local(rest.lerp(target,reach)))
		solve_hand_contact("r",to_global(Vector3(-.25,1.3,.20)))
		solve_hand_contact("l",to_global(Vector3(.25,1.3,.20)))
		set_grip("r",1);set_grip("l",1)
		return _skeleton.to_global(_skeleton.get_bone_global_pose(foot).origin)
	var fist:=to_global(Vector3(-.25,1.3,.25)).lerp(target,reach)
	solve_hand_contact("r",fist);set_grip("r",1)
	solve_hand_contact("l",to_global(Vector3(.22,1.3,.22)));set_grip("l",1)
	return palm_world("r")
