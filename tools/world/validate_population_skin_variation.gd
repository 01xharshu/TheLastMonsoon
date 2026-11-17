extends SceneTree
const Actor = preload("res://characters/npcs/indian/indian_street_actor.gd")
const SkinPass = preload("res://characters/npcs/indian/population_skin_variation.gd")
var issues: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
 if not value: issues.append(label);push_error(label)
func run() -> void:
 print("SKIN_PHASE setup")
 var world:=Node3D.new();world.name="SkinStudy";root.add_child(world);current_scene=world
 var clock: Node=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock);clock.clock_paused=true
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.45,.5,.54);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;world.add_child(env)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-30,0);sun.light_energy=1.0;world.add_child(sun)
 var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,1.15,6);camera.look_at(Vector3(0,1.0,0));camera.fov=48;camera.make_current()
 var names: Array[String]=[]
 for target in 3:
  for candidate in 1000:
   var identity:="Street_skin_sample_%d"%candidate
   if posmod(identity.hash(),SkinPass.TONES.size())==target:names.append(identity);break
 check(names.size()==3,"stable identities cover all tone indices")
 for sex in ["male","female"]:
  for index in 3:
   var actor:=Actor.new();actor.name=names[index] if sex=="male" else names[index]+"_female"
   # Pick a female identity with the same target index, keeping identity stable.
   if sex=="female":
    for candidate in 1000:
     var identity:="Street_skin_female_%d"%candidate
     if posmod(identity.hash(),SkinPass.TONES.size())==index:actor.name=identity;break
   actor.movement_enabled=false;actor.movement_profile=&"female" if sex=="female" else &"male"
   actor.add_child(load("res://characters/npcs/street_residents/%s_%02d.glb"%[sex,index+1]).instantiate())
   world.add_child(actor);actor.position=Vector3((index+(3 if sex=="female" else 0)-2.5)*.8,0,0)
   print("SKIN_PHASE actor ",actor.name)
   check(int(actor.get_meta("population_skin_tone",-1))==index,"stable tone on "+str(actor.name))
   var body_found:=false
   for mesh:MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
    if "makehuman_body" not in str(mesh.name).to_lower():continue
    var skin:=mesh.get_surface_override_material(0) as StandardMaterial3D
    var original:=mesh.mesh.surface_get_material(0) as StandardMaterial3D
    body_found=skin!=null and original!=null and skin.albedo_texture==original.albedo_texture and skin!=original
   check(body_found,"full body retains original skin texture "+str(actor.name))
   var before:Dictionary=world.get_meta(SkinPass.CACHE_KEY,{})
   var cache_count:=before.size()
   SkinPass.apply(actor)
   check(world.get_meta(SkinPass.CACHE_KEY,{}).size()==cache_count,"repeated appearance setup does not compound material tint")
 var cache:Dictionary=world.get_meta(SkinPass.CACHE_KEY,{})
 check(not cache.is_empty() and cache.size()<=18,"world-scoped material cache remains bounded")
 print("SKIN_PHASE render")
 for frame in 8:await process_frame
 if DisplayServer.get_name()!="headless":
  RenderingServer.force_draw()
  var folder:=OS.get_environment("TLM_SKIN_REVIEW")
  if not folder.is_empty():root.get_texture().get_image().save_png(folder.path_join("population_skin.png"))
 print("POPULATION_SKIN ",JSON.stringify({"passed":issues.is_empty(),"issues":issues,"actors":6,"tones":3,"cached_materials":cache.size()}))
 root.get_node("SaveManager").quit_game(0 if issues.is_empty() else 1)
