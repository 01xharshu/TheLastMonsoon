extends "res://characters/npcs/households/household_npc_actor.gd"
## Complete MPFB mission actor; authored contact runs after locomotion evaluation.
var riding_cart: Node3D
var riding_socket: Node3D
var driving=false
var seated_foot_drop=.65
var seated_foot_forward=-.35
var rope_contact=Vector3.ZERO
var rope_axis=Vector3.FORWARD
const ContactBudget=preload("res://systems/simulation_budget.gd")
var viewer: Node3D
var contact_elapsed=0.0
var held_rifle: Node3D
var dropped=false
var practice_target=Vector3.ZERO
var practice_clock=0.0
var travel_scarf:MeshInstance3D
func _ready() -> void:
 super._ready();process_priority=120
 if get_meta("rebel_travel",false) and _skeleton!=null:
  travel_scarf=preload("res://story/rebel_travel_scarf.gd").fit(self,_skeleton)
  if get_meta("mangal_leader",false):apply_leader_palette()
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
 if is_instance_valid(travel_scarf):
  travel_scarf.visible=(is_instance_valid(riding_socket) and riding_socket.name!="MangalDiscussionSeat") or has_meta("mounted_vehicle")
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
 # Combat tree owns the body during a hit or strike; weapon practice must
 # not pull the hands out of that reaction on the next frame.
 if not is_instance_valid(riding_socket) and rope_contact==Vector3.ZERO and get_meta("combat_action","") in ["hit","strike","fall","down","rise"]:return
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
   var foot=riding_socket.global_position+riding_cart.global_basis*Vector3(-.18 if side=="l" else .18,-seated_foot_drop,seated_foot_forward)
   if riding_socket.name=="MangalDiscussionSeat":
    foot=riding_socket.global_position+global_basis*Vector3(-.15 if side=="l" else .15,-.225,.36)
   if riding_cart.get_meta("consignment_cart",false):
    var index:int=_bones["foot_"+side];var rest:Transform3D=_skeleton.get_bone_global_rest(index)
    var up:Vector3=(_skeleton.global_basis.inverse()*riding_cart.global_basis.y).normalized()
    var basis:=Basis(Quaternion(Vector3.UP,up))*rest.basis
    var offset:Vector3=rest.basis.inverse()*Vector3(0,-.085,.06)
    foot_plant._solve(foot_plant.legs[side],_skeleton.to_local(foot)-basis*offset)
    var parent:int=_skeleton.get_bone_parent(index)
    _skeleton.set_bone_pose_rotation(index,(_skeleton.get_bone_global_pose(parent).basis.inverse()*basis).orthonormalized().get_rotation_quaternion())
    _skeleton.force_update_all_bone_transforms()
   else:foot_plant._solve(foot_plant.legs[side],_skeleton.to_local(foot))
   solve_hand_contact(side,riding_cart.rein_grip_world(side) if driving else to_global(Vector3(-.2 if side=="r" else .2,.75,.25)));set_grip(side,.6 if driving else .15)
  if get_meta("mangal_briefing",false):
   var cue:=pow(maxf(0.0,sin(Time.get_ticks_msec()*.003)),2.0)
   solve_hand_contact("r",to_global(Vector3(-.28,.77+cue*.16,.34+cue*.14)))
   set_grip("r",.15+cue*.13)
  if get_meta("hideout_discussing",false) and _bones.has("head"):
   var head:int=_bones["head"]
   _skeleton.set_bone_pose_rotation(head,_base_rotations["head"]*Quaternion(_yaw_axes["head"],-.28+.04*sin(Time.get_ticks_msec()*.002))*Quaternion(_pitch_axes["head"],.04*sin(Time.get_ticks_msec()*.003)))
  var camp_task:String=str(get_meta("hideout_task",""))
  if camp_task in ["planning","rifle_check","rest"]:
   var head:int=_skeleton.find_bone("head")
   if head>=0:_skeleton.set_bone_pose_rotation(head,_base_rotations["head"]*Quaternion(_pitch_axes["head"],.16 if camp_task!="rest" else -.06))
   if camp_task=="rifle_check" and is_instance_valid(held_rifle):
    held_rifle.position=Vector3(-.48,.74,.32);held_rifle.rotation=Vector3.ZERO
    solve_hand_contact("l",to_global(Vector3(.22,.78,.32)))
    solve_hand_contact("r",to_global(Vector3(-.16+.08*sin(Time.get_ticks_msec()*.002),.78,.32)))
   elif camp_task=="planning":
    solve_hand_contact("r",to_global(Vector3(-.15,.73,.38)))
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
   var hand:=to_global(Vector3(-.22,1,.18))
   var barrel: Vector3=(practice_target-hand).normalized() if aiming else (global_basis.z*.35+Vector3.UP*.936).normalized();var side=barrel.cross(Vector3.UP).normalized();var frame=Basis(barrel,side.cross(barrel).normalized(),side)
   gun.global_transform=Transform3D(frame.scaled(Vector3.ONE*.85),hand-frame*Vector3(-.09,-.045,0)*.85)
   solve_hand_contact("r",hand);solve_hand_contact("l",gun.to_global(Vector3(.8,.057,0) if practice_target!=Vector3.ZERO and phase>7 and phase<9 else Vector3(.20,-.032,0)));set_grip("r",.6);set_grip("l",.45)

func apply_leader_palette() -> void:
 for mesh:MeshInstance3D in find_children("*","MeshInstance3D",true,false):
  var tint:=Color.WHITE
  match str(mesh.name):
   "Fitted cotton upper base":tint=Color(.74,.68,.49)
   "Soft cotton head wrap","Head wrap fold":tint=Color(1.15,1.1,.78)
   _:continue
  for index in mesh.mesh.get_surface_count():
   var source:=mesh.get_active_material(index) as StandardMaterial3D
   if source==null:continue
   var variant:=source.duplicate() as StandardMaterial3D
   variant.albedo_color=Color(.48,.33,.17) if "wrap" in str(mesh.name).to_lower() else variant.albedo_color*tint
   mesh.set_surface_override_material(index,variant)
