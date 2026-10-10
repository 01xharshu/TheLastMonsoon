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

func _ready() -> void:
 var ground=preload("res://world/suryagarh/tree_trunk_collision.gd")
 ground.configure_terrain_support(cart)
 var original:Vector3=cart.global_position
 var along:Vector2=(route[1]-route[0]).normalized()
 var side:=Vector2(-along.y,along.x)
 # Placement only: an authored road centre may coincide with a boundary wall.
 # Find a clear parallel lane before this vehicle starts moving.
 for lane in [0.0,-2.5,2.5,-3.5,3.5]:
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
 accumulated+=delta
 var cadence:=Budget.interval(cart,viewer,cart.boarding.rider!=null or cart.has_meta("errand_cargo") or cart.has_meta("errand_transfer"))
 # Large vehicle bounds/turns use a conservative maximum 100 ms step.
 if accumulated<minf(cadence,.1):return
 delta=accumulated;accumulated=0
 traffic_age-=delta
 if traffic_age<=0:
  traffic_age=.5
  traffic.assign(get_tree().get_nodes_in_group("city_route_carts"))
 # Real cart bounds still govern movement; this look-ahead prevents rear shunts.
 for other:Node3D in traffic:
  if not is_instance_valid(other) or other==cart:continue
  var offset:=cart.to_local(other.global_position)
  if absf(offset.x)<2.3 and offset.z<0 and offset.z> -9:
   blocked_reason="traffic spacing: "+str(other.name)
   cart.boarding.speed=0;cart.set_forward_motion(0,delta);return
 var before:=cart.global_position
 super._physics_process(delta)
 distance_travelled+=before.distance_to(cart.global_position)
 if before.distance_squared_to(cart.global_position)>.0000001:
  blocked_reason=""
 elif wait<=0:
  blocked_reason=clearance_reason()

func clearance_reason() -> String:
 for collision:CollisionShape3D in cart.boarding.clearance_shapes:
  var query:=PhysicsShapeQueryParameters3D.new()
  query.shape=collision.shape
  query.transform=Transform3D(cart.global_basis,cart.global_position+cart.global_basis*collision.position)
  query.exclude=cart.boarding._vehicle_exclusions();query.collision_mask=1
  var hits:=cart.get_world_3d().direct_space_state.intersect_shape(query,1)
  if not hits.is_empty():return str(hits[0].collider.get_path())
 return "ground/heading/driver state"
