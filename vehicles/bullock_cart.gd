extends "res://vehicles/horse_cart_candidate.gd"
## Paired draught cattle and existing goods cart; shared control/save/collision.
const Cattle=preload("res://assets/animals/cow/household_cow.glb")
var oxen:Array[Node3D]=[]
var solvers:Array[Node]=[]
var layout=preload("res://world/suryagarh/landscape_layout.gd").new()
var draft_phase:=0.0
var driver:Node3D
var last_draft_position:=Vector3.INF
var last_draft_yaw:=0.0
func _ready() -> void:
 variant=1;show_horse=false
 set_meta("bullock_cart",true)
 set_meta("draft_cruise_speed",1.6);set_meta("draft_fast_speed",2.4);set_meta("draft_reverse_speed",.65);set_meta("draft_acceleration",1.2)
 super._ready()
 add_to_group("bullock_carts")
 seat_sockets["CoachmanSeat"]=seat_sockets.DriverSeat
 var draft_shape:CollisionShape3D=boarding.clearance_shapes[1]
 draft_shape.shape=draft_shape.shape.duplicate();draft_shape.shape.size=Vector3(2.1,1.8,3.6);draft_shape.position=Vector3(0,1.1,-1.15)
 for side in [-1.0,1.0]:
  var ox:Node3D=Cattle.instantiate();ox.name="LeftBullock" if side<0 else "RightBullock";ox.position=Vector3(side*.62,0,-1.10);visual_root.add_child(ox)
  preload("res://animals/cow_visual.gd").apply(ox)
  for mesh in ox.find_children("*","MeshInstance3D",true,false):
   if "udder" in str(mesh.name).to_lower() or "teat" in str(mesh.name).to_lower():mesh.hide()
  var solver:=preload("res://animals/cow_motion.gd").new();solver.configure(self,ox);ox.add_child(solver);solver.set_physics_process(false)
  oxen.append(ox);solvers.append(solver)
  var health:=preload("res://animals/bullock_vitality.gd").new();health.name=ox.name+"Health";combat.add_child(health)
  health.configure(self,ox,ox.find_child("AnimationPlayer",true,false),ox.position,side)
  health.died.connect(combat._horse_died.bind(health));combat.horses.append(health)
 var wood:=_mat(Color(.25,.15,.07));var leather:=_mat(Color(.22,.12,.065))
 _beam("DraughtYoke",Vector3(-1.0,1.520,-1.98),Vector3(1.0,1.520,-1.98),.12,wood)
 _beam("CentralPole",Vector3(0,1.12,1.60),Vector3(0,1.520,-1.98),.09,wood)
 for side in [-1.0,1.0]:
  _beam("YokeBow",Vector3(side*.62-.235,1.500,-1.98),Vector3(side*.62-.235,1.03,-1.98),.035,wood)
  _beam("YokeBow",Vector3(side*.62+.235,1.500,-1.98),Vector3(side*.62+.235,1.03,-1.98),.035,wood)
  _beam("Rein",Vector3(side*.62,1.12,-2.66),_rein_grip_local("l" if side<0 else "r"),.012,leather)
 var previous:=get_node("FlexibleReins");remove_child(previous);previous.queue_free()
 var reins:=preload("res://vehicles/flexible_cart_reins.gd").new();reins.name="FlexibleReins";reins.configure(self);add_child(reins)
 _add_driver.call_deferred()
func _add_driver() -> void:
 var document:=GLTFDocument.new();var state:=GLTFState.new()
 var source:="res://characters/npcs/motion/village_farmer/village_farmer_rigged_candidate.glb"
 if document.append_from_file(ProjectSettings.globalize_path(source),state)!=OK:return
 driver=preload("res://vehicles/bullock_driver.gd").new();driver.name="MPFBBullockDriver";driver.coach=self;driver.set_meta("human_source",source);driver.add_child(document.generate_scene(state));visual_root.add_child(driver)
func set_forward_motion(speed:float,delta:float) -> void:
 super.set_forward_motion(speed,delta)
 if last_draft_position.is_finite() and global_position.distance_to(last_draft_position)>2:
  for solver in solvers:solver.planted.clear()
 var turn_rate:=absf(angle_difference(last_draft_yaw,global_rotation.y))/maxf(delta,.001) if last_draft_position.is_finite() else 0.0
 last_draft_position=global_position;last_draft_yaw=global_rotation.y
 var gait_speed:=maxf(absf(speed),minf(turn_rate*.72,.8))
 draft_phase=fmod(draft_phase+gait_speed*delta/.72,1.0)
 for index in solvers.size():
  if combat.horses[index].dead:continue
  var solver:Node=solvers[index]
  var rig:Skeleton3D=solver.rig
  for bone in solver.rest:rig.set_bone_pose_rotation(bone,solver.rest[bone])
  rig.set_bone_pose_position(rig.find_bone("Body"),solver.body_rest_position+Vector3.DOWN*.025)
  for tag in solver.ORDER:
   var phase:float=fmod(draft_phase+solver.OFFSETS[tag],1.0)
   var bone:int=solver.feet[tag][2];var target:Vector3=rig.to_global(rig.get_bone_global_rest(bone).origin)
   var moving:=gait_speed>.03
   if moving and phase<.64:
    if not solver.planted.has(tag):solver.planted[tag]=target-global_basis.z*.18*signf(speed)
    target=solver.planted[tag]
   else:
    solver.planted.erase(tag)
    if moving:
     var swing:float=(phase-.64)/.36
     target+=global_basis.z*lerpf(.18,-.18,swing)*signf(speed)
     target.y+=sin(swing*PI)*.10
   var lift:float=sin((phase-.64)/.36*PI)*.10 if moving and phase>=.64 else 0.0
   var ray:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(target.x,global_position.y+2,target.z),Vector3(target.x,global_position.y-2,target.z),1,boarding._vehicle_exclusions()))
   target.y=(ray.position.y if not ray.is_empty() else layout.height(target.x,target.z))+.085+lift
   solver._solve_leg(solver.feet[tag],target)
