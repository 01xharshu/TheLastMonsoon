extends SceneTree
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func run()->void:
 var world:Node3D
 var full:=OS.get_environment("TLM_GRAZING_WORLD")=="1"
 if full:
  var saves:Node=root.get_node("SaveManager");saves.options.graphics_quality=1;saves.options.fullscreen=false;saves.start_new_game();await scene_changed;world=current_scene
  while world.get_node_or_null("FieldGrazing")==null:await process_frame
 else:
  world=Node3D.new();root.add_child(world);current_scene=world
  world.add_child(load("res://world/suryagarh/generated/landscape.scn").instantiate())
  preload("res://world/suryagarh/tree_trunk_collision.gd").configure_terrain_support(world)
  world.add_child(load("res://world/suryagarh/settlements/field_grazing.gd").new())
 var pasture:Node3D=world.get_node("FieldGrazing")
 while not pasture.ready_for_grazing:await process_frame
 if full:
  var opening:Node=world.get_node_or_null("OpeningSequence")
  if opening!=null:
   var skip:=InputEventKey.new();skip.keycode=KEY_ESCAPE;skip.pressed=true;opening._input(skip);await process_frame;opening._input(skip)
   while is_instance_valid(opening) and opening.state!="done":await process_frame
 check(pasture.animals.size()==9,"three grazing herds contain six cows and three horses")
 var identities:Dictionary={};var roads_clear:=true;var supported:=true
 for animal in pasture.animals:
  animal.set_physics_process(false);identities[animal.identity]=true
  roads_clear=roads_clear and pasture.land_allowed(animal.position)
  supported=supported and absf(animal.position.y-pasture.ground(animal.position))<.05
 check(identities.size()==pasture.animals.size(),"herd identities unique and use existing draft save registry")
 check(roads_clear and supported,"pastures supported and clear of roads crops and service lanes")
 for species in ["bullock","horse"]:
  var selected:Node3D
  for animal in pasture.animals:
   if animal.kind==species:selected=animal;break
  if selected==null:check(false,"missing species "+species);continue
  var seen:Dictionary={};var contact:=0.0;var contact_samples:=0
  for frame in 850:
   selected.tick(.1);seen[selected.state]=true
   if selected.head_weight>.999 and selected.state=="graze":
    contact=maxf(contact,selected.muzzle_error);contact_samples+=1
   if frame%20==0:await physics_frame
  print("PASS GRAZING DIAGNOSTIC ",species," distance=",selected.distance_walked," states=",seen," position=",selected.position)
  check(seen.has("walk") and seen.has("pause") and seen.has("graze") and selected.distance_walked>1,"grazing pause and physical patch movement "+species)
  check(contact_samples>20 and contact<.06,"muzzle reaches grass within6cm "+species+" error="+str(contact))
  var finite:=true
  for bone in selected.rig.get_bone_count():finite=finite and selected.rig.get_bone_global_pose(bone).is_finite()
  check(finite,"finite articulated feeding pose "+species)
  var record:Dictionary=selected.export_grazing_state();var saved_state:String=selected.state;var saved_remaining:float=selected.remaining
  selected.state="pause";selected.remaining=0;selected.restore_grazing_state(record)
  check(selected.state==saved_state and is_equal_approx(selected.remaining,saved_remaining),"grazing state and remaining duration round trip "+species)
  selected.state="graze";selected.head_weight=1;selected.pose(.1)
 # Exercise a full remote-size step against a real solid in the meadow.
 if not pasture.animals.is_empty():
  var animal:Node3D=pasture.animals[0];var original:Vector3=animal.position
  var barrier:=StaticBody3D.new();var collider:=CollisionShape3D.new();var form:=BoxShape3D.new();form.size=Vector3(5,3,.4);collider.shape=form;barrier.add_child(collider);world.add_child(barrier)
  animal.rotation.y=0;barrier.position=original+Vector3(0,1.5,-2)
  animal.goal=original+Vector3(0,0,-4);animal.state="walk";animal.remaining=10
  await physics_frame
  for step in 8:animal.tick(.5)
  check(animal.position.z>barrier.position.z+.8,"remote-size grazing walk respects solid obstruction")
  barrier.queue_free();animal.position=original;animal.state="graze";animal.head_weight=1;animal.pose(.1)
 if full:
  var records:Dictionary=world.get_node("DraftAnimalYards").export_state().animals
  var saved:=true
  for animal in pasture.animals:saved=saved and records.has(animal.identity) and records[animal.identity].has("grazing")
  check(saved,"normal world includes herd health and position in existing saves")
 if OS.get_environment("TLM_TUTORIAL_OUTPUT")!="":
  if not full:
   var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-35,0);world.add_child(light)
   var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color(.5,.65,.75);env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.7;environment.environment=env;world.add_child(environment)
  else:
   var player:Node3D=world.get_node("Player");player.get_node("UI").hide();player.set_physics_process(false)
  var camera:=Camera3D.new();world.add_child(camera);camera.far=800
  for species in ["bullock","horse"]:
   for animal in pasture.animals:
    if animal.kind!=species:continue
    animal.state="graze";animal.head_weight=1;animal.pose(.1)
    var at:Vector3=animal.global_position
    if full:world.get_node("Player").position=at+Vector3.UP*3
    camera.position=at+animal.global_basis*Vector3(4,2.5,-4);camera.look_at(at+Vector3.UP*.85);camera.make_current()
    for frame in 8:await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(OS.get_environment("TLM_TUTORIAL_OUTPUT")+"/grazing_"+species+".png");break
  print("PASS GRAZING REVIEW READY")
  var deadline:=Time.get_ticks_msec()+45000
  while Time.get_ticks_msec()<deadline and not FileAccess.file_exists(OS.get_environment("TLM_TUTORIAL_OUTPUT")+"/grazing_done"):await process_frame
 await preload("res://tools/test_audio_cleanup.gd").finish(self,0 if failures.is_empty() else 1)
