extends "res://world/suryagarh/settlements/street_journey.gd"
## Keep remote residents persistent at reduced update cadence, never crowd the centre.
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
var shadow_meshes:Array[GeometryInstance3D]=[]
var shadow_modes:Array[int]=[]
var shadows_near:=true

func _ready() -> void:
 super._ready()
 turn_in_place=false
 personal_seed=int(actor.get_meta("population_index",0))+int(actor.get_meta("street_identity",0))*17
 social_enabled=personal_seed%4<2
 social_cooldown=5.0+float(personal_seed%19)
 if is_instance_valid(crowd):crowd.register(self)
 for mesh:GeometryInstance3D in actor.find_children("*","GeometryInstance3D",true,false):
  shadow_meshes.append(mesh);shadow_modes.append(mesh.cast_shadow)
 terrain_cache=Ground.terrain_cache(actor)
 terrain_rids=terrain_cache.rids
 sweep_exclusions = super.motion_exclusions()+terrain_rids
 terrain_revision=terrain_cache.revision
 # Stable phase spreads remote work across frames instead of synchronising it.
 tier_age = float(actor.get_instance_id()%13)*.02
 accumulated = float(actor.get_instance_id()%7)*.01

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
  last_obstacle="unsafe terrain support";return Vector3.ZERO
 return Vector3(next.x,support.position.y,next.y)-actor.global_position

func on_blocked(target:Vector3,delta:float) -> void:
 retry_age+=delta
 if retry_age<.5:return
 retry_age=0
 var here:=Vector2(actor.global_position.x,actor.global_position.z)
 var forward:Vector2=(Vector2(target.x,target.z)-here).normalized()
 var side:=Vector2(-forward.y,forward.x)
 var preference:=1.0 if int(actor.get_meta("street_identity",0))%2==0 else -1.0
 for distance in [1.1,2.0,3.0]:
  for sign in [preference,-preference]:
   for advance in [1.2,0.0]:
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
    detour=point;detours+=1;return

func arrive() -> void:
 if detour.is_finite():detour=Vector2.INF;return
 super.arrive()
func _physics_process(delta: float) -> void:
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
 # Invisible residents still traverse the same collision-checked route and clock.
 if simulation_interval>=.5:
  actor.foot_plant.clear()
  return
 super.update_animation(state,delta)

func clear_sight(other:Node3D) -> bool:
 var ray:=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*1.25,other.global_position+Vector3.UP*1.25,1)
 ray.exclude=[actor.body_collider.get_rid(),other.body_collider.get_rid()]
 return actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func converse(delta:float) -> void:
 social_time+=delta
 current_speed=0;actor.travel_speed=0;update_animation(&"idle",delta)
 var offset:Vector3=social_partner.actor.global_position-actor.global_position
 actor.global_rotation.y=rotate_toward(actor.global_rotation.y,atan2(offset.x,offset.z),delta*2.2)
 actor.body_collider.force_update_transform()
 var speaking:bool=(int((crowd.age-(social_end-10.0))/2.7)%2==0)==social_speaker
 actor.set_meta("street_action","talking" if speaking else "listening")
 # Idle is sampled first, so gesture deltas cannot accumulate into the next walk.
 if simulation_interval>0.1 or actor._skeleton==null:return
 var gesture:float=sin(social_time*2.1+float(personal_seed))*.035
 actor.solve_hand_contact("r",actor.to_global(Vector3(-.20,1.02+gesture,.29)) if speaking else actor.to_global(Vector3(-.30,.81,.07)))
 actor.set_grip("r",.12 if speaking else 0.0)
 var head:int=actor._bones.get("head",-1)
 if head>=0:
  actor._skeleton.set_bone_pose_rotation(head,actor._base_rotations["head"]*Quaternion(actor._pitch_axes["head"],.025*sin(social_time*2.4) if not speaking else .015*sin(social_time*4.1)))

func _exit_tree() -> void:
 if is_instance_valid(crowd):crowd.end_conversation(self)
