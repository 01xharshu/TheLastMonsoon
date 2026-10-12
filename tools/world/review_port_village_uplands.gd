extends SceneTree
const Uplands=preload("res://world/suryagarh/port_village_uplands.gd")
var failures:Array[String]=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var world:=Node3D.new();root.add_child(world)
 world.add_child(load("res://world/suryagarh/generated/landscape.scn").instantiate())
 for frame in 4:await physics_frame
 var space:=world.get_world_3d().direct_space_state
 var capsule:=CapsuleShape3D.new();capsule.radius=.35;capsule.height=1.75
 var samples:=0;var maximum_grade:=0.0;var main_grade:=0.0
 var routes:Array=[Uplands.MAIN]+Uplands.SHORTCUTS.values()
 for route:Array in routes:
  var previous:=Vector3.INF
  for i in route.size()-1:
   var a:Vector2=route[i];var b:Vector2=route[i+1]
   for step in int(ceil(a.distance_to(b)/1.5)):
    var p:=a.lerp(b,float(step)/ceil(a.distance_to(b)/1.5))
    var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,150,p.y),Vector3(p.x,-10,p.y)))
    if hit.is_empty():failures.append("missing terrain");continue
    var at:Vector3=hit.position
    var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,at+Vector3.UP*1.0)
    if not space.intersect_shape(query,1).is_empty():failures.append("blocked capsule at "+str(at))
    if previous.is_finite():maximum_grade=maxf(maximum_grade,absf(at.y-previous.y)/maxf(.001,Vector2(at.x,at.z).distance_to(Vector2(previous.x,previous.z))))
    if route==Uplands.MAIN and previous.is_finite():main_grade=maxf(main_grade,absf(at.y-previous.y)/maxf(.001,Vector2(at.x,at.z).distance_to(Vector2(previous.x,previous.z))))
    previous=at;samples+=1
 if main_grade>.35:failures.append("saved main road/bridge grade too steep: "+str(main_grade))
 var coaches=preload("res://vehicles/coach_routes.gd")
 var graph:=coaches.build()
 var route:=coaches.route(graph,Vector2(-194,623),"Bhairavpur")
 var coach_length:=0.0
 for i in route.size()-1:coach_length+=route[i].distance_to(route[i+1])
 if coach_length<1600:failures.append("coach graph skips the long chase approach")
 var westmost:=0.0
 for point:Vector2 in route:westmost=minf(westmost,point.x)
 if route.is_empty() or westmost> -500:failures.append("coach graph bypasses winding road")
 var terrain:Node=world.get_child(0).get_node("TerrainTiles")
 for attempt:Array in [[Vector2(-185,500),Vector2(-374,312)],[Vector2(-280,600),Vector2(-430,520)],[Vector2(-440,625),Vector2(-520,515)]]:
  var a:Vector2=attempt[0];var b:Vector2=attempt[1]
  var steps:=ceili(a.distance_to(b));var steepest:=0.0
  var previous:=terrain_height(space,a,terrain)
  for step in range(1,steps+1):
   var at:=a.lerp(b,float(step)/steps);var h:=terrain_height(space,at,terrain)
   if not is_finite(h):failures.append("missing bypass terrain");break
   steepest=maxf(steepest,(h-previous)/(a.distance_to(b)/steps));previous=h
  print("SAVED BYPASS TRANSECT ",attempt," uphill_grade=",steepest)
  if steepest<1.0:failures.append("saved terrain permits a direct walking bypass")
 var lower_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-390,10,385),Vector3(-390,0,385)))
 if lower_hit.is_empty() or absf(lower_hit.position.y-4.0)>.2:failures.append("dry lower road missing")
 var visible_meshes:=0
 for mesh:MeshInstance3D in world.get_child(0).get_node("PortRavineBridge").find_children("*","MeshInstance3D",true,false):
  if mesh.mesh!=null:visible_meshes+=1
 if visible_meshes!=1:failures.append("unexpected water or unmerged timber in overbridge")
 print("PORT UPLANDS SAVED COLLISION samples=",samples," maximum_all_route_grade=",maximum_grade," main_grade=",main_grade," coach_points=",route.size()," coach_length=",coach_length," failures=",failures.slice(0,8))
 if DisplayServer.get_name()!="headless":
  var folder:=OS.get_environment("TLM_TEST_OUTPUT_DIR")
  assert(not folder.is_empty() and folder.begins_with(OS.get_environment("TMPDIR")))
  DisplayServer.window_set_size(Vector2i(1280,720))
  root.content_scale_size=Vector2i(1280,720)
  root.scaling_3d_scale=.3555556
  var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.4,.52,.65);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.65,.72,.78);env.environment.ambient_light_energy=.55;world.add_child(env)
  var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);world.add_child(sun)
  var camera:=Camera3D.new();camera.far=1800;world.add_child(camera);camera.current=true
  var views:Dictionary={"overview":[Vector3(-700,235,690),Vector3(-400,20,455)],"approach":[Vector3(-443,8,625),Vector3(-575,9.5,604)],"climb":[Vector3(-744,23,438),Vector3(-687,27,413)],"ridge":[Vector3(-521,44,560),Vector3(-433,42,521)],"bridge":[Vector3(-372,38,399),Vector3(-396,21,383)],"village_descent":[Vector3(-421,20,352),Vector3(-374,7,315)]}
  for identity:String in views:
   camera.position=views[identity][0]
   var ground=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(camera.position.x,180,camera.position.z),Vector3(camera.position.x,-20,camera.position.z)))
   if not ground.is_empty():camera.position.y=maxf(camera.position.y,ground.position.y+1.8)
   camera.look_at(views[identity][1])
   for frame in 5:await process_frame
   RenderingServer.force_draw()
   assert(root.get_texture().get_image().save_png(folder.path_join(identity+".png"))==OK)
 print("PORT UPLANDS REVIEW ","PASS" if failures.is_empty() else "FAIL")
 world.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)

func terrain_height(space:PhysicsDirectSpaceState3D,at:Vector2,terrain:Node) -> float:
 var query:=PhysicsRayQueryParameters3D.create(Vector3(at.x,150,at.y),Vector3(at.x,-20,at.y))
 var excluded:Array[RID]=[]
 for attempt in 24:
  query.exclude=excluded
  var hit:=space.intersect_ray(query)
  if hit.is_empty():return NAN
  if terrain.is_ancestor_of(hit.collider):return hit.position.y
  excluded.append(hit.collider.get_rid())
 return NAN
