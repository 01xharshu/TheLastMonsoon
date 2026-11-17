extends SceneTree
const Ground=preload("res://world/suryagarh/tree_trunk_collision.gd")
var failures:Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
 if not ok:failures.append(label);push_error(label)
func run() -> void:
 var saves:Node=root.get_node("SaveManager");saves.save_root=OS.get_environment("TLM_TREE_REVIEW");saves.options.graphics_quality=1;saves.options.fullscreen=false;saves.apply_options();saves.start_new_game();await scene_changed
 var world:Node3D=current_scene
 while not world.get_node("WildernessExpansion").has_meta("tree_variety_counts"):await process_frame
 while world.get_node_or_null("OpeningSequence")==null:await process_frame
 var opening:Node=world.get_node("OpeningSequence")
 var skip:=InputEventKey.new();skip.keycode=KEY_ESCAPE;skip.pressed=true;opening._input(skip);await process_frame;opening._input(skip)
 while is_instance_valid(opening) and opening.state!="done":await process_frame
 var clock:Node=world.get_node("GameTimeSystem");clock.current_hour=10;clock.total_game_minutes=600;clock.clock_paused=true;clock._update_readable_time(true)
 var camera:=Camera3D.new();world.add_child(camera);camera.far=1800;camera.fov=65;camera.make_current()
 var review_roots:Array=[]
 var lands:Array=[world.get_node("Landscape"),world.get_node("WildernessExpansion")]
 for land in lands:
  check(land.get_meta("tree_variety_counts").size()==7,"all seven types in "+str(land.name))
  var roots:=0;var grounded:=0;var triangles:=0;var original_triangles:=0
  for batch in land.get_node("NatureTiles").find_children("BroadleafTrees*","MultiMeshInstance3D",true,false):
   if not batch.visible or batch.multimesh.instance_count==0:continue
   var profile:=Ground.profile(batch.multimesh.mesh)
   for surface in batch.multimesh.mesh.get_surface_count():triangles+=batch.multimesh.mesh.surface_get_array_index_len(surface)*batch.multimesh.instance_count/3
   check(profile.size()==3,"woody trunk profile in "+str(batch.name))
   for at in Ground.instance_transforms(batch.multimesh):
    var base:Vector3=profile[0].centre-Vector3.UP*float(profile[0].height)*.5
    var point:Vector3=batch.to_global(at*base);var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*5,point-Vector3.UP*5,Ground.TERRAIN_SUPPORT_LAYER)
    var support:=world.get_world_3d().direct_space_state.intersect_ray(query)
    review_roots.append({"point":point,"kind":batch.get_meta("tree_variety",""),"height":batch.multimesh.mesh.get_aabb().size.y*at.basis.get_scale().y})
    if batch.get_meta("tree_variety","")=="banyan":
     for prop in batch.multimesh.mesh.get_meta("prop_roots"):
      var foot:Vector3=batch.to_global(at*(prop.centre-Vector3.UP*float(prop.height)*.5))
      var prop_query:=PhysicsRayQueryParameters3D.create(foot+Vector3.UP*5,foot-Vector3.UP*5,Ground.TERRAIN_SUPPORT_LAYER)
      var soil:=world.get_world_3d().direct_space_state.intersect_ray(prop_query)
      check(not soil.is_empty() and foot.y<=soil.position.y+.006,"banyan prop root meets actual terrain")
    roots+=1
    if not support.is_empty() and absf(point.y-support.position.y+.12)<.03:grounded+=1
  for record in land.get_meta("tree_variety_reference",[]):
   var live:=0
   for at in Ground.instance_transforms(record.source):
    if not is_zero_approx(at.basis.determinant()):live+=1
   for surface in record.source.mesh.get_surface_count():original_triangles+=record.source.mesh.surface_get_array_index_len(surface)*live/3
  check(triangles<=original_triangles*1.15,"palette base triangle budget within15percent "+str(land.name))
  print("TREE GEOMETRY ",land.name," reference=",original_triangles," variety=",triangles)
  check(grounded==roots and roots>100,"all roots supported in "+str(land.name))
  print("TREE WORLD ROOTS ",land.name," total=",roots," grounded=",grounded)
 var layout=world.layout
 for region in [{"name":"village","at":Vector2(-230,180),"look":Vector2(-270,210)},{"name":"east","at":Vector2(470,-250),"look":Vector2(500,-290)},{"name":"wilderness","at":Vector2(-550,-1076),"look":Vector2(-570,-1030)}]:
  if region.name=="east":
   var closest:=INF;var focus:=Vector3.ZERO
   for tree in review_roots:
    var distance:float=Vector2(tree.point.x,tree.point.z).distance_squared_to(region.at)
    if tree.kind=="spreading" and distance<closest:closest=distance;focus=tree.point
   region.at=Vector2(focus.x+18,focus.z+20);region.look=Vector2(focus.x,focus.z)
  world.player.global_position=Vector3(region.at.x,layout.height(region.at.x,region.at.y)+1,region.at.y)
  camera.global_position=world.player.global_position+Vector3.UP*2.0
  camera.look_at(Vector3(region.look.x,layout.height(region.look.x,region.look.y)+3,region.look.y))
  for mode in ["reference","variety"]:
   for land in lands:
    for record in land.get_meta("tree_variety_reference",[]):
     for part in record.parts:
      if part!=record.batch:part.visible=mode=="variety"
     record.batch.multimesh=record.source if mode=="reference" else record.varied;record.batch.visible=record.visible if mode=="reference" else record.get("varied_visible",true)
   for i in 20:await process_frame
   var times:Array[float]=[];var prior:=Time.get_ticks_usec()
   var epoch_path:=OS.get_environment("TLM_TREE_REVIEW").path_join("native_epoch")
   var epoch:=FileAccess.get_file_as_string(epoch_path) if FileAccess.file_exists(epoch_path) else ""
   while times.size()<60:
    await process_frame;await RenderingServer.frame_post_draw
    var now:=Time.get_ticks_usec()
    var current_epoch:=FileAccess.get_file_as_string(epoch_path) if FileAccess.file_exists(epoch_path) else ""
    if current_epoch!=epoch:
     epoch=current_epoch;times.clear()
     for frame in 20:await process_frame
     prior=Time.get_ticks_usec();continue
    times.append((now-prior)/1000.0);prior=now
   times.sort();print("TREE FRAME ",region.name," ",mode," p50_ms=",times[30]," p95_ms=",times[57])
   if mode=="variety":
    root.get_texture().get_image().save_png(OS.get_environment("TLM_TREE_REVIEW").path_join("world_"+region.name+".png"))
 for kind in ["peepal","banyan","palm"]:
  var closest:=INF;var selected:Dictionary={}
  for tree in review_roots:
   var distance:float=Vector2(tree.point.x,tree.point.z).distance_squared_to(Vector2(-230,180))
   if tree.kind==kind and distance<closest:closest=distance;selected=tree
  check(not selected.is_empty(),"named species exists in normal world: "+kind)
  if selected.is_empty():continue
  var focus:Vector3=selected.point;var height:float=selected.height
  world.player.global_position=focus+Vector3(15,1,15)
  camera.global_position=focus+Vector3(height*1.2,height*.7,height*1.5)
  var ground:=PhysicsRayQueryParameters3D.create(camera.global_position+Vector3.UP*100,camera.global_position-Vector3.UP*100,Ground.TERRAIN_SUPPORT_LAYER)
  var support:=world.get_world_3d().direct_space_state.intersect_ray(ground)
  if not support.is_empty():camera.global_position.y=maxf(camera.global_position.y,support.position.y+height*.4)
  camera.look_at(focus+Vector3.UP*height*.5)
  for frame in 6:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("TLM_TREE_REVIEW").path_join("world_"+kind+".png"))
  print("TREE NAMED LOCATION ",kind," ",focus)
 print("TREE WORLD REVIEW READY ",OS.get_environment("TLM_TREE_REVIEW"))
 var deadline:=Time.get_ticks_msec()+90000
 while not FileAccess.file_exists(OS.get_environment("TLM_TREE_REVIEW").path_join("review_done")) and Time.get_ticks_msec()<deadline:await process_frame
 print("TREE VARIETY: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
 saves.quit_game(0 if failures.is_empty() else 1)
