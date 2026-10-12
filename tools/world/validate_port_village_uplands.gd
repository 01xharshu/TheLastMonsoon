extends SceneTree
const Layout=preload("res://world/suryagarh/landscape_layout.gd")
const Uplands=preload("res://world/suryagarh/port_village_uplands.gd")
var failures:Array[String]=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var layout:=Layout.new()
 var total:=0.0
 var max_grade:=0.0
 for i in Uplands.MAIN.size()-1:
  var a:Vector2=Uplands.MAIN[i];var b:Vector2=Uplands.MAIN[i+1]
  total+=a.distance_to(b)
  for step in int(a.distance_to(b)):
   var p:=a.lerp(b,float(step)/a.distance_to(b))
   var next:=a.lerp(b,minf(1.0,float(step+1)/a.distance_to(b)))
   var ph:=Uplands.grade_route(p,layout.height(p.x,p.y),Uplands.BRIDGE,Uplands.BRIDGE_GRADES,4.5,4.6) if Uplands.RAVINE_BOUNDS.has_point(p) else layout.height(p.x,p.y)
   var nh:=Uplands.grade_route(next,layout.height(next.x,next.y),Uplands.BRIDGE,Uplands.BRIDGE_GRADES,4.5,4.6) if Uplands.RAVINE_BOUNDS.has_point(next) else layout.height(next.x,next.y)
   max_grade=maxf(max_grade,absf(nh-ph)/maxf(.001,p.distance_to(next)))
   if ph<2.5:failures.append("road underwater")
 if max_grade>.3:failures.append("cart road too steep")
 if total<1600:failures.append("journey extension too short")
 if Uplands.MAIN[-1]!=Layout.ROUTES.village_west_lane[-1]:failures.append("village connection")
 for x in range(-860,80,5):
  if layout.height(x,385)>4.01:failures.append("land bypass across ravine")
 for z in range(395,505,5):
  if layout.height(-350,z)>4.01:failures.append("east spur bypass")
 for x in range(-550,-345,5):
  if layout.height(x,480)>4.01:failures.append("west spur bypass")
 for i in 3:
  var a:Vector2=Uplands.MAIN[i];var b:Vector2=Uplands.MAIN[i+1]
  if absf(Uplands.GRADES[i+1]-Uplands.GRADES[i])/a.distance_to(b)>.025:failures.append("port approach climbs immediately")
 var bypasses:Array=[[Vector2(-185,500),Vector2(-374,312)],[Vector2(-280,600),Vector2(-430,520)],[Vector2(-440,625),Vector2(-520,515)]]
 for attempt:Array in bypasses:
  var a:Vector2=attempt[0];var b:Vector2=attempt[1]
  var steepest:=0.0;var previous:=layout.height(a.x,a.y)
  var steps:=ceili(a.distance_to(b))
  for step in range(1,steps+1):
   var at:=a.lerp(b,float(step)/steps)
   var h:=layout.height(at.x,at.y)
   steepest=maxf(steepest,(h-previous)/(a.distance_to(b)/steps));previous=h
  print("BYPASS TRANSECT ",attempt," uphill_grade=",steepest)
  if steepest<1.05:failures.append("direct walking bypass has no steep uphill barrier: "+str(attempt))
 var span:Vector2=Uplands.BRIDGE[-1]-Uplands.BRIDGE[0]
 var deck_grade:float=absf(Uplands.BRIDGE_GRADES[-1]-Uplands.BRIDGE_GRADES[0])/span.length()
 if Uplands.BRIDGE.size()!=2 or deck_grade>.03:failures.append("bridge must be straight and gently graded")
 for end in [0,1]:
  var p:Vector2=Uplands.BRIDGE[end]
  if absf(layout.height(p.x,p.y)-Uplands.BRIDGE_GRADES[end])>.1:failures.append("bridge approach not connected to road")
 print("PORT VILLAGE ROUTE length_m=",total," max_grade=",max_grade," failures=",failures)
 quit(0 if failures.is_empty() else 1)
