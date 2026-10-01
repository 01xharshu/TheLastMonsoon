extends "res://characters/npcs/households/household_npc_actor.gd"
## Independent locomotion and contact on the existing MPFB thana rig.
var duty_state := "idle"
var detainee: CharacterBody3D
var hand_contact_error := 0.0
func _ready() -> void:
	movement_enabled = false
	super._ready()
	add_to_group("thana_officers")
func _process(delta: float) -> void:
	if get_meta("dead",false) or animation_tree == null: return
	_set_animation(&"walk" if travel_speed>.02 else &"idle",delta)
	if is_instance_valid(detainee) and duty_state in ["restraint","escort"]:
		if duty_state=="restraint":
			_skeleton.set_bone_pose_rotation(_bones["spine_02"],_base_rotations["spine_02"]*Quaternion(_pitch_axes["spine_02"],.70))
			_skeleton.force_update_all_bone_transforms()
		var visual: Node3D = detainee.get_node("VisualRoot/CharacterVisual")
		var rig: Skeleton3D = visual.skeleton
		var bone: String = "hand_l" if duty_state=="restraint" else "upperarm_l"
		var target := rig.to_global(rig.get_bone_global_pose(rig.find_bone(bone)).origin)
		if duty_state=="escort": target += detainee.global_basis*Vector3(.04,-.10,0)
		solve_hand_contact("r",target)
		set_grip("r",.25)
		hand_contact_error = palm_world("r").distance_to(target)
func take_damage(amount: float) -> void:
	super.take_damage(amount)
