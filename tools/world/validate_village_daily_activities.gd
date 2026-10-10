extends SceneTree
var errors:Array[String]=[]
func _initialize()->void:run.call_deferred()
func run()->void:
 var world:Node3D
 if "--full" in OS.get_cmdline_user_args():world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world)
 else:
  world=Node3D.new();root.add_child(world)
  var clock=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
  world.add_child(load("res://world/suryagarh/generated/landscape.scn").instantiate())
  var charpai=load("res://objects/charpai.tscn").instantiate();charpai.name="Charpai";world.add_child(charpai)
  world.add_child(load("res://tools/world/river_village_fixture.gd").new())
  world.add_child(load("res://horses/village_stable.gd").new())
  world.add_child(load("res://world/suryagarh/settlements/village_daily_activities.gd").new())
 current_scene=world
 if world.has_node("OpeningSequence"):
  var skip:=InputEventKey.new();skip.keycode=KEY_ESCAPE;skip.pressed=true;world.get_node("OpeningSequence")._input(skip)
  for frame in 2:await process_frame
  world.get_node("OpeningSequence")._input(skip)
  world.get_node("Player").set_physics_process(false)
 var clock:Node=world.get_node("GameTimeSystem");clock.clock_paused=true;clock.current_hour=10
 var manager:Node=get_nodes_in_group("village_daily_activities")[0]
 for frame in 150:
  await physics_frame
  if manager.residents.size()==14:break
 if manager.residents.size()!=14:errors.append("expected fourteen working/social residents")
 var roles:Dictionary={};var max_hand:=0.0;var delivered:=0
 for person:Node3D in manager.residents:
  var activity:Node=person.get_node("DailyActivity");activity.set_physics_process(false)
  roles[activity.job]=int(roles.get(activity.job,0))+1
  for step in 90:
   activity.elapsed+=.05;activity.tick(.05)
   max_hand=maxf(max_hand,activity.hand_error)
  if activity.job=="groom" and not activity.visits.has("groom"):errors.append("stable keeper never reaches horse grooming")
  print("ACTIVITY_HAND ",person.name," ",activity.hand_error)
  if person.animation_tree==null:errors.append(person.name+": missing personal tree")
  if not person.global_position.is_finite():errors.append(person.name+": invalid transform")
  if person.body_collider.collision_layer!=1:errors.append(person.name+": not solid")
 if max_hand>.025:errors.append("work palm target exceeds 25 mm")
 if manager.owned_horse==null or manager.owned_horse.get_meta("owner","")!="Arjun":errors.append("Arjun home horse missing")
 for step in 400:
  for index in [4,5]:
   var drawing:Node=manager.residents[index].get_node("DailyActivity")
   drawing.elapsed+=.05;drawing.tick(.05);max_hand=maxf(max_hand,drawing.hand_error)
 for index in [4,5]:
  if manager.residents[index].get_meta("water_draws",0)<1:errors.append("well users do not alternate completed draws")
 if max_hand>.025 and not errors.has("work palm target exceeds 25 mm"):errors.append("work palm target exceeds 25 mm")
 var saved:Dictionary=manager.export_state()
 manager.restore_state(JSON.parse_string(JSON.stringify(saved)))
 var restored:Dictionary=manager.export_state()
 for label in saved:
  for key in saved[label]:
   var before:Variant=saved[label][key];var after:Variant=restored[label][key]
   if before is Array:
    for i in before.size():
     if absf(float(before[i])-float(after[i]))>.00001:errors.append("saved position changed")
   elif before is float:
    if absf(before-float(after))>.00001:errors.append("saved clock changed")
   elif before!=after:errors.append("saved activity state changed: "+key)
 var crop_count:=0
 for field_name in ["EstateField0","EstateField3"]:
  var field:=root.find_child(field_name,true,false)
  if field==null or not field.has_node("YoungCropRows"):errors.append(field_name+": crop rows absent")
  else:crop_count+=field.get_node("YoungCropRows").multimesh.instance_count
 if "--commute" in OS.get_cmdline_user_args():
  clock.current_hour=19
  for step in 1800:
   for person in manager.residents:person.get_node("DailyActivity").tick(.1,false)
   await physics_frame
  for person in manager.residents:
   var routine:Node=person.get_node("DailyActivity")
   var left:=Vector2(person.global_position.x,person.global_position.z).distance_to(routine.home)
   print("HOME_COMMUTE ",person.name," remaining=",left," state=",person.get_meta("daily_activity")," route=",routine.route_goal)
   if left>.15:errors.append(person.name+": home route blocked")
 var output:=OS.get_environment("TLM_TEST_OUTPUT_DIR")
 if not output.is_empty():
  root.size=Vector2i(1280,720)
  var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-25,0);world.add_child(sun)
  var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR
  env.environment.background_color=Color(.28,.34,.40);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
  env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.65;world.add_child(env)
  var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.fov=43
  for record in [{"name":"fields","index":0},{"name":"well","index":4},{"name":"seated","index":8},{"name":"delivery","index":10}]:
   var person:Node3D=manager.residents[record.index]
   camera.global_position=person.global_position+Vector3(2.3,1.9,3.6);camera.look_at(person.global_position+Vector3(0,.8,0))
   await process_frame;RenderingServer.force_draw(false)
   root.get_texture().get_image().save_png(output+"/activity_"+record.name+".png")
  for person in manager.residents:person.get_node("DailyActivity").set_physics_process(true)
  var started:=Time.get_ticks_msec();var frames:=0
  camera.global_position=manager.residents[0].global_position+Vector3(2,1.8,3);camera.look_at(manager.residents[0].global_position+Vector3.UP*.8)
  while Time.get_ticks_msec()-started<4000:
   await physics_frame;frames+=1
  print("VILLAGE_ACTIVITY_LIVE frames=",frames," wall_seconds=",float(Time.get_ticks_msec()-started)/1000)
  camera.global_position=manager.owned_horse.global_position+Vector3(-4,2.5,-5);camera.look_at(manager.owned_horse.global_position+Vector3.UP)
  await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png(output+"/activity_home_horse.png")
 print("VILLAGE_ACTIVITIES_RESULT ",JSON.stringify({"passed":errors.is_empty(),"residents":manager.residents.size(),"roles":roles,"crop_instances":crop_count,"max_hand_error":max_hand,"errors":errors}))
 world.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
