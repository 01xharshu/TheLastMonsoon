extends SceneTree
## Real physics-paced review; caller owns temporary output and timeout cleanup.
var errors: Array[String]=[]
var max_contact:=0.0
var max_reach_error:=0.0
var waits: Dictionary={}
var previous_sample:=0
var frames:=0
var max_stance_error:=0.0
var stance_samples:=0
var camera: Camera3D
var gathering: Node
var output: String
func _initialize() -> void:run.call_deferred()
func capture(label: String, actor: Node3D, distance: float) -> void:
 camera.global_position=actor.global_position+Vector3(distance*.7,distance*.4,distance)
 camera.look_at(actor.global_position+Vector3.UP*.9)
 await process_frame
 if DisplayServer.get_name()=="headless":return
 RenderingServer.force_draw(false)
 if not output.is_empty():save_frame(label)
func save_frame(label: String) -> void:
 var frame:=root.get_texture().get_image()
 frame.resize(1280,720)
 frame.save_png(output+"/"+label+".png")
func phase(seconds: float, label: String) -> void:
 var start:=Time.get_ticks_msec()
 var next_capture:=8.0
 var captured:=false
 previous_sample=Time.get_ticks_msec()
 while Time.get_ticks_msec()-start<seconds*1000:
  await physics_frame;frames+=1
  for member in gathering.members:
   var actor: Node3D=member.actor
   if actor.foot_plant.active:
    var ankle: Vector3=actor._skeleton.to_global(actor._skeleton.get_bone_global_pose(actor.foot_plant.legs[actor.foot_plant.planted_side][2]).origin)
    max_stance_error=maxf(max_stance_error,ankle.distance_to(actor.foot_plant.planted_world));stance_samples+=1
   if member.lantern!=null:
    max_contact=maxf(max_contact,member.lantern.hand_error)
    max_reach_error=maxf(max_reach_error,member.lantern.reach_error)
   var id: int=actor.get_instance_id()
   var stopped: bool=member.journey!=null and not member.journey.arrived and member.journey.last_obstacle!=""
   waits[id]=float(waits.get(id,0.0))+float(Time.get_ticks_msec()-previous_sample)/1000.0 if stopped else 0.0
   if waits[id]>3.0:
    var issue: String=str(actor.name)+" persistently blocked by "+member.journey.last_obstacle
    if issue not in errors:errors.append(issue)
  previous_sample=Time.get_ticks_msec()
  if gathering.members.size()>0 and label!="social":
   var person: Node3D=gathering.members[0].actor
   camera.global_position=person.global_position+Vector3(2.3,1.7,3.3)
   camera.look_at(person.global_position+Vector3.UP*.9)
  var elapsed:=float(Time.get_ticks_msec()-start)/1000.0
  if not captured and elapsed>=next_capture and gathering.members.size()==4:
   captured=true
   await capture(label+"_walk",gathering.members[0].actor,3.0)
  if gathering.members.size()==4 and gathering.members.all(func(member):return member.active and member.journey!=null and member.journey.arrived) and label=="evening":break
  if label=="dawn" and gathering.members.size()==4 and gathering.members.all(func(member):return not member.active):break
 for member in gathering.members:
  print("FIRE POSITION ",label," ",member.actor.name," at=",member.actor.global_position," goal=",member.journey.goal if member.journey!=null else -1," obstacle=",member.journey.last_obstacle if member.journey!=null else "none")
 print("FIRE LIVE ",label," wall_seconds=",float(Time.get_ticks_msec()-start)/1000.0)
func set_hour(clock: Node,hour: int) -> void:
 clock.advance_minutes(fposmod(hour*60.0-fmod(clock.total_game_minutes,1440.0),1440.0))
func run() -> void:
 output=OS.get_environment("TLM_TEST_OUTPUT_DIR")
 if output.is_empty():push_error("Set temporary TLM_TEST_OUTPUT_DIR");quit(1);return
 root.size=Vector2i(1280,720)
 root.scaling_3d_scale=.5
 var world: Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate() if "--full" in OS.get_cmdline_user_args() else Node3D.new()
 root.add_child(world);current_scene=world
 if not world.has_node("GameTimeSystem"):
  var clock_node=load("res://world/suryagarh/systems/game_time_system.gd").new();clock_node.name="GameTimeSystem";world.add_child(clock_node)
  world.add_child(load("res://world/suryagarh/generated/landscape.scn").instantiate())
  var bed=load("res://objects/charpai.tscn").instantiate();bed.name="Charpai";world.add_child(bed)
  world.add_child(load("res://tools/world/river_village_fixture.gd").new())
  world.add_child(load("res://world/suryagarh/settlements/village_daily_activities.gd").new())
  var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR
  env.environment.background_color=Color(.015,.02,.035);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.4,.5,.7);env.environment.ambient_light_energy=.3;world.add_child(env)
 var clock: Node=world.get_node("GameTimeSystem");clock.clock_paused=true;set_hour(clock,10)
 for frame in 180:
  await physics_frame
  var residents:=root.find_child("FireGatheringResidents",true,false)
  if residents!=null and residents.members.size()==4:break
 var opening:=world.get_node_or_null("OpeningSequence")
 if opening!=null:
  opening.cart_passage.finish()
  opening._release()
  await process_frame
 var player:=world.get_node_or_null("Player")
 if player!=null:
  player.set_physics_process(false)
  player.get_node("UI").hide()
  world.get_node("LandscapeUI").hide()
 root.get_node("SaveManager").pending_slot=-1
 root.get_node("WorldAudio").set_opening_quiet(false)
 clock.clock_paused=true
 gathering=root.find_child("FireGatheringResidents",true,false)
 camera=Camera3D.new();world.add_child(camera);camera.current=true
 set_hour(clock,20)
 camera.global_position=Vector3(-284,12,247);camera.look_at(Vector3(-279,8,239))
 await phase(300,"evening")
 for member in gathering.members:
  if not member.active or not member.journey.arrived:errors.append(str(member.actor.name)+" did not arrive in real time")
 await capture("circle",gathering.fire,6.0)
 await phase(5,"social")
 for index in gathering.members.size():await capture("contact_%d"%index,gathering.members[index].actor,2.2)
 set_hour(clock,6)
 await phase(300,"dawn")
 for member in gathering.members:
  if member.active:errors.append(str(member.actor.name)+" did not return in real time")
 if max_reach_error>.025:errors.append("Lantern requested handle reach exceeds 25mm")
 if stance_samples==0:errors.append("No walking foot-contact samples")
 if max_stance_error>.03:errors.append("Stance contact exceeds 30mm")
 if max_contact>.025:errors.append("Lantern handle contact exceeds 25mm")
 print("FIRE LIVE RESULT ","PASS" if errors.is_empty() else "FAIL"," frames=",frames," max_stance_error=",max_stance_error," stance_samples=",stance_samples," max_lantern_contact=",max_contact," max_lantern_reach=",max_reach_error," errors=",errors)
 world.queue_free();await process_frame;await preload("res://tools/test_audio_cleanup.gd").finish(self,0 if errors.is_empty() else 1)
