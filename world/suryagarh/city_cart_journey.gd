extends "res://vehicles/bullock_road_journey.gd"
## Existing clearance/grounding/boarding behavior with traffic spacing and progress.
const Budget = preload("res://systems/simulation_budget.gd")
var viewer: Node3D
var traffic: Array[Node3D] = []
var accumulated := 0.0
var traffic_age := 0.0
var distance_travelled := 0.0
var blocked_reason := ""
var road_lane := 0.0
var preferred_lane := 0.0
var contact_age := 0.0
var passing_target := Vector2.INF
var stalled_age := 0.0
var passing_retry := 0.0
var retreat_remaining := 0.0

func _ready() -> void:
 var ground=preload("res://world/suryagarh/tree_trunk_collision.gd")
 ground.configure_terrain_support(cart)
 # Pedestrians beside the axle are obstacles, never the road height.
 ground_collision_mask=ground.TERRAIN_SUPPORT_LAYER
 var original:Vector3=cart.global_position
 var along:Vector2=(route[1]-route[0]).normalized()
 var side:=Vector2(-along.y,along.x)
 # Placement only: an authored road centre may coincide with a boundary wall.
 # Find a clear parallel lane before this vehicle starts moving.
 for lane in [preferred_lane,0.0,-2.5,2.5,-3.5,3.5]:
  var offset:Vector2=side*lane
  var at:=Vector2(original.x,original.z)+offset
  var height:float=preload("res://world/suryagarh/landscape_layout.gd").new().height(at.x,at.y)
  var query:=PhysicsRayQueryParameters3D.create(Vector3(at.x,height+3,at.y),Vector3(at.x,height-3,at.y),ground.TERRAIN_SUPPORT_LAYER)
  var hit:=cart.get_world_3d().direct_space_state.intersect_ray(query)
  if hit.is_empty():continue
  var candidate:Vector3=Vector3(at.x,hit.position.y,at.y)
  if not cart.boarding._clearance_at(candidate):continue
  cart.global_position=candidate
  route=[route[0]+offset,route[1]+offset];road_lane=lane
  cart.boarding.collision_body.force_update_transform()
  return
func _physics_process(delta: float) -> void:
 if cart==null:return
 if cart.boarding.rider!=null or cart.has_meta("errand_cargo") or cart.has_meta("errand_transfer") or not cart.can_move():
  accumulated=0;return
 accumulated+=delta
 var cadence:=Budget.interval(cart,viewer,cart.boarding.rider!=null or cart.has_meta("errand_cargo") or cart.has_meta("errand_transfer"))
 # Large vehicle bounds/turns use a conservative maximum 100 ms step.
 if accumulated<minf(cadence,.1):return
 delta=accumulated;accumulated=0
 passing_retry=maxf(0,passing_retry-delta)
 if retreat_remaining>0:
  retreat(delta)
  return
 traffic_age-=delta
 if traffic_age<=0:
  traffic_age=.5
  traffic.assign(get_tree().get_nodes_in_group("city_route_carts"))
 # Real cart bounds still govern movement; this look-ahead prevents rear shunts.
 for other:Node3D in traffic:
  if not is_instance_valid(other) or other==cart:continue
  var offset:=cart.to_local(other.global_position)
  if not passing_target.is_finite() and absf(offset.x)<2.3 and offset.z<0 and offset.z> -9:
   blocked_reason="traffic spacing: "+str(other.name)
   stalled_age+=delta
   if stalled_age>2 and passing_retry<=0:plan_pass()
   cart.boarding.speed=0;cart.set_forward_motion(0,delta);return
 var before:=cart.global_position
 contact_age+=delta
 if contact_age>=.5 and cart.boarding.speed<=.001 and wait<=0 and cart.boarding.rider==null and not cart.has_meta("errand_cargo") and not cart.has_meta("errand_transfer"):
  contact_age=0.0
  preload("res://world/suryagarh/city_contact_recovery.gd").recover(cart,cart.boarding.collision_body,cart.boarding._vehicle_exclusions())
 align_road_grade()
 var road_target:Vector2=route[direction]
 var road_direction:=direction
 if passing_target.is_finite():route[direction]=passing_target
 super._physics_process(delta)
 route[road_direction]=road_target
 if passing_target.is_finite() and direction!=road_direction:
  direction=road_direction;wait=0;passing_target=Vector2.INF
 distance_travelled+=before.distance_to(cart.global_position)
 if before.distance_squared_to(cart.global_position)>.0000001:
  blocked_reason="";stalled_age=0
 elif wait<=0:
  blocked_reason=clearance_reason()
  stalled_age+=delta
  if stalled_age>2 and passing_retry<=0:plan_pass()

