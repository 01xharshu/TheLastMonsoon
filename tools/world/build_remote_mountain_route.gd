extends SceneTree
const Layout=preload("res://world/suryagarh/landscape_layout.gd")
func _initialize()->void:call_deferred("build")
func build()->void:
 var layout:=Layout.new()
 var graph:=AStar2D.new()
 var nx:=72;var nz:=121;var origin:=Vector2(400,-1030);var step:=10.0
 for z in nz:
  for x in nx:
   var p:=origin+Vector2(x,z)*step
   graph.add_point(z*nx+x,p)
 for z in nz:
  for x in nx:
   var id:=z*nx+x;var a:=graph.get_point_position(id);var ah:=layout.height(a.x,a.y)
   for d in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(-1,1)]:
    var bcell: Vector2i=Vector2i(x,z)+d
    if bcell.x<0 or bcell.x>=nx or bcell.y>=nz:continue
    var other: int=bcell.y*nx+bcell.x;var b:=graph.get_point_position(other);var bh:=layout.height(b.x,b.y)
    var obstructed:=false
    # Skirt the existing shrine grove and fort walls; never clear their trees.
    for fraction in [0.0,.25,.5,.75,1.0]:
     var sample:Vector2=a.lerp(b,fraction)
     if sample.distance_to(Vector2(620,-198))<168.0 or Rect2(Vector2(452,-414),Vector2(136,128)).has_point(sample) or Rect2(Vector2(438,-326),Vector2(65,52)).has_point(sample):obstructed=true
    # Retained saved boulder/tree collision discovered by the physical survey.
    for obstacle:Vector2 in [Vector2(530,-190),Vector2(753.75,-593.75),Vector2(827.5,-622.5),Vector2(992,-682)]:
     var t:=clampf((obstacle-a).dot(b-a)/(b-a).length_squared(),0,1)
     if obstacle.distance_to(a.lerp(b,t))<3.0:obstructed=true
    if obstructed:continue
    var grade:=absf(bh-ah)/a.distance_to(b)
    if grade>.40:continue
    var mid:Vector2=(a+b)*.5
    if absf(layout.height(mid.x,mid.y)-(ah+bh)*.5)>1.0:continue
    graph.connect_points(id,other)
 var landmarks:=[Vector2(460,-250),Vector2(570,-440),Vector2(800,-650),Vector2(1000,-700),Vector2(960,-930)]
 var route: Array=[]
 for i in landmarks.size()-1:
  var path:=graph.get_point_path(graph.get_closest_point(landmarks[i]),graph.get_closest_point(landmarks[i+1]))
  if path.is_empty():push_error("REMOTE mountain route disconnected segment "+str(i));quit(1);return
  for p in path:
   if route.is_empty() or route[-1].distance_to(p)>.1:route.append(p)
 var source:="extends RefCounted\n## Terrain-surveyed mountain trail; rebuild with tools/world/build_remote_mountain_route.gd.\nconst POINTS := [\n"
 var length:=0.0
 for i in route.size():
  var p:Vector2=route[i]
  source+="Vector2(%.1f,%.1f),\n"%[p.x,p.y]
  if i>0:length+=p.distance_to(route[i-1])
 source+="]\n"
 var file:=FileAccess.open("res://world/suryagarh/remote_mountain_route.gd",FileAccess.WRITE);file.store_string(source);file.close()
 print("REMOTE MOUNTAIN ROUTE ",route.size()," points ",length,"m")
 quit(0)
