extends SceneTree
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
 var world:=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
 root.add_child(world);current_scene=world
 for frame in 8:await physics_frame
 for coach in get_nodes_in_group("household_coach"):
  var travel:=coach.get_node("HouseholdTravel");travel.set_physics_process(false)
  for lean in [-.4,-.2,0.0,.2,.4,.6]:
   travel.driver_lean=lean;travel.step(.01)
   print("CONTACT_SWEEP ",coach.name," ",lean," ",travel.driver.get_meta("hand_contact_l")," ",travel.driver.get_meta("hand_contact_r"))
 quit()
