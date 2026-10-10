extends Node
## One resident's walk, step, sit and work transitions; transport owns the timetable.
var actor:Node3D
var travel:Node
var seat_name:String
var side:float
var office_side:float
var state:="home"
var path:Array[Vector3]=[]
var point:=0
var elapsed:=0.0
var start_at:Vector3
var step_feet:Dictionary={}
var transition_target:Vector3
var blocked_frames:=0
var last_obstacle:=""
var visited:Dictionary={}
var speed:=1.0
var sit_amount:=0.0
var stagger:=0.0
var pending_path:Array[Vector3]=[]
var home_door:Node3D
var door_wait_frames:=0

func configure(person:Node3D,owner_travel:Node,index:int) -> void:
 actor=person;travel=owner_travel;side=-1.0 if index==0 else 1.0;office_side=side
 stagger=index*3.0
 seat_name="RearPassengerLeft" if index==0 else "RearPassengerRight"
 actor.set_process(false);change("home")

func change(next:String) -> void:
 state=next;elapsed=0;start_at=actor.global_position;visited[state]=true
 actor.set_meta("household_action",state)
 var conversation:=actor.get_node_or_null("HouseholdConversation")
 if conversation!=null:
  conversation.position.z=-.55 if state=="work" else .55;conversation.refresh_physics()
 if state in ["climb_step","enter_coach","climb_down","step_to_ground"]:
  var rig:Skeleton3D=actor.get("_skeleton")
  for suffix in ["l","r"]:step_feet[suffix]=rig.to_global(rig.get_bone_global_pose(rig.find_bone("foot_"+suffix)).origin)

func walk(points:Array[Vector3],label:String) -> void:
 if state=="work" and label=="leave_office":
  pending_path=points;transition_target=travel.office.to_global(Vector3(-2.35 if office_side<0 else 2.35,.24,.35));change("stand_from_desk");return
 path=points;point=0;actor.set("foot_plant_enabled",true)
 actor.get_node("BodyCollider/BodyShape").set_deferred("disabled",false)
 travel._passenger_cloth(actor,false);change(label);elapsed=-stagger

func door_ground() -> Vector3:
 return travel.coach.to_global(Vector3(side*1.9,0,2.77))

func board() -> void:
 travel.coach.set_boarding_door(side,1.0)
 actor.set("foot_plant_enabled",false)
 actor.get_node("BodyCollider/BodyShape").set_deferred("disabled",true)
 transition_target=travel.coach.to_global(Vector3(side*1.40,.645,2.77));change("climb_step")

func disembark() -> void:
 travel.coach.set_boarding_door(side,1.0)
 travel._passenger_cloth(actor,false)
 transition_target=travel.coach.to_global(Vector3(side*.55,1.37,2.77));change("stand_from_seat");elapsed=-stagger

