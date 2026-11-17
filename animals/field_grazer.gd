extends "res://animals/draft_animal.gd"
## Existing animal identity/health/leading ownership, with bounded pasture behaviour.
const Budget=preload("res://systems/simulation_budget.gd")
var pasture:Node3D
var home:=Vector3.ZERO
var goal:=Vector3.ZERO
var viewer:Node3D
var elapsed:=0.0
var clock:=0.0
var state:="graze"
var remaining:=12.0
var head_weight:=0.0
var muzzle_error:=0.0
var rng:=RandomNumberGenerator.new()
var rig:Skeleton3D
var mouth_rest:=Vector3.ZERO
var neck_bones:Array[int]=[]
var horse_rest:Dictionary={}
var distance_walked:=0.0
var graze_seconds:=0.0
func build()->void:
 super.build()
 rng.seed=identity.hash();remaining=rng.randf_range(8,19);clock=rng.randf()*20
 viewer=pasture.get_parent().get_node_or_null("Player")
 rig=model.find_children("*","Skeleton3D",true,false)[0]
 # The draft bullock asset is shared; restore the female cow's complete surface.
 if kind=="bullock":
  for mesh:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
   if "udder" in str(mesh.name).to_lower() or "teat" in str(mesh.name).to_lower():mesh.show()
 else:
  for bone in rig.get_bone_count():horse_rest[bone]=rig.get_bone_pose_rotation(bone)
  var head:=rig.find_bone("Head")
  mouth_rest=rig.get_bone_global_rest(head).affine_inverse()*rig.to_local(to_global(Vector3(0,1.76,-1.6)))
  for label in ["Head","Neck3","Neck2","Neck1","Torso3"]:
   var index:=rig.find_bone(label)
   if index>=0:neck_bones.append(index)
 if animation:
  animation.stop();animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 for mesh:GeometryInstance3D in model.find_children("*","GeometryInstance3D",true,false):
  mesh.visibility_range_end=180;mesh.visibility_range_end_margin=20
func _physics_process(delta:float)->void:
 if vitality==null or vitality.dead or team!=null:return
 # Player leading remains authoritative and immediate, never throttled.
 if is_instance_valid(leader):
  head_weight=0;super._physics_process(delta)
  if animation:animation.advance(delta)
  state="pause";remaining=4;return
 elapsed+=delta
 if elapsed<Budget.interval(self,viewer):return
 var step:=elapsed;elapsed=0
 tick(step)
func tick(delta:float)->void:
 clock+=delta;remaining-=delta
 if state=="walk":
  var offset:=goal-global_position;offset.y=0
  if offset.length()<.3 or remaining<=0:
   state="graze";remaining=rng.randf_range(10,22)
  else:
   var yaw:=atan2(-offset.x,-offset.z)
   rotation.y=rotate_toward(rotation.y,yaw,delta*.65)
   var motion:=offset.normalized()*minf(.48*delta,offset.length()) if absf(angle_difference(rotation.y,yaw))<.15 else Vector3.ZERO
   # Swept collision includes fences, actors, other animals and saved scenery.
   var shape:CollisionShape3D=get_child(0)
   var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=shape.global_transform;query.motion=motion;query.collision_mask=1
   var ignored:Array[RID]=[get_rid(),vitality.hit_body.get_rid()]
   for body:CollisionObject3D in find_children("*","CollisionObject3D",true,false):ignored.append(body.get_rid())
   query.exclude=ignored
   var clear:=get_world_3d().direct_space_state.cast_motion(query)[0]>.99
   if motion.length_squared()>0 and clear and pasture.allowed(global_position+motion,self):
    global_position+=motion;distance_walked+=motion.length()
   elif motion.length_squared()>0:state="pause";remaining=3
 elif remaining<=0:
  if state=="graze":state="pause";remaining=rng.randf_range(2,5)
  else:
   goal=pasture.next_patch(self);state="walk";remaining=24
 global_position.y=pasture.ground(global_position)
 velocity=Vector3.ZERO
 pose(delta)
