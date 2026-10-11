extends "res://characters/npcs/thana/thana_officer.gd"
## Existing full MPFB police body seated on the live saddle, reins and stirrups.
var patrol_mount: Node3D
var dismount_age := -1.0
var dismount_from := Vector3.ZERO
var dismount_to := Vector3.ZERO
var mount_age := -1.0
var mount_from := Vector3.ZERO
var pose_elapsed := 0.0
func _ready() -> void:
	super._ready()
	process_priority=110
	if foot_plant.legs.is_empty(): foot_plant.configure(_skeleton)
func _process(delta: float) -> void:
	pose_elapsed+=delta
	var essential:bool=mount_age>=0 or dismount_age>=0 or get_meta("police_engaged",false)
	if pose_elapsed<preload("res://systems/simulation_budget.gd").interval(self,get_viewport().get_camera_3d(),essential):return
	delta=pose_elapsed;pose_elapsed=0.0
	super._process(delta)
	if dismount_age>=0:
		dismount_age+=delta
		var t := smoothstep(0.0,1.0,minf(dismount_age,1.0))
		global_position=dismount_from.lerp(dismount_to,t)+Vector3.UP*sin(t*PI)*.12
		for side in ["l","r"]:
			for entry in [["thigh_",-1.35],["calf_",1.45]]:
				var bone: String=entry[0]+side
				var index := _skeleton.find_bone(bone)
				if index>=0:_skeleton.set_bone_pose_rotation(index,_base_rotations[bone]*Quaternion(_pitch_axes[bone],entry[1]*(1.0-t)))
		body_collider.force_update_transform()
		if dismount_age>=1.0:
			dismount_age=-1;body_collider.collision_layer=1;set_meta("police_dismounting",false)
		return
	if not is_instance_valid(patrol_mount) or patrol_mount.vitality.dead: return
	if get_meta("dead",false) or get_meta("knocked_out",false): return
	travel_speed=0
	global_rotation.y=patrol_mount.global_rotation.y+PI
	for side in ["l","r"]:
		for entry in [["thigh_",-1.35],["calf_",1.45]]:
			var bone: String=entry[0]+side
			var index := _skeleton.find_bone(bone)
			if index>=0: _skeleton.set_bone_pose_rotation(index,_base_rotations[bone]*Quaternion(_pitch_axes[bone],entry[1]))
	var pelvis := _skeleton.find_bone("pelvis")
	var hip := _skeleton.to_global(_skeleton.get_bone_global_pose(pelvis).origin)
	var seated:Vector3=global_position+patrol_mount.seat_world()-hip
	if mount_age>=0:
		mount_age+=delta
		global_position=mount_from.lerp(seated,smoothstep(0.0,1.0,minf(mount_age,1.0)))
		if mount_age>=1.0:mount_age=-1.0;set_meta("police_mounting",false)
	else:global_position=seated
	for side in ["l","r"]:
		if foot_plant.legs.has(side): foot_plant._solve(foot_plant.legs[side],_skeleton.to_local(patrol_mount.stirrup_world(side)+Vector3.UP*.10))
		solve_hand_contact(side,patrol_mount.riding_rein_world(side))
		set_grip(side,.7)
	body_collider.force_update_transform()

func begin_dismount(at: Vector3) -> void:
	patrol_mount=null
	if get_meta("dead",false) or get_meta("knocked_out",false):
		global_position=at;body_collider.collision_layer=1;return
	dismount_from=global_position;dismount_to=at;dismount_age=0
	set_meta("police_dismounting",true)

func begin_mount(horse: Node3D) -> void:
	patrol_mount=horse;mount_from=global_position;mount_age=0.0
	body_collider.collision_layer=8;set_meta("police_mounting",true)
