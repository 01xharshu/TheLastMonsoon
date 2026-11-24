extends "res://world/suryagarh/settlements/street_journey.gd"
## Keep remote residents persistent at reduced update cadence, never crowd the centre.
const Livelihood = preload("res://world/suryagarh/street_livelihood.gd")
var port_hiring_owner: Node
var port_worker_key := ""
var livelihood_role: StringName = &""
const Budget = preload("res://systems/simulation_budget.gd")
var viewer: Node3D
var simulation_interval := 0.0
var tier_age := 0.0
var sweep_exclusions: Array[RID] = []
var terrain_revision := -1
var terrain_cache: Dictionary = {}
var accumulated := 0.0
const Ground = preload("res://world/suryagarh/tree_trunk_collision.gd")
var terrain_rids: Array[RID] = []
var waypoint_heights: Dictionary = {}
var detour := Vector2.INF
var detour_followup := Vector2.INF
var retry_age := 0.0
var detours := 0
var crowd: Node
var personal_seed := 0
var social_enabled := false
var social_partner: Node
var social_end := 0.0
var social_cooldown := 0.0
var social_speaker := false
var awareness_age := 0.0
var yield_age := 0.0
var social_time := 0.0
var social_voice_sent := false
var player_dialogue: Node
var shadow_meshes:Array[GeometryInstance3D]=[]
var shadow_modes:Array[int]=[]
var shadows_near:=true
var street_surface:RefCounted
var traffic_encounters:Node

func can_pause_for_peer() -> bool:
 if is_instance_valid(port_hiring_owner) and port_hiring_owner.port_shift_active(port_worker_key):return false
 if direction < 0 or wait > 0:
  return true
 return livelihood_role not in [&"clerk", &"domestic_worker", &"vendor"]

func _ready() -> void:
 super._ready()
 turn_in_place=false
 personal_seed=int(actor.get_meta("population_index",0))+int(actor.get_meta("street_identity",0))*17
 social_enabled=personal_seed%4<2
 social_cooldown=5.0+float(personal_seed%19)
 if is_instance_valid(crowd):
  crowd.register(self);player_dialogue=crowd.get_parent().get_node_or_null("PlayerStreetConversation")
 for mesh:GeometryInstance3D in actor.find_children("*","GeometryInstance3D",true,false):
  shadow_meshes.append(mesh);shadow_modes.append(mesh.cast_shadow)
 terrain_cache=Ground.terrain_cache(actor)
 terrain_rids=terrain_cache.rids
 sweep_exclusions = super.motion_exclusions()+terrain_rids
 terrain_revision=terrain_cache.revision
 if actor.get_script().resource_path=="res://characters/npcs/indian/indian_street_actor.gd":
  var world:Node=preload("res://systems/world_context.gd").find_world(actor)
  if world==null or not world.get_meta("uncached_street_surfaces",false):
   street_surface=preload("res://world/suryagarh/street_surface.gd").new()
   street_surface.point=actor.global_position
   street_surface.set_support(ground_at(Vector2(actor.global_position.x,actor.global_position.z)))
   actor.ground_height=street_surface.height

 # Stable phase spreads remote work across frames instead of synchronising it.
 tier_age = float(actor.get_instance_id()%13)*.02
 accumulated = float(actor.get_instance_id()%7)*.01

func tick(delta:float) -> void:
 if wait > 0 and is_instance_valid(port_hiring_owner) and port_hiring_owner.port_shift_active(port_worker_key):
  actor.travel_speed=0.0
  update_animation(&"idle",delta)
  actor.set_meta("daily_activity",&"port_freight_shift")
  return
 var old_goal:=goal
 var old_detour:=detour
 var target:=route_target(route[goal])
 var was_waiting:=wait>0
 super.tick(delta)
 if not livelihood_role.is_empty():
  var activity:=Livelihood.activity(livelihood_role,direction,wait,closing)
  if actor.get_meta("daily_activity", &"") != activity:
   actor.set_meta("daily_activity",activity)
 if paused or was_waiting or wait>0 or actor.get_meta("dead",false):return
 if goal!=old_goal or detour!=old_detour or (closing and goal==0):return
 var here:=Vector2(actor.global_position.x,actor.global_position.z)
 if here.distance_to(Vector2(target.x,target.z))>=.035:return
 # Reached the waypoint on its actual supporting surface. A cached endpoint
 # height can differ from a raised floor and must not trap a zero-length step.
 var support:=ground_at(here)
 if not support.is_empty() and support.normal.y>=.6 and absf(support.position.y-actor.global_position.y)<.035:arrive()

