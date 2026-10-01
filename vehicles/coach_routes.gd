extends RefCounted
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const STOPS := {"Bhairavpur":Vector2(-250,230),"Town Hall":Vector2(-320,-432),"Government House":Vector2(-390,-18),"Police Station":Vector2(320,150),"Company Compound":Vector2(345,252),"Hooghly Port":Vector2(-194,623)}
static func build() -> AStar2D:
 var graph := AStar2D.new()
 var layout := Layout.new()
 var paths: Array = Layout.ROUTES.values().duplicate()
 var trunk: Array[Vector2] = []
 for z in range(-470,651,10): trunk.append(Vector2(layout.road_x(z),z))
 paths.append(trunk)
 paths.append([Vector2(layout.road_x(165),165),Vector2(273,165)])
 paths.append([Vector2(-230,180),Vector2(layout.road_x(180),180)])
 for path in paths:
  var previous := -1
  for segment in path.size()-1:
   var a: Vector2 = path[segment]
   var b: Vector2 = path[segment+1]
   var divisions := maxi(1,ceili(a.distance_to(b)/10.0))
   for index in divisions+1:
    var point := a.lerp(b,float(index)/divisions)
    var id := graph.get_point_count()
    graph.add_point(id,point)
    if previous >= 0: graph.connect_points(previous,id)
    previous = id
 var ids := graph.get_point_ids()
 for i in ids.size():
  for j in range(i+1,ids.size()):
   if graph.get_point_position(ids[i]).distance_to(graph.get_point_position(ids[j])) < 11.0: graph.connect_points(ids[i],ids[j])
 return graph
static func route(graph: AStar2D, start: Vector2, destination: String) -> PackedVector2Array:
 if not STOPS.has(destination): return PackedVector2Array()
 var id := graph.get_closest_point(start)
 if start.distance_to(graph.get_point_position(id)) > 40.0: return PackedVector2Array()
 var end := graph.get_closest_point(STOPS[destination])
 return graph.get_point_path(id,end)
