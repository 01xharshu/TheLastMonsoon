extends Node
## One resident's walk, step, sit and work transitions; transport owns the timetable.
var actor:Node3D
var travel:Node
var seat_name:String
var side:float
var state:="home"
var path:Array[Vector3]=[]
var point:=0
var elapsed:=0.0
var start_at:Vector3
var transition_target:Vector3
var blocked_frames:=0
var last_obstacle:=""
var visited:Dictionary={}
var speed:=1.0
var sit_amount:=0.0
var pending_path:Array[Vector3]=[]

func configure(person:Node3D,owner_travel:Node,index:int) -> void:
 actor=person;travel=owner_travel;side=-1.0 if index==0 else 1.0
 seat_name="RearPassengerLeft" if index==0 else "RearPassengerRight"
 actor.set_process(false);change("home")

func change(next:String) -> void:
 state=next;elapsed=0;start_at=actor.global_position;visited[state]=true
 actor.set_meta("household_action",state)

func walk(points:Array[Vector3],label:String) -> void:
 if state=="work" and label=="leave_office":
  pending_path=points;transition_target=travel.office.to_global(Vector3(-2.35 if side<0 else 2.35,.24,.35));change("stand_from_desk");return
 path=points;point=0;actor.set("foot_plant_enabled",true)
 actor.get_node("BodyCollider/BodyShape").set_deferred("disabled",false)
 travel._passenger_cloth(actor,false);change(label)

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
 transition_target=travel.coach.to_global(Vector3(side*.55,1.25,2.77));change("stand_from_seat")

func tick(delta:float) -> void:
 if actor.get_meta("dead",false): return
 if state not in ["seated","sit_down","stand_from_seat","enter_coach"]:actor.set_meta("seated_coach",null)
 elapsed+=delta
 if state in ["leave_home","enter_office","leave_office","enter_home"]:
  if point>=path.size():
   if state in ["leave_home","leave_office"]:board()
   elif state=="enter_office":
    transition_target=travel.office.to_global(Vector3(-1.6 if side<0 else 1.6,-.13,.35));change("sit_at_desk")
   else:change("home")
   return
  var target:Vector3=path[point];var offset:=target-actor.global_position
  var motion:=offset.limit_length(speed*delta)
  if _clear_walk(motion):
   actor.global_position+=motion
   actor.set("travel_speed",motion.length()/maxf(delta,.001))
   if Vector2(offset.x,offset.z).length()>.01:actor.global_rotation.y=rotate_toward(actor.global_rotation.y,atan2(offset.x,offset.z),delta*3)
   actor.call("_set_animation",&"walk",delta)
   if actor.global_position.distance_to(target)<.03:point+=1
  else:
   blocked_frames+=1;actor.call("_set_animation",&"idle",delta)
 elif state=="climb_step":
  _move_transition(1.2,.0,delta)
  _pitch("thigh_l",-.75*sin(clampf(elapsed/1.2,0,1)*PI));_pitch("calf_l",.95*sin(clampf(elapsed/1.2,0,1)*PI))
  if elapsed>=1.2:
   transition_target=travel.coach.to_global(Vector3(side*.55,1.25,2.77));change("enter_coach")
 elif state=="enter_coach":
  _move_transition(1.2,.0,delta)
  _pitch("spine_02",.25);_pitch("thigh_r",-.55*sin(clampf(elapsed/1.2,0,1)*PI))
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
  _pitch("thigh_l",-.65*sin(clampf(elapsed/1.2,0,1)*PI))
  if elapsed>=1.2:transition_target=door_ground();change("step_to_ground")
 elif state=="step_to_ground":
  _move_transition(1.2,0,delta)
  if elapsed>=1.2:
   travel.coach.set_boarding_door(side,0);change("outside_coach")
 elif state=="sit_at_desk":
  _desk_transition(delta,clampf(elapsed/1.4,0,1))
  if elapsed>=1.4:change("work")
 elif state=="stand_from_desk":
  _desk_transition(delta,1-clampf(elapsed/1.4,0,1))
  if elapsed>=1.4:walk(pending_path,"leave_office")
 elif state=="work":
  actor.call("_set_animation",&"idle",delta)
  for suffix in ["l","r"]:_pitch("thigh_"+suffix,-1.5);_pitch("calf_"+suffix,1.5)
  _pitch("upperarm_r",-.4);_pitch("lowerarm_r",-.9+sin(elapsed*2)*.09)
 else:actor.call("_set_animation",&"idle",delta)
 actor.get_node("BodyCollider").force_update_transform()

func _move_transition(duration:float,seated:float,delta:float) -> void:
 var t:=smoothstep(0,1,clampf(elapsed/duration,0,1))
 actor.global_position=start_at.lerp(transition_target,t)
 actor.call("_set_animation",&"idle",delta)
 for suffix in ["l","r"]:
  _pitch("thigh_"+suffix,-1.5*seated);_pitch("calf_"+suffix,1.5*seated)
 var yaw:float=travel.coach.rotation.y+PI if seated>.2 else travel.coach.rotation.y-side*PI*.5
 actor.global_rotation.y=rotate_toward(actor.global_rotation.y,yaw,delta*3)

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
 query.transform=shape.global_transform;query.transform.origin+=Vector3.UP*.025
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
