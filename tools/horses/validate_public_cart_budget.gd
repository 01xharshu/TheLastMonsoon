extends SceneTree
## Actual-world Medium-budget measurements and near/far passenger continuity.
var errors:Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(value:bool,message:String) -> void:
 if not value:errors.append(message);push_error(message)
func run() -> void:
 if DisplayServer.get_name()=="headless":
  push_error("Public cart budget check requires the native renderer");quit(1);return
 var saves:Node=root.get_node("SaveManager")
 saves.options.fullscreen=false;saves.options.graphics_quality=1;saves.options.vsync=false;saves.apply_options()
 root.size=Vector2i(1280,720)
 saves.start_new_game();await scene_changed
 for frame in 4:await process_frame
 var world:Node3D=current_scene
 var opening:Node=world.get_node("OpeningSequence")
 var skip:=InputEventKey.new();skip.keycode=KEY_ESCAPE;skip.pressed=true
 opening._input(skip)
 for frame in 2:await process_frame
 opening._input(skip)
 var start:=Time.get_ticks_msec()
 while opening.state!="done" and Time.get_ticks_msec()-start<180000:await process_frame
 check(opening.state=="done","Opening releases the real world")
 var player:Node3D=world.get_node("Player");player.set_physics_process(false)
 var cart:Node3D=world.get_node("LiveCarts/VillageBullockCart")
 var service:Node=cart.get_node("PublicPassengerService")
 check(service.viewer==player and service.clock==world.get_node("GameTimeSystem"),"Public service caches this world's player and clock")
 var camera:=Camera3D.new();world.add_child(camera);camera.current=true
 var samples:Array=[]
 for stage in ["near","remote","approach","cinematic_remote"]:
  var remote:bool=stage in ["remote","cinematic_remote"]
  cart.set_meta("opening_cart_passage",stage=="cinematic_remote")
  player.global_position=cart.global_position+Vector3(260 if remote else 5,0,0)
  camera.global_position=player.global_position+Vector3(0,3,5)
  camera.look_at(player.global_position+Vector3(0,1,-5))
  for frame in 8:await process_frame
  var before:int=service.passengers[0].pose_updates
  var timings:Array[float]=[]
  for frame in 48:
   var tick:=Time.get_ticks_usec();await process_frame
   timings.append(float(Time.get_ticks_usec()-tick)/1000.0)
  var journey:Node=service.passengers[0]
  var updates:int=journey.pose_updates-before
  check(updates>0,stage+": passenger retains active pose updates")
  check(is_equal_approx(journey.simulation_interval,.5 if stage=="remote" else 0.0),stage+": correct shared tier and immediate restore")
  check(journey.actor.body_collider.collision_layer==2,stage+": passenger collision retained")
  var pelvis:Vector3=journey.actor._skeleton.to_global(journey.actor._skeleton.get_bone_global_pose(journey.actor._skeleton.find_bone("pelvis")).origin)
  check(pelvis.distance_to(journey.socket.global_position+Vector3.UP*.11)<.02,stage+": seated contact follows moving cart")
  timings.sort()
  samples.append({"stage":stage,"pose_updates":updates,"interval":journey.simulation_interval,"median_ms":timings[timings.size()/2],"p95_ms":timings[int((timings.size()-1)*.95)],"viewport":str(root.size),"scale_3d":root.scaling_3d_scale,"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
 cart.remove_meta("opening_cart_passage")
 print("PUBLIC PASSENGER CART BUDGET ",JSON.stringify({"passed":errors.is_empty(),"errors":errors,"samples":samples,"note":"Whole-world diagnostic samples; no A/B speedup or 30-FPS acceptance claimed"}))
 await saves.quit_game(0 if errors.is_empty() else 1)
