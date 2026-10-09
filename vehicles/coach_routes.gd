extends RefCounted
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const Bridge = preload("res://world/suryagarh/timber_bridge.gd")
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
 return bridge_lanes(graph.get_point_path(id,end))

static func route_to_point(graph: AStar2D, start: Vector2, goal: Vector2) -> PackedVector2Array:
 var first := graph.get_closest_point(start)
 var last := graph.get_closest_point(goal)
 if start.distance_to(graph.get_point_position(first)) > 40 or goal.distance_to(graph.get_point_position(last)) > 40: return PackedVector2Array()
 var points := graph.get_point_path(first,last)
 if not points.is_empty(): points.append(goal)
 return bridge_lanes(points)

static func bridge_lanes(points: PackedVector2Array) -> PackedVector2Array:
 var lanes := points.duplicate()
 var center := Layout.new().river_x(Bridge.CROSSING_Z)
 for index in points.size():
  var point := points[index]
  if absf(point.y-Bridge.CROSSING_Z) > .1: continue
  var along := absf(point.x-center)
  if along > Bridge.HALF_SPAN+Bridge.RAMP+8.0: continue
  var before := points[maxi(index-1,0)]
  var after := points[mini(index+1,points.size()-1)]
  var direction := signf(after.x-before.x)
  var blend := clampf((Bridge.HALF_SPAN+Bridge.RAMP+8.0-along)/8.0,0.0,1.0)
  lanes[index].y += direction*Bridge.LANE_OFFSET*blend
 return lanes
