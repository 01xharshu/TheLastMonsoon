extends "res://characters/npcs/households/household_npc_actor.gd"
## Existing MPFB official with restrained additive attitude/gesture over idle.
var attitude := "neutral"
var speaking := false
var acting_age := 0.0
var seated:=true
var seat_weight:=1.0
var attention:=Vector3.ZERO
func _ready() -> void:
	movement_enabled=false
	set_meta("combat_faction","british")
	set_meta("external_combat_motion",true)
	super._ready()
	# This candidate's long forelock covers an eye. Keep the hat and body;
	# suppress the separate hair shell for these chamber instances only.
	var hair: Node3D=find_child("Official_hair",true,false)
	if hair!=null:hair.hide()
func _process(delta: float) -> void:
	super._process(delta)
	if _skeleton==null or get_meta("dead",false) or get_meta("knocked_out",false):return
	acting_age+=delta
	seat_weight=move_toward(seat_weight,1.0 if seated else 0.0,delta/0.8)
	if seat_weight>.001 and foot_plant.legs.has("l"):
		for side in ["l","r"]:
			for pair in [["thigh_",-1.35],["calf_",1.5],["foot_",-.15]]:
				var bone: String=pair[0]+side
				_skeleton.set_bone_pose_rotation(_bones[bone],_base_rotations[bone]*Quaternion(_pitch_axes[bone],pair[1]*seat_weight))
		for side in ["l","r"]:
			var ankle:=to_global(Vector3(.17 if side=="l" else -.17,.55,.45))
			ankle.y=global_position.y+.55
			foot_plant._solve(foot_plant.legs[side],_skeleton.to_local(ankle))
		var collision: CollisionShape3D=body_collider.get_node("BodyShape")
		collision.shape.height=1.1;collision.position.y=.8
	else:
		var collision: CollisionShape3D=body_collider.get_node("BodyShape")
		collision.shape.height=1.7;collision.position.y=.9
	var sneer: float=1.0 if attitude=="mocking" else 0.0
	var head_angle: float=.06*sneer+sin(acting_age*1.7)*.012*sneer
	_skeleton.set_bone_pose_rotation(_bones["head"],_base_rotations["head"]*Quaternion(_pitch_axes["head"],head_angle))
	if attention!=Vector3.ZERO:
		var local:=to_local(attention)
		var yaw:=clampf(atan2(local.x,local.z),-.65,.65)
		_skeleton.set_bone_pose_rotation(_bones["head"],_skeleton.get_bone_pose_rotation(_bones["head"])*Quaternion(_yaw_axes["head"],yaw))
	if speaking:
		var contact:=global_position+global_basis*Vector3(-.24,1.02,.32)
		solve_hand_contact("r",contact+Vector3.UP*sin(acting_age*2)*.025)
		set_grip("r",.12)
