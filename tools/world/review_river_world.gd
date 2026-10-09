extends SceneTree
## Native world listening/motion route. Captures only to a caller-owned temp directory.
const Layout=preload('res://world/suryagarh/landscape_layout.gd')
func _initialize() -> void:call_deferred('run')
func run() -> void:
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 DisplayServer.window_set_size(Vector2i(960,540));root.content_scale_size=Vector2i(960,540)
 var world: Node3D=load('res://world/suryagarh/suryagarh_world.tscn').instantiate()
 root.add_child(world);current_scene=world
 for i in 3:await physics_frame
 var player: CharacterBody3D=world.get_node('Player');player.set_physics_process(false)
 player.get_node('UI').hide();world.get_node('LandscapeUI').hide()
 var music: AudioStreamPlayer=world.get_node_or_null('BackgroundMusic')
 if music!=null:music.stop()
 var clock: Node=world.get_node('GameTimeSystem')
 clock.advance_minutes(fposmod(600-fmod(clock.total_game_minutes,1440),1440))
 var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.far=1800;camera.fov=65
 var layout:=Layout.new();var out: String=''
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--output='):out=arg.trim_prefix('--output=')
 var river: Node=world.get_node('RiverDynamics')
 assert(river.materials[0].get_shader_parameter('exclude_moored_ship'))
 print('PASS world river preserves port hull exclusion')
 for z in [235.0,650.0,-500.0]:
  var bank:=layout.river_x(z)-layout.river_width(z)-24
  camera.position=Vector3(bank,maxf(3.2,layout.height(bank,z+12)+1.7),z+12)
  camera.look_at(Vector3(bank+40,-.1,z-12))
  player.global_position=Vector3(bank,layout.height(bank,z)+1,z)
  # Let the freshly visible terrain/materials warm before timing live motion.
  print('WORLD RIVER WARMUP '+str(z))
  for i in 30:await process_frame
  var started:=Time.get_ticks_msec();var frames:=0
  while (Time.get_ticks_msec()-started<4000 or frames<30) and Time.get_ticks_msec()-started<20000:
   await process_frame;frames+=1
  await RenderingServer.frame_post_draw
  if out!='':
   var capture:=root.get_texture().get_image();capture.resize(960,540);capture.save_png(out+'/river_'+str(int(z))+'.png')
  print('WORLD RIVER REACH '+str(z)+' | seconds '+str((Time.get_ticks_msec()-started)/1000.0)+' | frames '+str(frames))
  if frames<30:
   print('NATIVE RIVER WORLD ROUTE: FAIL | insufficient frames')
   preload('res://tools/test_audio_cleanup.gd').stop(root)
   quit(1);return
 print('NATIVE RIVER WORLD ROUTE: PASS')
 preload('res://tools/test_audio_cleanup.gd').stop(root);await preload('res://tools/test_audio_cleanup.gd').settle(self)
 quit()