func pose(delta:float)->void:
 var walking:=state=="walk"
 var weight_target:=1.0 if state=="graze" else 0.0
 head_weight=move_toward(head_weight,weight_target,delta*.65)
 if kind=="bullock":
  cow_solver.update_breathing(delta,walking)
  for bone in cow_solver.rest:rig.set_bone_pose_rotation(bone,cow_solver.rest[bone])
  phase=fmod(phase+(.48 if walking else 0.0)*delta/.72,1)
  for tag in cow_solver.ORDER:
   var t:float=fmod(phase+cow_solver.OFFSETS[tag],1)
   var foot:Vector3=rig.to_global(rig.get_bone_global_rest(cow_solver.feet[tag][2]).origin)
   foot+=global_basis.z*sin(t*TAU)*.15 if walking else Vector3.ZERO
   foot.y=pasture.ground(foot)+.076+(maxf(0,sin(t*TAU))*.08 if walking else 0.0)
   cow_solver._solve_leg(cow_solver.feet[tag],foot)
  cow_solver.head_weight=head_weight
  var target:=to_global(Vector3(0,.09,-.7));target.y=pasture.ground(target)+.09
  if head_weight>0:cow_solver._head_contact(target)
  muzzle_error=cow_solver.contact_error
  var jaw:=rig.find_bone("Jaw")
  rig.set_bone_pose_rotation(jaw,cow_solver.rest[jaw]*Quaternion(Vector3.RIGHT,sin(clock*TAU)*.035*head_weight))
  var tail:=rig.find_bone("Tail")
  rig.set_bone_pose_rotation(tail,cow_solver.rest[tail]*Quaternion(Vector3.UP,sin(clock*1.3)*.13))
 else:
  for bone in horse_rest:rig.set_bone_pose_rotation(bone,horse_rest[bone])
  var clip:="AnimalArmature|Walk" if walking else "AnimalArmature|Idle"
  if animation.current_animation!=clip:
   animation.get_animation(clip).loop_mode=Animation.LOOP_LINEAR;animation.play(clip,.3)
  animation.advance(delta*(.18 if walking else 1.0))
  var target:=to_global(Vector3(0,.12,-.8));target.y=pasture.ground(target)+.12
  var head:=rig.find_bone("Head")
  var mouth:Vector3=rig.to_global(rig.get_bone_global_pose(head)*mouth_rest)
  var goal_mouth:=mouth.lerp(target,head_weight)
  for iteration in 16:
   for bone in neck_bones:
    var pivot:=rig.get_bone_global_pose(bone).origin
    var from:=rig.to_local(rig.to_global(rig.get_bone_global_pose(head)*mouth_rest))-pivot
    var to:=rig.to_local(goal_mouth)-pivot
    if minf(from.length_squared(),to.length_squared())<.00001:continue
    var rotation_basis:=Basis(Quaternion(from.normalized(),to.normalized()))*rig.get_bone_global_pose(bone).basis
    var parent:=rig.get_bone_parent(bone)
    if parent>=0:rotation_basis=rig.get_bone_global_pose(parent).basis.inverse()*rotation_basis
    rig.set_bone_pose_rotation(bone,rotation_basis.orthonormalized().get_rotation_quaternion());rig.force_update_all_bone_transforms()
   if rig.to_global(rig.get_bone_global_pose(head)*mouth_rest).distance_to(goal_mouth)<.005:break
  muzzle_error=rig.to_global(rig.get_bone_global_pose(head)*mouth_rest).distance_to(target)
 if head_weight>.99 and state=="graze":graze_seconds+=delta
 force_update_transform()

func export_grazing_state()->Dictionary:
 return {"state":state,"remaining":remaining,"clock":clock,"goal":[goal.x,goal.y,goal.z]}
func restore_grazing_state(record:Dictionary)->void:
 var saved_state:=str(record.get("state","graze"))
 state=saved_state if saved_state in ["graze","pause","walk"] else "graze"
 var duration:Variant=record.get("remaining",12.0)
 remaining=clampf(float(duration),0,25) if (duration is float or duration is int) and is_finite(float(duration)) else 12.0
 var saved_clock:Variant=record.get("clock",0.0)
 clock=maxf(0,float(saved_clock)) if (saved_clock is float or saved_clock is int) and is_finite(float(saved_clock)) else 0.0
 var values:Variant=record.get("goal",[])
 goal=global_position
 if values is Array and values.size()==3:
  var valid:=true
  for value in values:valid=valid and (value is int or value is float)
  if valid:
   var candidate:=Vector3(float(values[0]),float(values[1]),float(values[2]))
   if candidate.is_finite() and candidate.distance_to(home)<12 and pasture.allowed(candidate,self):goal=candidate
 head_weight=0
