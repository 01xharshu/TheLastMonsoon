extends "res://characters/npcs/households/household_npc_actor.gd"
## Original per-frame finger math and disabled-foot lookup for regression checks.
func _ready()->void:
	super._ready()
	foot_plant=preload("res://tools/characters/npc_foot_disabled_reference.gd").new()
	foot_plant.configure(_skeleton)
func _pose_fingers()->void:
	for index in _finger_rest:
		var finger_name:=_skeleton.get_bone_name(index)
		var curl:=.95 if get_meta("combat_action","")=="strike" else (0.22 if "_01_" in finger_name else (0.32 if "_02_" in finger_name else 0.18))
		if finger_name.begins_with("thumb"):curl*=.55
		_skeleton.set_bone_pose_rotation(index,_finger_rest[index]*Quaternion(_finger_pitch[index],curl))