func plan_pass() -> void:
 passing_retry=3.0
 var here:=Vector2(cart.global_position.x,cart.global_position.z)
 var forward:Vector2=(route[direction]-here).normalized()
 var side:=Vector2(-forward.y,forward.x)
 var terrain:=preload("res://world/suryagarh/tree_trunk_collision.gd").terrain_cache(cart)
 var space:=cart.get_world_3d().direct_space_state
 var original_yaw:=cart.rotation.y
 var layout:=preload("res://world/suryagarh/landscape_layout.gd").new()
 for along in [7.0,4.0]:
  for lateral in [1.4,-1.4,2.2,-2.2]:
   var point:Vector2=here+forward*along+side*lateral
   if layout.road_distance(point.x,point.y)>4.5:continue
   var ray:=PhysicsRayQueryParameters3D.create(Vector3(point.x,cart.global_position.y+3,point.y),Vector3(point.x,cart.global_position.y-3,point.y),ground_collision_mask)
   var support:=space.intersect_ray(ray)
   if support.is_empty() or support.normal.y<.6 or absf(support.position.y-cart.global_position.y)>.35:continue
   var destination:=Vector3(point.x,support.position.y,point.y)
   var heading:=atan2(-point.x+here.x,-point.y+here.y)
   var clear:=true
   # Validate the complete pivot, then every body shape along the passing leg.
   for step in range(1,9):
    cart.rotation.y=lerp_angle(original_yaw,heading,float(step)/8.0)
    if not cart.boarding._clearance_at(cart.global_position):clear=false;break
   if clear:
    for shape:CollisionShape3D in cart.boarding.clearance_shapes:
     var query:=PhysicsShapeQueryParameters3D.new()
     query.shape=shape.shape;query.transform=Transform3D(cart.global_basis,cart.global_position+cart.global_basis*shape.position)
     query.motion=destination-cart.global_position;query.margin=.008;query.collision_mask=1
     query.exclude=terrain.rids+cart.boarding._vehicle_exclusions()
     if space.cast_motion(query)[0]<.99:clear=false;break
    if clear and not cart.boarding._clearance_at(destination):clear=false
   cart.rotation.y=original_yaw
   if clear:passing_target=point;stalled_age=0;return
 # A cart pinned beside a person or boundary cannot safely pivot. Back away
 # using the same supported body clearance before attempting another pass.
 passing_target=Vector2.INF
 retreat_remaining=2.5

func retreat(delta:float) -> void:
 var before:=cart.global_position
 var next:Vector3=before+cart.global_basis.z*minf(.65*delta,retreat_remaining)
 var space:=cart.get_world_3d().direct_space_state
 var ray:=PhysicsRayQueryParameters3D.create(next+Vector3.UP*2,next-Vector3.UP*3,ground_collision_mask,cart.boarding._vehicle_exclusions())
 var support:=space.intersect_ray(ray)
 var clear:=not support.is_empty()
 if clear:
  next.y=support.position.y
  clear=support.normal.y>=.6 and absf(next.y-before.y)<.35 and cart.boarding._clearance_at(next)
 if clear:
  var terrain:=preload("res://world/suryagarh/tree_trunk_collision.gd").terrain_cache(cart)
  for shape:CollisionShape3D in cart.boarding.clearance_shapes:
   var query:=PhysicsShapeQueryParameters3D.new()
   query.shape=shape.shape;query.transform=Transform3D(cart.global_basis,before+cart.global_basis*shape.position)
   query.motion=next-before;query.margin=.008;query.collision_mask=1
   query.exclude=terrain.rids+cart.boarding._vehicle_exclusions()
   if space.cast_motion(query)[0]<.99:clear=false;break
 if clear:
  cart.global_position=next
  var travelled:=before.distance_to(next)
  distance_travelled+=travelled;retreat_remaining=maxf(0,retreat_remaining-travelled)
  cart.boarding.collision_body.force_update_transform()
  cart.boarding.speed=-.65;cart.set_forward_motion(-.65,delta)
 else:
  retreat_remaining=0;cart.boarding.speed=0;cart.set_forward_motion(0,delta)
 if retreat_remaining<=0:stalled_age=0;passing_retry=0


func align_road_grade() -> void:
 var space:=cart.get_world_3d().direct_space_state
 var heights:Array[float]=[]
 for along in [-2.0,3.0]:
  var at:Vector3=cart.global_position+cart.global_basis.z*along
  var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*3,at-Vector3.UP*4,ground_collision_mask,cart.boarding._vehicle_exclusions())
  var hit:=space.intersect_ray(ray)
  if hit.is_empty():return
  heights.append(hit.position.y)
 var pitch:=clampf(atan2(heights[0]-heights[1],5.0),-.3,.3)
 var old_pitch:=cart.rotation.x
 cart.rotation.x=pitch
 if not cart.boarding._clearance_at(cart.global_position):cart.rotation.x=old_pitch

func clearance_reason() -> String:
 var next:=cart.global_position-cart.global_basis.z*.12
 for collision:CollisionShape3D in cart.boarding.clearance_shapes:
  var query:=PhysicsShapeQueryParameters3D.new()
  query.shape=collision.shape
  query.transform=Transform3D(cart.global_basis,next+cart.global_basis*collision.position)
  query.exclude=cart.boarding._vehicle_exclusions();query.collision_mask=1
  var hits:=cart.get_world_3d().direct_space_state.intersect_shape(query,1)
  if not hits.is_empty():return str(hits[0].collider.get_path())
 var ray:=PhysicsRayQueryParameters3D.create(next+Vector3.UP*2,next-Vector3.UP*3,ground_collision_mask,cart.boarding._vehicle_exclusions())
 var support:=cart.get_world_3d().direct_space_state.intersect_ray(ray)
 var offset:Vector2=route[direction]-Vector2(cart.global_position.x,cart.global_position.z)
 return "support="+str(support.get("position","missing"))+" heading_error="+str(angle_difference(cart.rotation.y,atan2(-offset.x,-offset.y)))
