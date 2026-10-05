extends SceneTree
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
 var actor:Node3D=load("res://characters/npcs/british/british_npc_actor.gd").new()
 actor.movement_profile=&"female";actor.movement_enabled=false;actor.foot_plant_enabled=false
 actor.add_child(load("res://characters/npcs/british/official_woman.glb").instantiate())
 root.add_child(actor);actor.set_process(false)
 var travel:Node=load("res://world/suryagarh/settlements/household_coach_travel.gd").new()
 root.add_child(travel);travel.set_physics_process(false)
 travel._passenger_cloth(actor,true)
 var uncached:Array[float]=[];var cached:Array[float]=[]
 for trial in 5:
  var start:=Time.get_ticks_usec()
  for sample in 2000:
   actor.remove_meta("coach_cloth_meshes");travel._passenger_cloth(actor,true)
  uncached.append((Time.get_ticks_usec()-start)/2000.0)
  start=Time.get_ticks_usec()
  for sample in 2000:travel._passenger_cloth(actor,true)
  cached.append((Time.get_ticks_usec()-start)/2000.0)
 uncached.sort();cached.sort()
 travel._passenger_cloth(actor,false)
 var dress:MeshInstance3D=actor.get_meta("coach_dress")
 var passed:bool=not dress.visible and actor.get_meta("coach_cloth_meshes").size()==2
 for part in actor.get_meta("coach_cloth_meshes"):passed=passed and part.visible
 var report:={"passed":passed,"uncached_median_us":uncached[2],"cached_median_us":cached[2],"garment_parts":actor.get_meta("coach_cloth_meshes").size(),"scope":"actual imported official woman; garment lookup microbenchmark only, not whole-world FPS or contact approval"}
 FileAccess.open("res://docs/world/household_cloth_profile.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("HOUSEHOLD_CLOTH_PROFILE ",JSON.stringify(report));quit(0 if passed else 1)
