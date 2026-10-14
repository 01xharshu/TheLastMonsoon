extends RefCounted
## A long wilderness convoy route develops unused western/northern world space.
## The graded physical surface supports carts and horses; no population is spawned here.
const Data=preload("res://story/consignment_route_data.gd")
const WAYPOINTS=Data.WAYPOINTS
const GROUND_TIE_IN=0.0
static func planar_path(waypoints:Array,public_count:int) -> Dictionary:
 var path:Array[Vector2]=[waypoints[0]]
 var shared_end:=-1
 for i in range(1,waypoints.size()-1):
  var corner:Vector2=waypoints[i]
  if i<public_count or corner==Data.HOLDING_ANCHOR:
   path.append(corner)
   if i==public_count-1:shared_end=path.size()-1
   continue
  var radius:=3.0 if i<public_count+3 else 24.0
  var before:Vector2=corner.move_toward(waypoints[i-1],minf(radius,corner.distance_to(waypoints[i-1])*.25))
  var after:Vector2=corner.move_toward(waypoints[i+1],minf(radius,corner.distance_to(waypoints[i+1])*.25))
  for j in 9:
   var t:=float(j)/8;path.append(before*(1-t)*(1-t)+corner*2*(1-t)*t+after*t*t)
 path.append(waypoints[-1])
 return {"path":path,"shared_end":shared_end}
static func points(layout: RefCounted,space: PhysicsDirectSpaceState3D=null) -> PackedVector3Array:
 var result:=PackedVector3Array()
 var plan:=planar_path(WAYPOINTS,Data.PUBLIC_WAYPOINTS.size())
 var path:Array[Vector2]=plan.path
 var terrain_sample_end:=-1
 var private_distance:=0.0
 for i in path.size()-1:
  var a: Vector2=path[i];var b: Vector2=path[i+1];var count:=maxi(1,ceili(a.distance_to(b)/6))
  for j in count:
   var at:=a.lerp(b,float(j)/count)
   var height:=support_height(layout,space,at)+.16
   if i==int(plan.shared_end) and j==0:private_distance=0.0
   elif i>=int(plan.shared_end) and result.size()>0:
    private_distance+=Vector2(result[-1].x,result[-1].z).distance_to(at)
   var shared:bool=i<int(plan.shared_end) or private_distance<=GROUND_TIE_IN
   if not shared:
    var direction: Vector2=(b-a).normalized();var side:=Vector2(-direction.y,direction.x)*7
    height=maxf(height,maxf(support_height(layout,space,at+side),support_height(layout,space,at-side))+.16)
   result.append(Vector3(at.x,height,at.y))
   if shared:terrain_sample_end=result.size()-1
 var end: Vector2=WAYPOINTS[-1];result.append(Vector3(end.x,support_height(layout,space,end)+.16,end.y))
 # Grade only the new wilderness surface. The public prefix uses real ground
 # and the existing bridge; raising it would produce a second floating road.
 for i in range(terrain_sample_end+1,result.size()):
  var point:=result[i];point.y=maxf(point.y,result[i-1].y-Vector2(point.x-result[i-1].x,point.z-result[i-1].z).length()*.1);result[i]=point
 for i in range(result.size()-2,terrain_sample_end,-1):
  var point:=result[i];point.y=maxf(point.y,result[i+1].y-Vector2(point.x-result[i+1].x,point.z-result[i+1].z).length()*.1);result[i]=point
 # Both visits to the circuit anchor share one exact physical height.
 var anchors:Array[int]=[]
 for i in result.size():
  if Vector2(result[i].x,result[i].z).distance_squared_to(Data.HOLDING_ANCHOR)<.0001:anchors.append(i)
 assert(anchors.size()==2)
 for junction in [Data.HOLDING_ANCHOR,Vector2(790,-310)]:
  var junction_height:float=0.0
  for at in result:
   if Vector2(at.x,at.z).distance_to(junction)<60:junction_height=maxf(junction_height,at.y)
  for i in result.size():
   var at:Vector3=result[i];var distance:float=Vector2(at.x,at.z).distance_to(junction)
   if distance<60:at.y=lerpf(at.y,junction_height,1.0-smoothstep(35,60,distance));result[i]=at
 for iteration in 8:
  var height:float=maxf(result[anchors[0]].y,result[anchors[1]].y)
  for index in anchors:var at:Vector3=result[index];at.y=height;result[index]=at
  for i in range(terrain_sample_end+1,result.size()):
   var at:Vector3=result[i];at.y=maxf(at.y,result[i-1].y-Vector2(at.x-result[i-1].x,at.z-result[i-1].z).length()*.1);result[i]=at
  for i in range(result.size()-2,terrain_sample_end,-1):
   var at:Vector3=result[i];at.y=maxf(at.y,result[i+1].y-Vector2(at.x-result[i+1].x,at.z-result[i+1].z).length()*.1);result[i]=at
 return result