func ground_at(point:Vector2) -> Dictionary:
 var height:float=layout.height(point.x,point.y)
 var ray:=PhysicsRayQueryParameters3D.create(Vector3(point.x,height+8,point.y),Vector3(point.x,height-8,point.y),Ground.TERRAIN_SUPPORT_LAYER)
 return actor.get_world_3d().direct_space_state.intersect_ray(ray)

func route_target(point:Vector2) -> Vector3:
 if detour.is_finite():point=detour
 if not waypoint_heights.has(point):
  var support:=ground_at(point)
  waypoint_heights[point]=support.position.y if not support.is_empty() else layout.height(point.x,point.y)
 return Vector3(point.x,waypoint_heights[point],point.y)

func motion_exclusions() -> Array[RID]:
 # Terrain support is tested by the dedicated ray; sweep all solid obstacles.
 if terrain_revision!=int(terrain_cache.revision):
  sweep_exclusions=super.motion_exclusions()+terrain_rids
  terrain_revision=terrain_cache.revision
 return sweep_exclusions

func travel_motion(target:Vector3,delta:float) -> Vector3:
 var here:=Vector2(actor.global_position.x,actor.global_position.z)
 var offset:=Vector2(target.x,target.z)-here
 var next:=here+offset.normalized()*minf(offset.length(),current_speed*delta)
 var support:=ground_at(next)
 if support.is_empty() or support.normal.y<.6 or absf(support.position.y-actor.global_position.y)>.35:
  last_obstacle="unsafe terrain support"
  # A rejected support step must trigger navigation recovery as a solid
  # obstacle does; zero motion alone would otherwise be treated as success.
  on_blocked(target,delta)
  return Vector3.ZERO
 if street_surface!=null:street_surface.set_support(support)
 return Vector3(next.x,support.position.y,next.y)-actor.global_position

func on_blocked(target:Vector3,delta:float) -> void:
 retry_age+=delta
 if retry_age<.5:return
 var elapsed_recovery:=retry_age
 retry_age=0
 var recovered:float=preload("res://world/suryagarh/city_contact_recovery.gd").recover(actor,actor.body_collider)
 if recovered>0:
  distance_walked+=recovered;detour=Vector2.INF;detour_followup=Vector2.INF
  return
 if escape_cart_overlap(elapsed_recovery):return
 var here:=Vector2(actor.global_position.x,actor.global_position.z)
 var forward:Vector2=(route[goal]-here).normalized()
 var side:=Vector2(-forward.y,forward.x)
 var preference:=1.0 if int(actor.get_meta("street_identity",0))%2==0 else -1.0
 var fallback:=Vector2.INF
 for distance in [.65,1.1,2.0,3.0,.35]:
  for sign in [preference,-preference]:
   for advance in [1.2,.6,.3,0.0,-.3,-.6,-1.2,-2.4]:
    var point: Vector2=here+side*distance*sign+forward*advance
    if layout.road_distance(point.x,point.y)>4.5:continue
    var support:=ground_at(point)
    if support.is_empty() or support.normal.y<.6 or absf(support.position.y-actor.global_position.y)>.35:continue
    var query:=PhysicsShapeQueryParameters3D.new()
    var shape:CollisionShape3D=actor.get_node("BodyCollider/BodyShape")
    query.shape=shape.shape;query.transform=shape.global_transform;query.transform.origin+=Vector3.UP*.025
    query.motion=Vector3(point.x,support.position.y,point.y)-actor.global_position
    query.margin=.008;query.collision_mask=1;query.exclude=motion_exclusions()
    if actor.get_world_3d().direct_space_state.cast_motion(query)[0]<.99:continue
    query.transform.origin+=query.motion;query.motion=Vector3.ZERO
    if not actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
    # Hold the passing lane until beyond a long cart, instead of immediately
    # steering back into its rear when the first lateral step finishes.
    detour_followup=Vector2.INF
    for length in [5.0,3.0,1.5]:
     var onward:Vector2=point+forward*length
     var onward_support:=ground_at(onward)
     if layout.road_distance(onward.x,onward.y)>4.5 or onward_support.is_empty() or onward_support.normal.y<.6 or absf(onward_support.position.y-support.position.y)>.35:continue
     var onward_query:=PhysicsShapeQueryParameters3D.new()
     onward_query.shape=query.shape;onward_query.transform=query.transform;onward_query.margin=query.margin
     onward_query.collision_mask=query.collision_mask;onward_query.exclude=query.exclude
     onward_query.motion=Vector3(onward.x,onward_support.position.y,onward.y)-query.transform.origin+Vector3.UP*(shape.global_position.y-actor.global_position.y+.025)
     if actor.get_world_3d().direct_space_state.cast_motion(onward_query)[0]<.99:continue
     onward_query.transform.origin+=onward_query.motion;onward_query.motion=Vector3.ZERO
     if not actor.get_world_3d().direct_space_state.intersect_shape(onward_query,1).is_empty():continue
     detour_followup=onward;break
    if not detour_followup.is_finite():
     # A clear lateral toe-step alone can steer straight back into the blocker.
     # Prefer a complete passing lane; retain a substantial escape only as fallback.
     if not fallback.is_finite() or point.distance_squared_to(here)>fallback.distance_squared_to(here):fallback=point
     continue
    detour=point;detours+=1;return
 if fallback.is_finite():detour=fallback;detour_followup=Vector2.INF;detours+=1

