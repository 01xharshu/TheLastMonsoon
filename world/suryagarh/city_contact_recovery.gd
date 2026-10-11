extends RefCounted
## Resolve an existing overlap through the physics server, then recheck the pose.
const Ground=preload("res://world/suryagarh/tree_trunk_collision.gd")

static func recover(actor:Node3D,body:PhysicsBody3D,extra:Array=[]) -> float:
 var terrain:=Ground.terrain_cache(actor)
 var space:=actor.get_world_3d().direct_space_state
 var exclusions:Array[RID]=[]
 exclusions.assign(terrain.rids);exclusions.append_array(extra);exclusions.append(body.get_rid())
 var occupied:=false
 for shape:CollisionShape3D in body.get_children():
  if shape.disabled:continue
  var query:=PhysicsShapeQueryParameters3D.new()
  query.shape=shape.shape;query.transform=shape.global_transform
  query.margin=.008;query.collision_mask=1;query.exclude=exclusions
  if not space.intersect_shape(query,1).is_empty():occupied=true;break
 if not occupied:return 0.0
 var parameters:=PhysicsTestMotionParameters3D.new()
 parameters.from=body.global_transform;parameters.motion=Vector3.ZERO
 parameters.margin=.015;parameters.recovery_as_collision=true
 parameters.exclude_bodies=terrain.rids+extra
 var result:=PhysicsTestMotionResult3D.new()
 if not PhysicsServer3D.body_test_motion(body.get_rid(),parameters,result):return 0.0
 var motion:=result.get_travel()
 if motion.length_squared()<.000001 or motion.length()>.75:return 0.0
 var target:=actor.global_position+motion
 var ray:=PhysicsRayQueryParameters3D.create(target+Vector3.UP*.5,target-Vector3.UP*.5,Ground.TERRAIN_SUPPORT_LAYER)
 var support:=space.intersect_ray(ray)
 if support.is_empty() or support.normal.y<.6 or absf(support.position.y-actor.global_position.y)>.35:return 0.0
 target.y=support.position.y;motion=target-actor.global_position
 for shape:CollisionShape3D in body.get_children():
  if shape.disabled:continue
  var query:=PhysicsShapeQueryParameters3D.new()
  query.shape=shape.shape;query.transform=shape.global_transform
  query.transform.origin+=motion;query.margin=.008;query.collision_mask=1
  query.exclude=exclusions
  if not space.intersect_shape(query,1).is_empty():return 0.0
 actor.global_position=target;body.force_update_transform()
 return motion.length()
