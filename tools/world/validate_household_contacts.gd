extends SceneTree
## Contact-only regression across changing vehicle headings and live staff poses.
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
 var world:Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
 root.add_child(world);current_scene=world
 for frame in 8:await physics_frame
 var worst:=0.0;var samples:=0
 for coach in get_nodes_in_group("household_coach"):
  var travel:Node=coach.get_node("HouseholdTravel");travel.set_physics_process(false)
  for yaw in [0.0,.7,1.4,2.1,2.8]:
   coach.rotation.y=yaw;travel.step(.01)
   for side in ["l","r"]:
    worst=maxf(worst,travel.driver.get_meta("hand_contact_"+side));samples+=1
 for frame in 90:
  await process_frame
  for actor in get_nodes_in_group("household_staff"):
   if actor.get("household_job")!="WaterBearer":continue
   for side in ["l","r"]:
    worst=maxf(worst,actor.get_meta("hand_contact_"+side));samples+=1
 var report:={"passed":worst<.015,"palm_target_samples":samples,"max_error_m":worst,"limit_m":.015,"scope":"bone-derived palm targets; visible finger grip and cloth require separate rendered review"}
 FileAccess.open("res://docs/world/household_contacts_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("HOUSEHOLD_CONTACTS ",JSON.stringify(report))
 world.queue_free();await process_frame
 quit(0 if report.passed else 1)