func escape_cart_overlap(delta:float) -> bool:
 if not is_instance_valid(traffic_encounters):
  var world:=preload("res://systems/world_context.gd").find_world(actor)
  if world!=null:traffic_encounters=world.get_node_or_null("CombatEncounters")
 if not is_instance_valid(traffic_encounters):return false
 var shape:CollisionShape3D=actor.body_collider.get_node("BodyShape")
 var query:=PhysicsShapeQueryParameters3D.new()
 query.shape=shape.shape;query.transform=shape.global_transform;query.transform.origin+=Vector3.UP*.025
 query.margin=.002;query.collision_mask=1;query.exclude=[actor.body_collider.get_rid()]
 for hit in actor.get_world_3d().direct_space_state.intersect_shape(query,16):
  var body:Node=hit.collider
  if not body.is_in_group("cart_clearance_bodies") or not body.get_parent() is Node3D:continue
  var cart:Node3D=body.get_parent()
  var local:=cart.to_local(actor.global_position)
  var side:float=-1.0 if local.x<0 else 1.0
  var target:=actor.global_position+cart.global_basis.x*side*4.0
  var previous:=actor.global_position
  var remaining:=delta
  while remaining>.0001:
   var step:=minf(remaining,.0625)
   if not traffic_encounters.separate_patrol_from_cart(actor,cart,target,step):break
   remaining-=step
  var moved:=previous.distance_to(actor.global_position)
  if moved>.0001:
   distance_walked+=moved;detour=Vector2.INF;detour_followup=Vector2.INF;last_obstacle=""
   return true
 return false

func arrive() -> void:
 if detour.is_finite():
  detour=detour_followup;detour_followup=Vector2.INF;return
 var destination_reached := goal == route.size() - 1
 super.arrive()
 if destination_reached and not livelihood_role.is_empty():
  wait = Livelihood.dwell(livelihood_role,true)
  if is_instance_valid(port_hiring_owner):port_hiring_owner.offer_port_shift(port_worker_key)
func _physics_process(delta: float) -> void:
 if (actor.get_meta("dead",false) or actor.get_meta("knocked_out",false)) and is_instance_valid(port_hiring_owner):
  port_hiring_owner.port_shift_active(port_worker_key)
 if actor.get_meta("civilian_reacting",false) or actor.get_meta("defending",false):return
 if actor.get_meta("player_street_chat",false) and is_instance_valid(viewer):
  current_speed=0;actor.travel_speed=0
  var toward:Vector3=viewer.global_position-actor.global_position
  if Vector2(toward.x,toward.z).length_squared()>.01:
   actor.global_rotation.y=rotate_toward(actor.global_rotation.y,atan2(toward.x,toward.z),delta*2.5)
  social_time+=delta;simulation_interval=0.0
  update_animation(&"idle",delta)
  actor.set_meta("street_action","talking" if actor.get_meta("speaking",false) else "listening")
  apply_conversation_gesture()
  return
 accumulated+=delta
 tier_age-=delta
 if tier_age<=0:
  tier_age=.25
  simulation_interval=Budget.interval(actor,viewer,actor.get_meta("combat_action","")!="" or actor.get_meta("mission_active",false))
  var camera:Camera3D=actor.get_viewport().get_camera_3d()
  var near:bool=camera==null or camera.global_position.distance_squared_to(actor.global_position)<Budget.NEAR_SQUARED
  if near!=shadows_near:
   shadows_near=near
   for index in shadow_meshes.size():
    if is_instance_valid(shadow_meshes[index]):shadow_meshes[index].cast_shadow=shadow_modes[index] if near else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 # Approaching/teleporting players restore full collision/animation immediately.
 if simulation_interval>0 and is_instance_valid(viewer) and actor.global_position.distance_squared_to(viewer.global_position)<=Budget.NEAR_SQUARED:
  simulation_interval=0
 if accumulated<simulation_interval:return
 var step:=accumulated;accumulated=0
 if actor.get_meta("knocked_out",false) or actor.get_meta("grappled",false) or actor.get_meta("dead",false) or actor.get_meta("combat_action","")!="":
  if is_instance_valid(crowd):crowd.end_conversation(self)
  return
 if is_instance_valid(social_partner) and is_instance_valid(crowd):
  if crowd.age>=social_end or not crowd.available(social_partner) or closing:
   crowd.end_conversation(self)
  else:
   converse(step);return
 awareness_age-=step
 if awareness_age<=0 and is_instance_valid(crowd):
  awareness_age=.15
  var next:=route_target(route[goal])
  var forward:=Vector2(next.x-actor.global_position.x,next.z-actor.global_position.z).normalized()
  pace_scale=crowd.road_pace(self,forward)
 # A checked escape from the yielding lane must be allowed to execute.
 # tick still sweeps the capsule, so this never ignores the cart or a person.
 if detour.is_finite():pace_scale=1.0
 if pace_scale<.1:
  yield_age+=step;current_speed=0;actor.travel_speed=0
  update_animation(&"idle",step);actor.set_meta("street_action","yielding_to_traffic")
  if yield_age>1.2:on_blocked(route_target(route[goal]),step)
  return
 yield_age=0
 # Retain elapsed remote time while bounding support/obstacle sweeps and turns.
 var remaining:=step
 while remaining>.0001:
  var portion:=minf(remaining,.1)
  tick(portion);remaining-=portion