static func shared_end_index(route:PackedVector3Array) -> int:
 var end:Vector2=Data.PUBLIC_WAYPOINTS[-1]
 for i in route.size():
  if Vector2(route[i].x,route[i].z).distance_squared_to(end)<.0001:return i
 return -1
static func surface_start_index(route:PackedVector3Array) -> int:
 var end:=shared_end_index(route);var distance:=0.0
 for i in range(end+1,route.size()):
  distance+=Vector2(route[i].x-route[i-1].x,route[i].z-route[i-1].z).length()
  if distance>GROUND_TIE_IN:return i-1
 return end
static func legacy_samples() -> PackedVector2Array:
 var plan:=planar_path(Data.LEGACY_WAYPOINTS,0)
 var path:Array[Vector2]=plan.path
 var result:=PackedVector2Array()
 for i in path.size()-1:
  var count:=maxi(1,ceili(path[i].distance_to(path[i+1])/6))
  for j in count:result.append(path[i].lerp(path[i+1],float(j)/count))
 result.append(path[-1]);return result
static func nearest_anchor(route:PackedVector3Array,anchor:Vector2) -> int:
 var nearest:=0;var distance:=INF
 for i in route.size():
  var candidate:=Vector2(route[i].x,route[i].z).distance_squared_to(anchor)
  if candidate<distance:distance=candidate;nearest=i
 return nearest
static func support_height(layout: RefCounted,space: PhysicsDirectSpaceState3D,at: Vector2) -> float:
 var height: float=layout.height(at.x,at.y)
 if space==null:return height
 var query=PhysicsRayQueryParameters3D.create(Vector3(at.x,height+200,at.y),Vector3(at.x,height-200,at.y),preload("res://world/suryagarh/tree_trunk_collision.gd").TERRAIN_SUPPORT_LAYER)
 var hit:=space.intersect_ray(query)
 return maxf(height,hit.position.y) if not hit.is_empty() else height
static func build(parent: Node3D, route: PackedVector3Array) -> Array[CollisionObject3D]:
 var supports: Array[CollisionObject3D]=[]
 var shared_end:=surface_start_index(route)
 assert(shared_end>=0,"canonical public road endpoint missing")
 var material:=StandardMaterial3D.new();material.albedo_color=Color(.34,.26,.18);material.roughness=1;material.cull_mode=BaseMaterial3D.CULL_DISABLED
 for first in range(0,route.size()-1,32):
  var origin:=route[first]
  var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  var faces:=PackedVector3Array()
  for i in range(first,mini(first+32,route.size()-1)):
   if i<shared_end:continue
   var a:=route[i];var b:=route[i+1];var along: Vector3=(b-a).normalized();var side: Vector3=along.cross(Vector3.UP).normalized()*7
   if i==0:a-=along*4
   if i==route.size()-2:b+=along*4
   for point in [a-side,b+side,b-side,a-side,a+side,b+side]:
    faces.append(point-origin);surface.add_vertex(point-origin)
  if faces.is_empty():continue
  surface.generate_normals();var mesh:=surface.commit()
  var visual:=MeshInstance3D.new();visual.name="ConsignmentMountainRoad%d"%first;visual.mesh=mesh;visual.material_override=material;visual.position=origin;visual.visibility_range_end=360;visual.visibility_range_end_margin=30;parent.add_child(visual)
  var body:=StaticBody3D.new();body.name="ConsignmentRoadCollision%d"%first;body.position=origin;parent.add_child(body)
  var collision:=CollisionShape3D.new();var road_shape:=ConcavePolygonShape3D.new();road_shape.set_faces(faces);road_shape.backface_collision=true;collision.shape=road_shape;body.add_child(collision)
  preload("res://world/suryagarh/tree_trunk_collision.gd").register_terrain_support(parent,body);supports.append(body)
 var builder=preload("res://world/suryagarh/settlements/settlement_builder.gd").new();builder.stone=builder.material(Color(.31,.29,.25))
 for i in range(shared_end,route.size(),6):
  var at:=route[i];var ground: float=parent.get_parent().layout.height(at.x,at.z);var depth:=at.y-ground
  if depth>1:
   var pier:=builder.piece(parent,"ValleyCausewayPier",Vector3(at.x,ground+maxf(.1,depth-1.5)*.5,at.z),Vector3(8,maxf(.1,depth-1.5),2),builder.stone)
   for mesh in pier.find_children("*","GeometryInstance3D",true,false):mesh.visibility_range_end=240;mesh.visibility_range_end_margin=20
 builder.free()
 return supports
