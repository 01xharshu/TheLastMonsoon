extends "res://characters/npcs/households/household_npc_actor.gd"
## Existing MPFB official with restrained additive attitude/gesture over idle.
var attitude := "neutral"
var speaking := false
var acting_age := 0.0
func _ready() -> void:
	movement_enabled=false
	set_meta("combat_faction","british")
	super._ready()
	# This candidate's long forelock covers an eye. Keep the hat and body;
	# suppress the separate hair shell for these chamber instances only.
	var hair: Node3D=find_child("Official_hair",true,false)
	if hair!=null:hair.hide()
func _process(delta: float) -> void:
	super._process(delta)
	if _skeleton==null or get_meta("dead",false) or get_meta("knocked_out",false):return
	acting_age+=delta
	var sneer: float=1.0 if attitude=="mocking" else 0.0
	var head_angle: float=.06*sneer+sin(acting_age*4)*.025*sneer
	_skeleton.set_bone_pose_rotation(_bones["head"],_base_rotations["head"]*Quaternion(_pitch_axes["head"],head_angle))
	if speaking:
		var contact:=global_position+global_basis*Vector3(-.24,1.02,.32)
		solve_hand_contact("r",contact+Vector3.UP*sin(acting_age*2)*.025)
		set_grip("r",.12)