func update_animation(state: StringName, delta: float) -> void:
 if simulation_interval>=.5:
  actor.foot_plant.clear()
  return
 super.update_animation(state,delta)

func clear_sight(other:Node3D) -> bool:
 var ray:=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*1.25,other.global_position+Vector3.UP*1.25,1)
 ray.exclude=[actor.body_collider.get_rid(),other.body_collider.get_rid()]
 return actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func converse(delta:float) -> void:
 if actor.get_meta("civilian_reacting",false) or actor.get_meta("defending",false):return
 social_time+=delta
 current_speed=0;actor.travel_speed=0;update_animation(&"idle",delta)
 var offset:Vector3=social_partner.actor.global_position-actor.global_position
 actor.global_rotation.y=rotate_toward(actor.global_rotation.y,atan2(offset.x,offset.z),delta*2.2)
 actor.body_collider.force_update_transform()
 var speaking:bool=(int((crowd.age-(social_end-10.0))/2.7)%2==0)==social_speaker
 if is_instance_valid(player_dialogue):
  var audible_turn:int=player_dialogue.peer_speaking_status(self)
  if audible_turn>=0:speaking=audible_turn==1
 actor.set_meta("street_action","talking" if speaking else "listening")
 if speaking and not social_voice_sent and actor.get_meta("social_tone","")!="argument" and is_instance_valid(viewer) and actor.global_position.distance_squared_to(viewer.global_position)<196.0:
  var status:int=player_dialogue.try_peer_speech(self) if is_instance_valid(player_dialogue) else -1
  if status>0:social_voice_sent=true
  elif status<0:social_voice_sent=WorldAudio.play_social_voice(actor,viewer,personal_seed)
 apply_conversation_gesture()

func apply_conversation_gesture() -> void:
 var speaking:bool=actor.get_meta("street_action","")=="talking"
 # Idle is sampled first, so gesture deltas cannot accumulate into the next walk.
 if simulation_interval>0.1 or actor._skeleton==null:return
 var arguing:bool=actor.get_meta("social_tone","")=="argument"
 var gesture:float=sin(social_time*(3.1 if arguing else 2.1)+float(personal_seed))*(.06 if arguing else .035)
 actor.solve_hand_contact("r",actor.to_global(Vector3(-.20,(1.12 if arguing else 1.02)+gesture,.34 if arguing else .29)) if speaking else actor.to_global(Vector3(-.30,.81,.07)))
 actor.set_grip("r",.12 if speaking else 0.0)
 var warmth:float=actor.get_meta("social_warmth",0.0)
 actor.solve_hand_contact("l",actor.to_global(Vector3(.24,.93+gesture*.6,.19)) if speaking else actor.to_global(Vector3(.30,.81,.07)))
 actor.set_grip("l",.08 if speaking else 0.0)
 var head:int=actor._bones.get("head",-1)
 if head>=0:
  actor._skeleton.set_bone_pose_rotation(head,actor._base_rotations["head"]*Quaternion(actor._pitch_axes["head"],.025*sin(social_time*2.4) if not speaking else .015*sin(social_time*4.1))*Quaternion(actor._yaw_axes["head"],warmth*.08*sin(social_time*.9)))

func _exit_tree() -> void:
 if is_instance_valid(crowd):crowd.unregister(self)
