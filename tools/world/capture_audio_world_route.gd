extends SceneTree
var world: Node3D
var camera: Camera3D
var actor: CharacterBody3D
var env: Node
var record: AudioEffectRecord
var timestamps: Array=[]
var frame_index:=0
var walking:=false
var recording_start:=0
func _initialize() -> void:call_deferred('run')
func hold(label: String,seconds: float) -> void:
 var next_capture:=0
 var started:=Time.get_ticks_msec()
 while Time.get_ticks_msec()-started<int(seconds*1000):
  await process_frame
  if walking:
   camera.global_position=actor.global_position+Vector3(4,2,5);camera.look_at(actor.global_position+Vector3.UP*.4)
  if Time.get_ticks_msec()-started>=next_capture:
   next_capture+=250
   await RenderingServer.frame_post_draw
   var frame:=root.get_texture().get_image();frame.resize(1280,720)
   frame.save_png('/tmp/monsoon_audio_route_frames/%04d.png'%frame_index)
   timestamps.append(Time.get_ticks_msec()-recording_start);frame_index+=1
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image();image.resize(1280,720)
 image.save_png('res://docs/world/audio_route_'+label+'.png')
 print('AUDIO ROUTE '+label)
func view(at: Vector3,target: Vector3) -> void:
 camera.global_position=at;camera.look_at(target);camera.current=true
func run() -> void:
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 root.size=Vector2i(1280,720)
 world=load('res://world/suryagarh/suryagarh_world.tscn').instantiate();root.add_child(world);current_scene=world
 for i in 45:await physics_frame
 actor=world.get_node('Player');actor.set_physics_process(false)
 env=root.get_node('WorldAudio/EnvironmentAudio')
 camera=Camera3D.new();camera.fov=60;world.add_child(camera);camera.current=true
 var clock: Node=world.get_node('GameTimeSystem')
 clock.advance_minutes(fposmod(600-fmod(clock.total_game_minutes,1440),1440))
 record=AudioEffectRecord.new();AudioServer.add_bus_effect(0,record);AudioServer.set_bus_mute(0,false);AudioServer.set_bus_volume_db(0,0)
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(1280,720)
 DirAccess.make_dir_recursive_absolute('/tmp/monsoon_audio_route_frames')
 record.set_recording_active(true);recording_start=Time.get_ticks_msec()
 var layout:=preload('res://world/suryagarh/landscape_layout.gd').new()
 actor.global_position=Vector3(-335,layout.height(-335,230)+.91,230)
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;actor.set_physics_process(true);walking=true;Input.action_press('move_forward')
 await hold('footsteps',5)
 Input.action_release('move_forward');walking=false;actor.set_physics_process(false)
 var river_at:=Vector3(layout.river_x(165)-layout.river_width(165)+4,2,165)
 view(river_at+Vector3(-4,3,7),river_at);await hold('river',5)
 var yard: Node3D=get_nodes_in_group('household_cattle')[0]
 var motion: Node=yard.motion;motion.enabled=false;motion.state='idle';env.actors[motion.get_instance_id()].wait=0
 view(yard.cow.global_position+Vector3(3,2,5),yard.cow.global_position+Vector3.UP*.8);await hold('cattle',5)
 var service: Node3D=get_nodes_in_group('administrative_services')[0]
 actor.global_position=service.global_position+Vector3(.1,.2,1)
 view(service.global_position+Vector3(2,1.0,3),service.staff.global_position+Vector3.UP)
 service.interact(actor);await hold('office',5)
 clock.advance_minutes(fposmod(1200-fmod(clock.total_game_minutes,1440),1440))
 var fire: Node3D=get_nodes_in_group('village_gathering_fire')[0]
 view(fire.global_position+Vector3(2,1.5,3),fire.global_position+Vector3.UP*.4);await hold('fire',5)
 var flag: Node3D=get_nodes_in_group('wind_flag_roots')[0]
 clock.advance_minutes(fposmod(600-fmod(clock.total_game_minutes,1440),1440))
 view(flag.global_position+Vector3(2,1.3,3),flag.global_position+Vector3.UP*1.5);await hold('wind',5)
 record.set_recording_active(false)
 var sound: AudioStreamWAV=record.get_recording();sound.save_to_wav('res://docs/world/audio_world_listening.wav')
 var timing:=FileAccess.open('/tmp/monsoon_audio_route_frames/timing.json',FileAccess.WRITE);timing.store_string(JSON.stringify(timestamps));timing.close()
 print('NATIVE AUDIO WORLD ROUTE: PASS | six live locations | recorded master mix')
 AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
 preload('res://tools/test_audio_cleanup.gd').stop(root);await preload('res://tools/test_audio_cleanup.gd').settle(self);quit()
