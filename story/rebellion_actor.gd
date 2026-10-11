extends "res://characters/npcs/households/household_npc_actor.gd"
## Complete MPFB mission actor; authored contact runs after locomotion evaluation.
var riding_cart: Node3D
var riding_socket: Node3D
var driving=false
var rope_contact=Vector3.ZERO
var rope_axis=Vector3.FORWARD
const ContactBudget=preload("res://systems/simulation_budget.gd")
var viewer: Node3D
var contact_elapsed=0.0
var held_rifle: Node3D
var dropped=false
var practice_target=Vector3.ZERO
var practice_clock=0.0
func _ready() -> void:
 super._ready();process_priority=120
 if get_meta("rebellion_guard",false):
  var vitality=get_node("Vitality");var fields: Dictionary={}
  for field in ["actor","skeleton","spine_bone","pelvis_bone","neck_bone","head_bone","torso_shape","head_shape","hit_body"]:fields[field]=vitality.get(field)
  vitality.set_script(preload("res://story/rebellion_vitality.gd"))
  for field in fields:vitality.set(field,fields[field])
func _process(delta: float) -> void:
 contact_elapsed+=delta
 if contact_elapsed<ContactBudget.interval(self,viewer,is_instance_valid(riding_socket) or rope_contact!=Vector3.ZERO):return
 delta=contact_elapsed;contact_elapsed=0
 super._process(delta)
 if _skeleton==null:return
 if get_meta("dead",false) or get_meta("knocked_out",false):
  if not dropped:
   var weapon=held_rifle
   if weapon!=null:weapon.position=Vector3(.6,.1,0);weapon.rotation=Vector3(0,.35,0)
   dropped=true
  return
 if get_meta("grappled",false):
  if is_instance_valid(held_rifle):held_rifle.position=Vector3(.6,.1,0);held_rifle.rotation=Vector3(0,.35,0)
  var phase: float=get_meta("mission_grapple_phase",0.0)
  _skeleton.set_bone_pose_rotation(_bones["head"],_base_rotations["head"]*Quaternion(_yaw_axes["head"],-.45*smoothstep(.35,.8,phase)))
  return
 if is_instance_valid(riding_socket):
  travel_speed=0;foot_plant_enabled=false;global_rotation.y=riding_socket.global_rotation.y+PI
  for side in ["l","r"]:
   for pair in [["thigh_",-1.45],["calf_",1.45]]:
    var bone: String=pair[0]+side
    _skeleton.set_bone_pose_rotation(_bones[bone],_base_rotations[bone]*Quaternion(_pitch_axes[bone],pair[1]))
  _skeleton.force_update_all_bone_transforms()
  var pelvis=_skeleton.find_bone("pelvis")
  global_position+=riding_socket.global_position+Vector3.UP*.10-_skeleton.to_global(_skeleton.get_bone_global_pose(pelvis).origin)
  for side in ["l","r"]:
   var foot=riding_socket.global_position+riding_cart.global_basis*Vector3(-.18 if side=="l" else .18,-.65,-.35)
   foot_plant._solve(foot_plant.legs[side],_skeleton.to_local(foot))
   solve_hand_contact(side,riding_cart.rein_grip_world(side) if driving else to_global(Vector3(-.2 if side=="r" else .2,.75,.25)));set_grip(side,.6 if driving else .15)
 elif rope_contact!=Vector3.ZERO:
  for side in ["l","r"]:
   for pair in [["thigh_",-.4],["calf_",.75]]:
    var bone: String=pair[0]+side;_skeleton.set_bone_pose_rotation(_bones[bone],_base_rotations[bone]*Quaternion(_pitch_axes[bone],pair[1]))
  for side in ["l","r"]:solve_hand_contact(side,rope_contact+rope_axis*(.16 if side=="l" else -.16));set_grip(side,.8)
 else:
  foot_plant_enabled=true
  var gun=get_node_or_null("RebelEnfield") as Node3D
  if gun!=null:
   practice_clock+=delta
   var phase=fmod(practice_clock,12.0)
   if practice_target!=Vector3.ZERO:
    var offset: Vector3=practice_target-global_position;global_rotation.y=atan2(offset.x,offset.z)
   var aiming=practice_target!=Vector3.ZERO and phase<5
   var barrel: Vector3=global_basis.z if aiming else (global_basis.z*.35+Vector3.UP*.936).normalized();var side=barrel.cross(Vector3.UP).normalized();var frame=Basis(barrel,side.cross(barrel).normalized(),side)
   var hand=to_global(Vector3(-.22,1,.18));gun.global_transform=Transform3D(frame.scaled(Vector3.ONE*.85),hand-frame*Vector3(-.09,-.045,0)*.85)
   solve_hand_contact("r",hand);solve_hand_contact("l",gun.to_global(Vector3(.8,.057,0) if practice_target!=Vector3.ZERO and phase>7 and phase<9 else Vector3(.20,-.032,0)));set_grip("r",.6);set_grip("l",.45)
