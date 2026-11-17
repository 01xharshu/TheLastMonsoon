extends RefCounted
## Geometric regression, supplemented by native 1.0x full-body review.
var knee_gap := INF
var hand_gap := INF
var elbow_gap := INF
var wrist_angle := 0.0
var knee_flex := 0.0
var elbow_flex := 0.0
var min_sole := INF
var planted_drift := 0.0
var pose_step := 0.0
var last: Dictionary = {}
var samples := 0
var worst := {}
var phase := ""

func sample(visual: Node, component: Node) -> void:
	var rig: Skeleton3D = visual.skeleton
	var frame: Transform3D = visual.actor.get_node("VisualRoot").global_transform.affine_inverse()
	var point := {}
	for name in ["pelvis","head","upperarm_l","upperarm_r","lowerarm_l","lowerarm_r","hand_l","hand_r","thigh_l","thigh_r","calf_l","calf_r","foot_l","foot_r"]:
		var index: int = visual.bones[name]
		point[name] = frame*rig.to_global(rig.get_bone_global_pose(index).origin)
		var rotation := rig.get_bone_pose_rotation(index)
		if last.has(name):
			var jump: float = (last[name] as Quaternion).angle_to(rotation)
			if jump > pose_step: worst.snap = "phase=%s bone=%s action=%s u=%.3f step=%.3f" % [phase,name,component.action,component.seat,jump]
			pose_step = maxf(pose_step,jump)
		last[name] = rotation
	if float(point.calf_l.x-point.calf_r.x) < knee_gap: worst.knee = "action=%s u=%.3f knee_l=%s knee_r=%s" % [component.action,component.seat,point.calf_l,point.calf_r]
	knee_gap = minf(knee_gap,float(point.calf_l.x-point.calf_r.x))
	if float(point.hand_l.x-point.hand_r.x) < hand_gap: worst.hand = "action=%s u=%.3f hand_l=%s hand_r=%s" % [component.action,component.seat,point.hand_l,point.hand_r]
	hand_gap = minf(hand_gap,float(point.hand_l.x-point.hand_r.x))
	elbow_gap = minf(elbow_gap,float(point.lowerarm_l.x-point.lowerarm_r.x))
	for side in ["l","r"]:
		var wrist: Quaternion = rig.get_bone_pose_rotation(visual.bones["hand_"+side])
		wrist_angle = maxf(wrist_angle,(visual.equipment.rest_rotations["hand_"+side] as Quaternion).angle_to(wrist))
		knee_flex = maxf(knee_flex,_flex(point["thigh_"+side],point["calf_"+side],point["foot_"+side]))
		elbow_flex = maxf(elbow_flex,_flex(point["upperarm_"+side],point["lowerarm_"+side],point["hand_"+side]))
		var foot: int = visual.bones["foot_"+side]
		var foot_pose := rig.global_transform*rig.get_bone_global_pose(foot)
		var contact: Node = visual.get_node("LocomotionFootContact")
		for local: Vector3 in contact.sole_points[side]: min_sole = minf(min_sole,(foot_pose*local).y-component.floor_world.y)
		if component.seat > 0.0 and preload("res://player/ground_idle_motion.gd").leg_fraction(component.seat,side) == 0.0 and component.foot_start.has(side):
			var rest := rig.get_bone_global_rest(foot)
			var sole: Vector3 = foot_pose*(rest.basis.inverse()*Vector3(0,-.085,.06))
			planted_drift = maxf(planted_drift,sole.distance_to(component.foot_start[side]))
	samples += 1

func _flex(a: Vector3,b: Vector3,c: Vector3) -> float:
	return PI-acos(clampf((a-b).normalized().dot((c-b).normalized()),-1.0,1.0))

func describe() -> String:
	print("JOINT EXTREMES ",worst)
	return "samples=%d knee_gap=%.3fm hand_gap=%.3fm elbow_gap=%.3fm wrist=%.3frad knee_flex=%.3f elbow_flex=%.3f min_boot=%.3fm planted_drift=%.3fm max_frame_rotation=%.3frad" % [samples,knee_gap,hand_gap,elbow_gap,wrist_angle,knee_flex,elbow_flex,min_sole,planted_drift,pose_step]
