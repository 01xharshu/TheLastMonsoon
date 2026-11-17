extends RefCounted
## World-scoped setup survey of authoritative terrain collision; no retained world node.
const Terrain=preload("res://world/suryagarh/tree_trunk_collision.gd")
var space:PhysicsDirectSpaceState3D
var heights:Dictionary={}
func configure(world:Node3D)->void:
 Terrain.configure_terrain_support(world)
 space=world.get_world_3d().direct_space_state
func height(x:float,z:float)->float:
 var key:=Vector2(snappedf(x,.001),snappedf(z,.001))
 if heights.has(key):return heights[key]
 var query:=PhysicsRayQueryParameters3D.create(Vector3(x,350,z),Vector3(x,-30,z),Terrain.TERRAIN_SUPPORT_LAYER)
 var hit:=space.intersect_ray(query)
 var result:float=hit.position.y if not hit.is_empty() else preload("res://world/suryagarh/landscape_layout.gd").new().height(x,z)
 heights[key]=result
 return result
