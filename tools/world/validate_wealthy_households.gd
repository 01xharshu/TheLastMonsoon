extends SceneTree
var errors:Array[String]=[]
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var world:=load("res://world/suryagarh/suryagarh_world.tscn").instantiate() as Node3D
	root.add_child(world);current_scene=world
	world.get_node("Player").set_physics_process(false)
	for i in 6:await physics_frame
	var households:=get_nodes_in_group("wealthy_household")
	var staff:=get_nodes_in_group("household_staff")
	var residents:=get_nodes_in_group("household_resident")
	var coaches:=get_nodes_in_group("household_coach")
	if households.size()!=3 or staff.size()!=9 or residents.size()!=4 or coaches.size()!=3:
		errors.append("household population/coach count mismatch")
	# Clear physical entrances into the two new homes.
	var entrances:=0
	for name in ["MerchantHousehold","BritishHousehold"]:
		var home:=world.get_node("WealthyHouseholds/"+name) as Node3D
		var probe:=CharacterBody3D.new();var shape:=CollisionShape3D.new()
		var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.8
		shape.shape=capsule;probe.add_child(shape);world.add_child(probe)
		probe.global_position=home.to_global(Vector3(0,1.15,11))
		await physics_frame
		var hit:=probe.move_and_collide(Vector3(0,0,-10))
		if hit!=null:errors.append(name+": entrance-to-reception blocked by "+str(hit.get_collider().get_path()))
		else:entrances+=1
		probe.queue_free();await physics_frame
	var graphs:Dictionary={}
	for actor in staff+residents:
		var tree:AnimationTree=actor.get("animation_tree")
		if tree==null or not tree.active:errors.append(str(actor.name)+": no active personal tree")
		else:graphs[tree.get_instance_id()]=true
	if graphs.size()!=13:errors.append("household actors do not have 13 independent trees")
	for coach in coaches:coach.get_node("HouseholdTravel").set_physics_process(false)
	# Two bounded household cycles, while physics consumes each moving body pose.
	var worst_contact:=0.0
	for frame in 4000:
		for coach in coaches:coach.get_node("HouseholdTravel").step(.1)
		await physics_frame
		for actor in staff:
			for side in ["l","r"]:
				if actor.has_meta("hand_contact_"+side):worst_contact=maxf(worst_contact,actor.get_meta("hand_contact_"+side))
	var journeys:Array=[]
	for coach in coaches:
		var travel:=coach.get_node("HouseholdTravel")
		if travel.completed_trips<1:errors.append(str(coach.name)+": no completed driveway round trip")
		journeys.append({"coach":str(coach.name),"round_trips":travel.completed_trips,"distance_m":travel.distance_travelled,"blocked_frames":travel.blocked_frames,"phase":travel.phase,"actions":travel.actions,"resident_actions":travel.journeys.map(func(j):return {"actor":str(j.actor.name),"visited":j.visited,"state":j.state,"blocked_frames":j.blocked_frames,"position":str(j.actor.global_position),"obstacle":j.last_obstacle})})
	var contacts:Array=[]
	for actor in staff:
		if actor.get("household_job") not in ["WaterBearer","Coachman"]:continue
		for side in ["l","r"]:
			var error:float=actor.get_meta("hand_contact_"+side,1.0)
			contacts.append({"actor":str(actor.name),"hand":side,"error_m":error})
			if error>.015:errors.append(str(actor.name)+": "+side+" palm contact exceeds 15 mm")
	if worst_contact>.015:errors.append("moving palm contact exceeds 15 mm")
	var report:={"passed":errors.is_empty(),"households":households.size(),"staff":staff.size(),"residents":residents.size(),"independent_trees":graphs.size(),"clear_new_home_entrances":entrances,"hand_contacts":contacts,"max_sampled_contact_error_m":worst_contact,"coaches":coaches.size(),"journeys":journeys,"errors":errors,"scope":"household walk/board/sit/office/home cycle; final rendered motion/contact approval remains separate"}
	FileAccess.open("res://docs/world/wealthy_households_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("HOUSEHOLDS_VALIDATION ",JSON.stringify(report))
	quit(0 if report.passed else 1)