func tick(delta:float) -> void:
 if actor.get_meta("dead",false): return
 if state not in ["seated","sit_down","stand_from_seat","enter_coach"]:actor.set_meta("seated_coach",null)
 elapsed+=delta
 if elapsed<0:return
 if state in ["leave_home","enter_office","leave_office","enter_home"]:
  if point>=path.size():
   if state in ["leave_home","leave_office"]:board()
   elif state=="enter_office":
    transition_target=_desk_root();change("sit_at_desk")
   else:change("home")
   return
  if not _home_door_ready():
   door_wait_frames+=1;actor.set("travel_speed",0.0);actor.call("_set_animation",&"idle",delta)
   travel._passenger_cloth(actor,false);return
  var target:Vector3=path[point];var offset:=target-actor.global_position
  var motion:=offset.limit_length(speed*delta)
  # Step-height sweep plus a floor ray keeps the feet on veranda/threshold levels.
  var ray:=PhysicsRayQueryParameters3D.create(actor.global_position+motion+Vector3.UP*.5,actor.global_position+motion-Vector3.UP*.5)
  ray.exclude=[actor.get_node("BodyCollider").get_rid(),travel.coach.boarding.collision_body.get_rid()]
  for person in travel.residents:ray.exclude.append(person.get_node("BodyCollider").get_rid())
  var floor_hit:=actor.get_world_3d().direct_space_state.intersect_ray(ray)
  if not floor_hit.is_empty() and floor_hit.normal.y>.7 and absf(floor_hit.position.y-actor.global_position.y)<=.31:
   motion.y=floor_hit.position.y+.012-actor.global_position.y
  if _clear_walk(motion):
   actor.global_position+=motion
   actor.set("travel_speed",motion.length()/maxf(delta,.001))
   if Vector2(offset.x,offset.z).length()>.01:actor.global_rotation.y=rotate_toward(actor.global_rotation.y,atan2(offset.x,offset.z),delta*3)
   actor.call("_set_animation",&"walk",delta)
   if Vector2(actor.global_position.x-target.x,actor.global_position.z-target.z).length()<.03:point+=1
  else:
   blocked_frames+=1;actor.call("_set_animation",&"idle",delta)
 elif state=="climb_step":
  _move_transition(1.2,.0,delta)
  _step_pose(1.2)
  if elapsed>=1.2:
   transition_target=travel.coach.to_global(Vector3(side*.55,1.37,2.77));change("enter_coach")
 elif state=="enter_coach":
  _move_transition(1.2,.0,delta)
  _pitch("spine_02",.4);_step_pose(1.2)
  if elapsed>=1.2:
   transition_target=_seat_root();change("sit_down")
 elif state=="sit_down":
  _move_transition(1.4,clampf(elapsed/1.4,0,1),delta)
  if elapsed>=1.4:
   travel._passenger_cloth(actor,true);travel.coach.set_boarding_door(side,0.0);change("seated")
 elif state=="seated":travel._seat(actor,seat_name,delta)
 elif state=="stand_from_seat":
  _move_transition(1.4,1-clampf(elapsed/1.4,0,1),delta)
  if elapsed>=1.4:
   transition_target=travel.coach.to_global(Vector3(side*1.4,.645,2.77));change("climb_down")
 elif state=="climb_down":
  _move_transition(1.2,0,delta)
  _step_pose(1.2)
  if elapsed>=1.2:transition_target=door_ground();change("step_to_ground")
 elif state=="step_to_ground":
  _move_transition(1.2,0,delta);_step_pose(1.2)
  if elapsed>=1.2:
   travel.coach.set_boarding_door(side,0);change("outside_coach")
 elif state=="sit_at_desk":
  _desk_transition(delta,clampf(elapsed/1.4,0,1))
  if elapsed>=1.4:
   travel._passenger_cloth(actor,true);change("work")
 elif state=="stand_from_desk":
  _desk_transition(delta,1-clampf(elapsed/1.4,0,1))
  if elapsed>=1.4:walk(pending_path,"leave_office")
 elif state=="work":
  actor.call("_set_animation",&"idle",delta)
  for suffix in ["l","r"]:_pitch("thigh_"+suffix,-1.5);_pitch("calf_"+suffix,1.5)
  _plant_seated_feet(travel.office.global_position.y+.24)
  _pitch("spine_02",.35)
  var paper: Vector3 = travel.office.to_global(Vector3(office_side*1.6+.08,1.12,-.08))
  _solve_work_hand(paper+Vector3(sin(elapsed*2)*.025,0,0))
  travel._passenger_cloth(actor,true)
 else:actor.call("_set_animation",&"idle",delta)
 travel._passenger_cloth(actor,state in ["work","seated"])
 actor.get_node("BodyCollider").force_update_transform()

func _home_door_ready() -> bool:
 if state not in ["leave_home","enter_home"]:return true
 if not is_instance_valid(home_door):
  var household:String=actor.get_meta("household","")
  var home:Node3D=travel.coach.get_parent().get_node_or_null(NodePath(household))
  if home!=null:home_door=home.get_node_or_null("EntranceDoor")
 if home_door==null:return true
 var gap:=Vector2(actor.global_position.x-home_door.global_position.x,actor.global_position.z-home_door.global_position.z).length()
 if gap>4.5:return true
 # Residents can leave from inside; an explicit exterior lock prevents re-entry.
 if state=="enter_home" and home_door.manual_locked:return false
 home_door.open_idle_seconds=0.0;home_door.set_open(true)
 return home_door.opened and not home_door.moving

func _move_transition(duration:float,seated:float,delta:float) -> void:
 var t:=smoothstep(0,1,clampf(elapsed/duration,0,1))
 actor.global_position=start_at.lerp(transition_target,t)
 actor.call("_set_animation",&"idle",delta)
 for suffix in ["l","r"]:
  _pitch("thigh_"+suffix,-1.5*seated);_pitch("calf_"+suffix,1.5*seated)
 var yaw:float=travel.coach.rotation.y+PI if seated>.2 else travel.coach.rotation.y-side*PI*.5
 actor.global_rotation.y=rotate_toward(actor.global_rotation.y,yaw,delta*3)
 if state in ["stand_from_seat","climb_down"]:_pitch("spine_02",.4*(1-seated))

func _pitch(bone:String,angle:float) -> void:
 var rig:Skeleton3D=actor.get("_skeleton")
 var bases:Dictionary=actor.get("_base_rotations");var axes:Dictionary=actor.get("_pitch_axes")
 if bases.has(bone):rig.set_bone_pose_rotation(rig.find_bone(bone),bases[bone]*Quaternion(axes[bone],angle))

func _seat_root() -> Vector3:
 var rig:Skeleton3D=actor.get("_skeleton")
 var pelvis:=rig.get_bone_global_pose(rig.find_bone("pelvis")).origin
 return travel.coach.seat_sockets[seat_name].global_position-actor.global_basis*(rig.transform*pelvis)

