extends SceneTree
## Current drape cost probe; prints results and retains no test output.
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
 var actor:Node3D=load("res://characters/npcs/british/british_npc_actor.gd").new()
 actor.movement_profile=&"female";actor.movement_enabled=false;actor.foot_plant_enabled=false
 actor.add_child(load("res://characters/npcs/british/official_woman.glb").instantiate())
 root.add_child(actor);actor.set_process(false)
 var drape:Node=load("res://characters/npcs/households/household_drape.gd").new();actor.add_child(drape)
 if not drape.configure(actor):quit(1);return
 var started:=Time.get_ticks_usec()
 for sample in 2000:drape.update_pose()
 print("UNCHANGED_DRAPE_MEAN_US ",(Time.get_ticks_usec()-started)/2000.0," rebuilds ",drape.rebuilds)
 quit(0 if drape.rebuilds==1 else 1)
