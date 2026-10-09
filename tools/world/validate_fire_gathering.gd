extends SceneTree
var errors: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var world: Node3D
 var clock: Node
 if "--full" in OS.get_cmdline_user_args():
  world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
  clock=world.get_node("GameTimeSystem")
 else:
  world=Node3D.new();root.add_child(world);current_scene=world
  clock=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
  world.add_child(load("res://world/suryagarh/generated/landscape.scn").instantiate())
  var bed=load("res://objects/charpai.tscn").instantiate();bed.name="Charpai";world.add_child(bed)
  world.add_child(load("res://tools/world/river_village_fixture.gd").new())
  world.add_child(load("res://world/suryagarh/settlements/village_daily_activities.gd").new())
 var night_start: bool="--night-start" in OS.get_cmdline_user_args()
 clock.clock_paused=true;clock.current_hour=20 if night_start else 10
 for frame in 180:await physics_frame
 var gathering:Node=root.find_child("FireGatheringResidents",true,false)
 if gathering==null:push_error("Missing gathering");quit(1);return
 gathering.set_physics_process(false)
 if gathering.members.size()!=4:errors.append("Daytime registration missing")
 for member in gathering.members:
  if member.active and not night_start:errors.append("Gathering active during day")
 clock.current_hour=20
 for step in 1800:
  gathering._physics_process(.1)
  for member in gathering.members:
   if member.active and member.actor.global_position.distance_to(gathering.fire.global_position)<1.8:errors.append("Approach enters fire safety radius")
 if gathering.members.size()!=4:errors.append("Expected four existing residents")
 for member in gathering.members:
  if member.actor.movement_profile!=&"male":errors.append("Only men should attend")
  if not member.active or not member.journey.arrived:errors.append(str(member.actor.name)+" did not arrive: "+str(member.journey.last_obstacle))
  if member.actor.global_position.distance_to(gathering.fire.global_position)<1.8:errors.append("Unsafe fire distance")
  if member.actor.animation_tree==null:errors.append("Missing animation tree")
  if member.activity.prop!=null and member.activity.prop.visible:errors.append("Work tools visible at fire")
 if gathering.members.filter(func(member):return member.lantern!=null).size()!=2:errors.append("Exactly two men carry lanterns")
 var output:=OS.get_environment("TLM_TEST_OUTPUT_DIR")
 if not output.is_empty():
  root.size=Vector2i(1280,720)
  var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR
  env.environment.background_color=Color(.015,.02,.035);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.4,.5,.7);env.environment.ambient_light_energy=.18;world.add_child(env)
  var camera:=Camera3D.new();world.add_child(camera);camera.current=true
  camera.global_position=gathering.fire.global_position+Vector3(7,3.5,7);camera.look_at(gathering.fire.global_position+Vector3.UP)
  var lights:Node=gathering.get_parent();lights._time_changed(1,20,0)
  gathering.set_physics_process(true)
  var started:=Time.get_ticks_msec()
  while Time.get_ticks_msec()-started<4000:await physics_frame
  await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png(output+"/fire.png")
  gathering.set_physics_process(false)
 clock.current_hour=6
 for step in 1800:
  gathering._physics_process(.1)
  for member in gathering.members:
   if member.active and member.actor.global_position.distance_to(gathering.fire.global_position)<1.8:errors.append("Approach enters fire safety radius")
 for member in gathering.members:
  if member.active:errors.append(str(member.actor.name)+" did not return: "+str(member.journey.last_obstacle))
  if member.lantern!=null and member.lantern.visible:errors.append("Lantern remains lit after dawn return")
  if member.activity.prop!=null and member.activity.prop.visible!=member.prop_visible:errors.append("Work prop visibility not restored")
 for member in gathering.members:
  member.activity.tick(.1)
  if member.actor.get_meta("daily_activity","")=="waiting_for_clear_path":errors.append("Daily routine blocked after return")
 print("FIRE GATHERING ","PASS" if errors.is_empty() else "FAIL",": ",errors)
 world.queue_free();await process_frame;await preload("res://tools/test_audio_cleanup.gd").finish(self,0 if errors.is_empty() else 1)
