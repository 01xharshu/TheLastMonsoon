extends "res://combat/mounted_police_actor.gd"
var firearm: Node
var riding_age=0.0
var torso_turn=0.0
var weapon_hand_pass=false
func _process(delta: float) -> void:
 set_meta("riding_reins_released",is_instance_valid(firearm))
 super._process(delta)
 if is_instance_valid(patrol_mount) and not patrol_mount.vitality.dead and dismount_age<0 and not get_meta("dead",false) and not get_meta("knocked_out",false):
  # Flush the sampled animation before reading the pelvis. Deferred skeleton
  # evaluation otherwise leaves an occasional visible gap after a hit/reload.
  _skeleton.force_update_all_bone_transforms()
  if mount_age<0:
   var hip:Vector3=_skeleton.to_global(_skeleton.get_bone_global_pose(foot_plant.pelvis).origin)
   var correction:Vector3=patrol_mount.seat_world()-hip
   if correction.length_squared()>.000004:
    global_position+=correction
    for side in ["l","r"]:foot_plant._solve(foot_plant.legs[side],_skeleton.to_local(patrol_mount.stirrup_world(side)+Vector3.UP*.10))
    body_collider.force_update_transform()
  riding_age+=delta
  var effort:float=clampf(patrol_mount.pace/13.0,0,1)
  var turn:=0.0
  if is_instance_valid(firearm) and firearm.can_engage():
   var local:Vector3=global_basis.inverse()*(firearm.target.global_position-global_position)
   turn=clampf(atan2(local.x,local.z),-.55,.55)
  torso_turn=lerp_angle(torso_turn,turn,1-exp(-8*delta))
  for part in [["spine_02",1.0]]:
   var bone:String=part[0];var index:int=_bones.get(bone,-1)
   if index>=0 and _base_rotations.has(bone) and _pitch_axes.has(bone) and _yaw_axes.has(bone):
    _skeleton.set_bone_pose_rotation(index,_base_rotations[bone]*Quaternion(_pitch_axes[bone],(.08+.025*sin(riding_age*7))*effort)*Quaternion(_yaw_axes[bone],torso_turn*float(part[1])))
  if _bones.has("head") and _yaw_axes.has("head"):
   _skeleton.set_bone_pose_rotation(_bones.head,_base_rotations.head*Quaternion(_yaw_axes.head,torso_turn*.35))
 if is_instance_valid(firearm):
  weapon_hand_pass=true;firearm._process(delta);weapon_hand_pass=false
func solve_hand_contact(side:String,target_world:Vector3) -> void:
 # The rifle owns both hands. Do not solve each hand to the reins first and then
 # repeat the whole skeleton solve to undo it in the same frame.
 if not weapon_hand_pass and is_instance_valid(firearm) and is_instance_valid(patrol_mount) and dismount_age<0 and not patrol_mount.vitality.dead:return
 super.solve_hand_contact(side,target_world)
