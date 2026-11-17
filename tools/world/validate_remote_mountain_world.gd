extends SceneTree
var failures: Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func run()->void:
 var saves: Node=root.get_node("SaveManager");saves.options.graphics_quality=1;saves.options.fullscreen=false;saves.apply_options()
 saves.start_new_game();await scene_changed
 var world:Node3D=current_scene
 while world.get_node_or_null("RemoteMountains")==null:await process_frame
 var region:Node3D=world.get_node("RemoteMountains")
 while not region.ready_for_exploration:await process_frame
 while world.get_node_or_null("FieldGrazing")==null:await process_frame
 while not world.get_node("FieldGrazing").ready_for_grazing:await process_frame
 await process_frame
 var opening:Node=world.get_node_or_null("OpeningSequence")
 if opening!=null:
  var skip:=InputEventKey.new();skip.keycode=KEY_ESCAPE;skip.pressed=true;opening._input(skip);await process_frame;opening._input(skip)
  while is_instance_valid(opening) and opening.state!="done":await process_frame
 var player:CharacterBody3D=world.get_node("Player")
 var map:Control=player.get_node("UI/WorldMap");map.refresh_sites()
 check(map.sites.has("Northern mountain refuge") and map.sites.has("Northeastern summit"),"normal New Journey registers remote region and actual map destinations")
 var missing:=0;var blocked:=0
 var terrain:=preload("res://world/suryagarh/tree_trunk_collision.gd")
 var excluded: Array[RID]=terrain.terrain_exclusions(world);excluded.append(player.get_rid())
 var capsule:=CapsuleShape3D.new();capsule.radius=.35;capsule.height=1.6
 for point:Vector3 in region.route:
  var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform.origin=point+Vector3.UP*1.05;query.collision_mask=1;query.exclude=excluded
  var hits:=world.get_world_3d().direct_space_state.intersect_shape(query,4)
  if not hits.is_empty():
   blocked+=1
   if blocked<6:print("MOUNTAIN WORLD BLOCK ",point," ",hits[0].collider.get_path())
 check(blocked==0,"populated world mountain route remains clear after forest and collision setup")
 var period_review:=OS.get_environment("TLM_PERIOD_REVIEW")=="1"
 if period_review:
  var settlement:Node3D=world.get_node("Settlement")
  var stall:Node3D=settlement.get_node("BhairavpurMarketStall0")
  var scale_node:Node3D=stall.get_node_or_null("MerchantBeamBalance")
  check(scale_node!=null and scale_node.find_children("Dish*","MeshInstance3D",true,false).size()>=1 and scale_node.get_child_count()==16,"merchant balance includes both suspended pans, six cords and loose weights")
  var wares_count:=0
  for id in [1,3,5]:
   var counter:Node3D=settlement.get_node("BhairavpurMarketStall%d"%id)
   for item in counter.get_children():
    if item is MeshInstance3D and item.mesh is ArrayMesh and is_equal_approx(item.position.y,.93) and absf(item.position.z)<.6 and absf(item.position.x)<2.2:
     wares_count+=1
  check(wares_count==10,"ten pottery and brassware meshes rest on existing market counters")
 if OS.get_environment("TLM_TUTORIAL_OUTPUT")!="":
  var camera:=Camera3D.new();world.add_child(camera);camera.far=1800
  player.get_node("UI").hide()
  for label in ([] if period_review else ["crags","refuge","path"]):
   var at:Vector3=region.surface(Vector2(860,-820)) if label=="crags" else region.get_node("Northernmountainrefuge").global_position
   if label=="path":at=region.route[int(region.route.size()/2)]
   player.position=at+Vector3.UP*2;player.velocity=Vector3.ZERO;player.set_physics_process(false)
   camera.position=at+Vector3(-70,28,40) if label=="crags" else at+Vector3(8,5,-10);camera.look_at(at+Vector3.UP*2)
   if label=="path":
    var forward:Vector3=(region.route[int(region.route.size()/2)+8]-at).normalized()
    camera.position=at-forward*5+Vector3.UP*2.3;camera.look_at(at+forward*9+Vector3.UP*.5)
   camera.make_current()
   for frame in 12:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OS.get_environment("TLM_TUTORIAL_OUTPUT")+"/mountain_world_"+label+".png")
  if period_review:
   player.set_physics_process(false)
   camera.make_current()
   var stall:Node3D=world.get_node("Settlement/BhairavpurMarketStall0")
   var balance:Node3D=stall.get_node("MerchantBeamBalance")
   var vessels:Node3D=world.get_node("Settlement/BhairavpurMarketStall3")
   for target:Node3D in [balance,vessels]:
    var at:Vector3=target.global_position
    if target==vessels:at+=Vector3.UP
    player.hide();player.position=at+Vector3.UP*3
    camera.position=at+target.global_basis*Vector3(.9,1.2,-2.2);camera.look_at(at+Vector3.UP*.35)
    for frame in 12:await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(OS.get_environment("TLM_TUTORIAL_OUTPUT")+"/period_"+str(target.name)+".png")
  print("MOUNTAIN WORLD REVIEW READY")
  var deadline:=Time.get_ticks_msec()+45000
  while Time.get_ticks_msec()<deadline and not FileAccess.file_exists(OS.get_environment("TLM_TUTORIAL_OUTPUT")+"/mountain_done"):await process_frame
 print("MOUNTAIN WORLD ","PASS" if failures.is_empty() else "FAIL",failures)
 await preload("res://tools/test_audio_cleanup.gd").finish(self,0 if failures.is_empty() else 1)
