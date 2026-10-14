extends SceneTree
## Native expanded-world frames at Medium; stdout only, no whole-game FPS approval.
const Layout=preload("res://world/suryagarh/landscape_layout.gd")
func _initialize() -> void:call_deferred("run")
func percentile(values:Array[float],fraction:float) -> float:
 var sorted:=values.duplicate();sorted.sort()
 return sorted[clampi(int(sorted.size()*fraction),0,sorted.size()-1)]
func run() -> void:
 if DisplayServer.get_name()=="headless":push_error("Native renderer required");quit(2);return
 var saves:Node=root.get_node("SaveManager")
 saves.options.graphics_quality=1;saves.options.fullscreen=false;saves.options.vsync=false;saves.apply_options()
 saves.start_new_game();await scene_changed
 for frame in 4:await process_frame
 var world:Node3D=current_scene
 var opening:Node=world.get_node("OpeningSequence")
 var skip:=InputEventKey.new();skip.keycode=KEY_ESCAPE;skip.pressed=true
 opening._input(skip)
 for frame in 2:await process_frame
 opening._input(skip)
 while opening.state!="done":await process_frame
 var player:Node3D=world.get_node("Player");player.set_physics_process(false)
 var clock:Node=world.get_node("GameTimeSystem")
 clock.current_hour=10;clock.total_game_minutes=600;clock.clock_paused=true;clock._update_readable_time(true)
 var population:Node=world.get_node("CityRoutePopulation")
 var camera:=Camera3D.new();world.add_child(camera);camera.make_current()
 var layout:=Layout.new();var rid:=root.get_viewport_rid()
 RenderingServer.viewport_set_measure_render_time(rid,true)
 for row in [["western_wilderness",Vector2(-1100,-590)],["northern_valley",Vector2(-480,-1110)],["eastern_pursuit",Vector2(1090,-520)],["central_city_control",Vector2(-350,-310)]]:
  var point:Vector2=row[1];player.global_position=Vector3(point.x,layout.height(point.x,point.y)+.1,point.y)
  camera.global_position=player.global_position+Vector3(8,3,10);camera.look_at(player.global_position+Vector3.UP)
  # Finish the normal nearby spawn queue before measuring an inhabited region.
  var preparation_start:=Time.get_ticks_msec()
  while population.pending.any(func(record:Dictionary)->bool:return record.kind!="person" or Vector2(record.phase.point).distance_squared_to(point)<population.PREPARE_RADIUS_SQUARED):
   await process_frame
   if Time.get_ticks_msec()-preparation_start>60000:
    push_error("Expanded budget neighbourhood preparation timed out: "+str(row[0]))
    saves.quit_game(1);return
  for frame in 80:await process_frame
  var frames:Array[float]=[];var gpu:Array[float]=[];var prior:=Time.get_ticks_usec()
  for frame in 120:
   await process_frame
   var now:=Time.get_ticks_usec();frames.append(float(now-prior)/1000);prior=now
   gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
  print("CONSIGNMENT EXPANSION BUDGET ",JSON.stringify({"area":row[0],"frame_p50_ms":percentile(frames,.5),"frame_p95_ms":percentile(frames,.95),"gpu_p50_ms":percentile(gpu,.5),"window":str(root.size),"render_scale":root.scaling_3d_scale,"actual_3d_size":str(Vector2(root.size)*root.scaling_3d_scale),"display_window":str(DisplayServer.window_get_size()),"instantiated_walkers":population.pedestrians.size(),"pending_records":population.pending.size(),"patrols":population.patrols.size(),"carts":population.carts.size(),"scope":"actual populated expanded world at Medium; 120frames perregion; not whole-game FPS approval"}))
 print("CONSIGNMENT EXPANSION BUDGET: SAMPLED")
 saves.quit_game()
