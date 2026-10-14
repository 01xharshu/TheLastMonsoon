extends SceneTree
const Uplands=preload("res://world/suryagarh/port_village_uplands.gd")
var failures:Array[String]=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var temporary:=OS.get_environment("TLM_TEST_OUTPUT_DIR")
 assert(not temporary.is_empty() and temporary.begins_with(OS.get_environment("TMPDIR")))
 root.get_node("SaveManager").save_root=temporary
 var world:=Node3D.new();root.add_child(world);current_scene=world
 var clock:=GameTimeSystem.new();clock.name="GameTimeSystem";world.add_child(clock);clock.set_process(false)
 world.add_child(load("res://world/suryagarh/generated/landscape.scn").instantiate())
 var player:CharacterBody3D=load("res://player/player.tscn").instantiate();world.add_child(player)
 player.set_process_unhandled_input(false);player.get_node("UI").hide()
 for frame in 5:await physics_frame
 var space:=world.get_world_3d().direct_space_state
 for case in (0 if "--bypass-only" in OS.get_cmdline_user_args() else 3):
  var reversed:=case==1
  var points:Array=Uplands.BRIDGE.duplicate() if case<2 else [Vector2(-425,385),Vector2(-375,385)]
  if reversed:points.reverse()
  var start:Vector2=points[0]
  var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(start.x,100,start.y),Vector3(start.x,-20,start.y)))
  player.position=hit.position+Vector3.UP*1.05;player.velocity=Vector3.ZERO
  for frame in 15:await physics_frame
  var goal:=1;var frames:=0;var minimum_fall:=0.0
  Input.action_press("move_forward")
  while goal<points.size() and frames<1600:
   var target:Vector2=points[goal]
   var offset:=target-Vector2(player.position.x,player.position.z)
   if offset.length()<1.0:goal+=1;continue
   player.get_node("CameraPivot").global_rotation.y=atan2(-offset.x,-offset.y)
   await physics_frame;frames+=1
   minimum_fall=minf(minimum_fall,player.velocity.y)
  Input.action_release("move_forward")
  if goal<points.size() or minimum_fall< -3:failures.append("crossing failed "+str(reversed))
  print("PORT BRIDGE WALK case=",case," reverse=",reversed," arrived=",goal==points.size()," frames=",frames," minimum_fall=",minimum_fall)
 var terrain:Node=world.get_node("Landscape/TerrainTiles")
 var case_id:=0
 for attempt:Array in [[Vector2(-185,500),Vector2(-374,312)],[Vector2(-280,600),Vector2(-430,520)],[Vector2(-440,625),Vector2(-520,515)]]:
  var a:Vector2=attempt[0];var b:Vector2=attempt[1]
  var direction:Vector2=(b-a).normalized();var length:=a.distance_to(b)
  var steps:=ceili(length);var peak:=0;var steepest:=0.0;var previous:=terrain_height(space,a,terrain)
  for step in range(1,steps+1):
   var at:=a.lerp(b,float(step)/steps);var h:=terrain_height(space,at,terrain)
   if (h-previous)/(length/steps)>steepest:steepest=(h-previous)/(length/steps);peak=step
   previous=h
  var start:Vector2=a+direction*(float(peak)*length/steps-4.0)
  var goal:Vector2=start+direction*10.0
  player.position=Vector3(start.x,terrain_height(space,start,terrain)+1.05,start.y);player.velocity=Vector3.ZERO
  for frame in 15:await physics_frame
  player.get_node("CameraPivot").global_rotation.y=atan2(-direction.x,-direction.y)
  Input.action_press("move_forward")
  var progress:=0.0;var closest:=INF
  for frame in 300:
   var offset:=goal-Vector2(player.position.x,player.position.z)
   closest=minf(closest,offset.length())
   if offset.length()<1.0:break
   player.get_node("CameraPivot").global_rotation.y=atan2(-offset.x,-offset.y)
   await physics_frame
   progress=maxf(progress,(Vector2(player.position.x,player.position.z)-start).dot(direction))
  Input.action_release("move_forward")
  if closest<1.0:failures.append("actual Arjun walks through direct bypass "+str(case_id))
  print("PORT BYPASS WALK case=",case_id," attempted_m=10 progress_m=",progress," closest_goal_m=",closest," blocked=",closest>=1.0)
  case_id+=1
 world.queue_free();current_scene=null
 for frame in 3:await process_frame
 print("PORT BRIDGE WALK ","PASS" if failures.is_empty() else failures)
 root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)

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
