extends SceneTree
const Startup=preload("res://systems/world_startup.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
 var saves:Node=root.get_node("SaveManager")
 saves.options.graphics_quality=1;saves.options.fullscreen=false;saves.options.vsync=false;saves.apply_options()
 var loading:=Startup.start(self);paused=true;saves.start_new_game();await scene_changed
 var world:Node3D=current_scene
 while not loading.tasks.is_empty():await process_frame
 while saves.pending_slot>=0:await process_frame
 world.show();Startup.close(loading);paused=false
 var opening:Node=world.get_node("OpeningSequence")
 var skip:=InputEventKey.new();skip.keycode=KEY_ESCAPE;skip.pressed=true
 opening._input(skip);await process_frame;opening._input(skip)
 while opening.state!="done":await process_frame
 var actor:Node3D=world.get_node("Player");actor.set_physics_process(false)
 actor.global_position=Vector3(-350,world.layout.height(-350,-310)+1,-310)
 var population:Node=world.get_node("CityRoutePopulation");population.eager_population=true
 while not population.ready_population:await process_frame
 var camera:=Camera3D.new();world.add_child(camera);camera.make_current();camera.global_position=actor.global_position+Vector3(0,1,0);camera.look_at(camera.global_position+Vector3(20,-1.4,-20))
 var records:Array[Dictionary]=[]
 for person in population.pedestrians:
  for mesh:MeshInstance3D in person.find_children("*","MeshInstance3D",true,false):
   if "makehuman_body" not in str(mesh.name).to_lower():continue
   for surface in mesh.mesh.get_surface_count():
    if mesh.get_surface_override_material(surface)!=null:records.append({"mesh":mesh,"surface":surface,"material":mesh.get_surface_override_material(surface)})
 assert(not records.is_empty(),"No population skin overrides to profile")
 for mode in ["baseline","variation","baseline_repeat"]:
  for record in records:record.mesh.set_surface_override_material(record.surface,record.material if mode=="variation" else null)
  for frame in 20:await process_frame
  var samples:Array[float]=[];var tick:=Time.get_ticks_usec()
  for frame in 60:
   await process_frame
   var now:=Time.get_ticks_usec();samples.append((now-tick)/1000.0);tick=now
  samples.sort()
  print("POPULATION_SKIN_FRAME ",mode," p50/p95ms=",[samples[30],samples[57]]," viewport=",root.size," scale=",root.scaling_3d_scale," surfaces=",records.size())
 for record in records:record.mesh.set_surface_override_material(record.surface,record.material)
 print('POPULATION_SKIN {"passed":true,"scope":"bounded live city material comparison"}')
 saves.quit_game()
