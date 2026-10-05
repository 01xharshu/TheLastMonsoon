extends SceneTree
const SAMPLES := 600
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
 var world := Node3D.new()
 root.add_child(world)
 current_scene = world
 var clock := Node.new()
 clock.name = "GameTimeSystem"
 clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
 world.add_child(clock)
 var camera := Camera3D.new()
 world.add_child(camera)
 camera.make_current()
 var results: Array = []
 for kind in 3:
  var cart: Node3D = load("res://vehicles/family_carriage_candidate.gd" if kind == 2 else "res://vehicles/horse_cart_candidate.gd").new()
  if kind < 2: cart.variant = kind
  world.add_child(cart)
  await process_frame
  var reins: Node3D = cart.get_node("FlexibleReins")
  reins.set_process(false)
  for distance in [20.0,120.0,260.0]:
   camera.position = Vector3(0,0,distance)
   var baseline_times: Array = []
   var baseline_total_us := 0.0
   if "--after" in OS.get_cmdline_user_args():
    reins.distance_lod_enabled = false
    for i in 30: reins._process(1.0/60.0)
    for i in SAMPLES:
     var start := Time.get_ticks_usec()
     reins._process(1.0/60.0)
     var cost := Time.get_ticks_usec()-start
     baseline_times.append(cost)
     baseline_total_us += cost
    baseline_times.sort()
   reins.distance_lod_enabled = "--after" in OS.get_cmdline_user_args()
   for i in 30: reins._process(1.0/60.0)
   var times: Array = []
   var before: int = int(reins.get("detail_updates")) if "--after" in OS.get_cmdline_user_args() else 0
   for i in SAMPLES:
    var start := Time.get_ticks_usec()
    reins._process(1.0/60.0)
    times.append(Time.get_ticks_usec()-start)
   var total_us := 0.0
   for cost in times: total_us += float(cost)
   times.sort()
   var updates: int = int(reins.get("detail_updates"))-before if "--after" in OS.get_cmdline_user_args() else SAMPLES
   if "--after" in OS.get_cmdline_user_args():
    assert(updates == SAMPLES if distance == 20.0 else (updates > 50 and updates < 120 if distance == 120.0 else updates == 0),"Rein LOD update budget failed")
    assert(reins.visible == (distance < 180.0),"Distant rein visibility failed")
   results.append({"variant":kind,"distance_m":distance,"samples":SAMPLES,"rein_strips":reins.reins.size(),"detail_updates":updates,"baseline_mean_us":baseline_total_us/SAMPLES if not baseline_times.is_empty() else null,"baseline_p50_us":baseline_times[SAMPLES/2] if not baseline_times.is_empty() else null,"mean_us":total_us/SAMPLES,"p50_us":times[SAMPLES/2],"p95_us":times[int(SAMPLES*.95)]})
  if kind == 2 and "--after" in OS.get_cmdline_user_args():
   var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
   world.add_child(actor)
   actor.set_physics_process(false)
   camera.position = Vector3(0,0,260)
   camera.make_current()
   for i in 30: reins._process(1.0/60.0)
   assert(not reins.visible)
   cart.boarding.rider = actor
   cart.boarding.role = "passenger"
   var before_occupied: int = reins.detail_updates
   for i in 30: reins._process(1.0/60.0)
   assert(reins.visible and reins.detail_updates-before_occupied == 30,"Occupied distant cart lost full rein contact updates")
   for entry in reins.reins:
    assert(entry.points[0].distance_to(entry.rendered_pins[0]) < .0001)
    assert(entry.points[-1].distance_to(entry.rendered_pins[-1]) < .0001)
   cart.boarding.rider = null
   actor.queue_free()
   await process_frame
  camera.position = Vector3(0,0,20)
  for i in 30: reins._process(1.0/60.0)
  assert(reins.visible,"Near rein detail did not resume")
  cart.queue_free()
  await process_frame
 var report := {"status":"PASS","scope":"Direct CPU timing of flexible rein update; excludes frame/render/horse/driver/physics costs","phase":"after" if "--after" in OS.get_cmdline_user_args() else "baseline","results":results}
 var target := "res://docs/world/cart_visual_profile_"+str(report.phase)+".json"
 FileAccess.open(target,FileAccess.WRITE).store_string(JSON.stringify(report," "))
 print("CART VISUAL PROFILE ",JSON.stringify(report))
 quit()