func _clear_walk(motion:Vector3) -> bool:
 var shape:CollisionShape3D=actor.get_node("BodyCollider/BodyShape")
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape
 query.transform=shape.global_transform;query.transform.origin+=Vector3.UP*.33
 query.motion=motion;query.margin=.005;query.collision_mask=1
 var exclude:Array[RID]=[travel.coach.boarding.collision_body.get_rid()]
 for person in travel.residents:exclude.append(person.get_node("BodyCollider").get_rid())
 query.exclude=exclude
 var result:=actor.get_world_3d().direct_space_state.cast_motion(query)
 if result[0]<.99:
  query.transform.origin+=motion*minf(1.0,result[0]+.1);query.motion=Vector3.ZERO
  var hits:=actor.get_world_3d().direct_space_state.intersect_shape(query,4)
  last_obstacle=str(hits.map(func(h):return str(h.collider.get_path())))
  if blocked_frames==0:print("JOURNEY_BLOCKED ",actor.name," ",state," ",actor.global_position," target ",path[point]," ",last_obstacle)
 return result[0]>=.99

func _desk_transition(delta:float,amount:float) -> void:
 actor.set("foot_plant_enabled",false)
 actor.get_node("BodyCollider/BodyShape").set_deferred("disabled",true)
 actor.global_position=start_at.lerp(transition_target,smoothstep(0,1,clampf(elapsed/1.4,0,1)))
 actor.global_rotation.y=rotate_toward(actor.global_rotation.y,PI,delta*3)
 actor.call("_set_animation",&"idle",delta)
 for suffix in ["l","r"]:_pitch("thigh_"+suffix,-1.5*amount);_pitch("calf_"+suffix,1.5*amount)
 _plant_seated_feet(travel.office.global_position.y+.24,amount)

func _plant_seated_feet(floor_y:float,amount:float=1.0) -> void:
 var rig:Skeleton3D=actor.get("_skeleton")
 var plant=actor.get("foot_plant")
 var worst:=0.0
 for suffix in ["l","r"]:
  if not plant.legs.has(suffix):continue
  var foot:=rig.find_bone("foot_"+suffix)
  var current:=rig.to_global(rig.get_bone_global_pose(foot).origin)
  var target:=current
  target.y=floor_y+(rig.transform*rig.get_bone_global_rest(foot).origin).y
  var blended:=current.lerp(target,clampf(amount,0,1))
  plant._solve(plant.legs[suffix],rig.to_local(blended))
  worst=maxf(worst,rig.to_global(rig.get_bone_global_pose(foot).origin).distance_to(blended))
 actor.set_meta("desk_feet_error_m",worst)

func _step_pose(duration:float) -> void:
 var t:=clampf(elapsed/duration,0,1)
 var rig:Skeleton3D=actor.get("_skeleton")
 # Lead foot reaches the next tread before the pelvis rises; rear foot follows.
 var pelvis_t:=smoothstep(0,.55,t) if transition_target.y<start_at.y else smoothstep(.45,1,t)
 actor.global_position=start_at.lerp(transition_target,pelvis_t)
 for suffix in ["l","r"]:
  var bone:=rig.find_bone("foot_"+suffix)
  var rest:=rig.get_bone_global_rest(bone).origin
  var target:=transition_target+actor.global_basis*(rig.transform*rest)
  var swing:=smoothstep(0,.55,t) if suffix=="l" else smoothstep(.45,1,t)
  var foot:Vector3=step_feet[suffix].lerp(target,swing)+Vector3.UP*(sin(swing*PI)*.08)
  _solve_leg(suffix,rig.to_local(foot))

func _solve_leg(suffix:String,target:Vector3) -> void:
 var plant=actor.get("foot_plant")
 if plant.legs.has(suffix):plant._solve(plant.legs[suffix],target)

func _solve_work_hand(target_world:Vector3) -> void:
 var rig:Skeleton3D=actor.get("_skeleton");var hand:=rig.find_bone("hand_r")
 var target:=rig.to_local(target_world)
 for iteration in 22:
  for label in ["lowerarm_r","upperarm_r"]:
   var index:=rig.find_bone(label);var pose:=rig.get_bone_global_pose(index)
   var palm:Vector3=rig.get_bone_global_pose(hand)*Vector3(0,.055,0)
   var desired:=Basis(Quaternion((palm-pose.origin).normalized(),(target-pose.origin).normalized()))*pose.basis
   var parent:=rig.get_bone_parent(index)
   if parent>=0:desired=rig.get_bone_global_pose(parent).basis.inverse()*desired
   rig.set_bone_pose_rotation(index,desired.orthonormalized().get_rotation_quaternion());rig.force_update_all_bone_transforms()
 actor.set_meta("desk_hand_error_m",(rig.get_bone_global_pose(hand)*Vector3(0,.055,0)).distance_to(target))

func _desk_root() -> Vector3:
 var rig:Skeleton3D=actor.get("_skeleton")
 var pelvis:=rig.get_bone_global_pose(rig.find_bone("pelvis")).origin
 return travel.office.to_global(Vector3(office_side*1.6,.75,.35))-Basis(Vector3.UP,PI)*(rig.transform*pelvis)
