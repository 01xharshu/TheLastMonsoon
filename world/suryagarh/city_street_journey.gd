extends "res://world/suryagarh/settlements/street_journey.gd"
## Keep remote residents persistent at reduced update cadence, never crowd the centre.
var viewer: Node3D
var accumulated := 0.0
const Ground = preload("res://world/suryagarh/tree_trunk_collision.gd")
var terrain_rids: Array[RID] = []
var waypoint_heights: Dictionary = {}
var detour := Vector2.INF
var retry_age := 0.0
var detours := 0

func _ready() -> void:
 super._ready()
 Ground.configure_terrain_support(actor)
 var world:Node=actor
 while world.get_parent()!=get_tree().root:world=world.get_parent()
 for body:CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
  if body.name=="GroundCollision":terrain_rids.append(body.get_rid())

func ground_at(point:Vector2) -> Dictionary:
 var height:float=layout.height(point.x,point.y)
 var ray:=PhysicsRayQueryParameters3D.create(Vector3(point.x,height+3,point.y),Vector3(point.x,height-3,point.y),Ground.TERRAIN_SUPPORT_LAYER)
 return actor.get_world_3d().direct_space_state.intersect_ray(ray)

func route_target(point:Vector2) -> Vector3:
 if detour.is_finite():point=detour
 if not waypoint_heights.has(point):
  var support:=ground_at(point)
  waypoint_heights[point]=support.position.y if not support.is_empty() else layout.height(point.x,point.y)
 return Vector3(point.x,waypoint_heights[point],point.y)

func motion_exclusions() -> Array[RID]:
 # Terrain support is tested by the dedicated ray; sweep all solid obstacles.
 return super.motion_exclusions()+terrain_rids

func travel_motion(target:Vector3,delta:float) -> Vector3:
 var here:=Vector2(actor.global_position.x,actor.global_position.z)
 var offset:=Vector2(target.x,target.z)-here
 var next:=here+offset.normalized()*minf(offset.length(),speed*delta)
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
 var far:=is_instance_valid(viewer) and actor.global_position.distance_squared_to(viewer.global_position)>40000
 if far and accumulated<.5:return
 var step:=accumulated;accumulated=0
 if actor.get_meta("knocked_out",false) or actor.get_meta("grappled",false):return
 tick(step)
