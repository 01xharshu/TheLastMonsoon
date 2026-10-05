extends "res://characters/npcs/households/household_npc_actor.gd"
## Reuses the existing Blender MPFB farmer; no primitive human geometry.
var coach: Node3D
var driver_lean := .18
var driver_turn := 0.0
var driving_phase := 0.0
var foot_targets: Dictionary = {}
var seated_cloth = preload("res://vehicles/coachman_seated_cloth.gd").new()
func _ready() -> void:
 movement_enabled = false
 foot_plant_enabled = false
 household_job = "Coachman"
 super._ready()
 if foot_plant.legs.is_empty(): foot_plant.configure(_skeleton)
 body_collider.collision_layer = 0
 body_collider.collision_mask = 0
 body_collider.get_node("BodyShape").set_deferred("disabled",true)
 process_priority = 110
 seated_cloth.configure(self,coach)
func _process(delta: float) -> void:
 if not visible or coach == null or _skeleton == null or foot_plant.legs.is_empty(): return
 super._process(delta)
 driving_phase += delta
 var blend := 1.0-exp(-5.0*delta)
 var load: float = clampf(coach.boarding.rider_acceleration*.012,-.06,.06)
 driver_lean = lerpf(driver_lean,.18+load+sin(driving_phase*1.8)*.004,blend)
 driver_turn = lerpf(driver_turn,clampf(coach.boarding.rider_turn,-1.0,1.0)*.055,blend)
 _seat(self,"CoachmanSeat",delta)
 seated_cloth.update()
func _seat(actor:Node3D,socket_name:String,delta:float) -> void:
 if actor.get_meta("dead",false): return
 actor.set_meta("seated_coach",coach)
 actor.call("_set_animation",&"idle",delta)
 var skeleton:Skeleton3D=actor.get("_skeleton")
 var bases:Dictionary=actor.get("_base_rotations")
 var axes:Dictionary=actor.get("_pitch_axes")
 for side in ["l","r"]:
  for entry in [["thigh_",-1.5],["calf_",1.5]]:
   var bone:String=entry[0]+side
   var index:=skeleton.find_bone(bone)
   if index>=0:skeleton.set_bone_pose_rotation(index,bases[bone]*Quaternion(axes[bone],entry[1]))
 if socket_name=="CoachmanSeat":
  var spine:=skeleton.find_bone("spine_02")
  skeleton.set_bone_pose_rotation(spine,bases["spine_02"]*Quaternion(axes["spine_02"],driver_lean)*Quaternion(_yaw_axes["spine_02"],driver_turn))
  for side in ["l","r"]:
   for entry in [["upperarm_",-.5],["lowerarm_",-.7]]:
    var bone:String=entry[0]+side
    skeleton.set_bone_pose_rotation(skeleton.find_bone(bone),bases[bone]*Quaternion(axes[bone],entry[1]))
 var socket:Node3D=coach.seat_sockets[socket_name]
 actor.global_rotation.y=socket.global_rotation.y+PI
 var pelvis:=skeleton.find_bone("pelvis")
 var hip:Vector3=skeleton.to_global(skeleton.get_bone_global_pose(pelvis).origin)
 actor.global_position+=socket.global_position+coach.global_basis.y*.11-hip
 # Solve ankles after the pelvis is seated; targets travel with the footboard.
 for side in ["l","r"]:
  var target: Vector3 = foot_target_world(side)
  foot_targets[side] = target
  foot_plant._solve(foot_plant.legs[side],skeleton.to_local(target))
 if socket_name=="CoachmanSeat":
  for side in ["l","r"]:
   actor.call("solve_hand_contact",side,coach.rein_grip_world(side))
   actor.call("set_grip",side,.7)

func foot_target_world(side: String) -> Vector3:
 return coach.to_global(Vector3(-.18 if side == "l" else .18,1.46,.48))
