extends Node
## Additional requests share the job ledger; entrusted goods are never spending money.
var job_id := "family_cart"
var pickup_id := "passenger"
var goal_id := "family_home"
var manager: Node3D
var passenger: Node3D
var cart: Node3D
var borrowed: Node3D
var call_cooldown := 0.0
const TRANSFER_SECONDS := 2.4
var leg_solver: Node
var transfer_feet: Dictionary = {}
var transfer := ""
var transfer_time := 0.0
var transfer_hip := Vector3.ZERO
var transfer_yaw := 0.0
var exit_ground := Vector3.ZERO
var transfer_side := 1.0
var seated := false
var home: Vector3

func configure(owner: Node3D) -> void:
	manager = owner
	owner._person("port_cargo","PortWarehouseKeeper",Vector3(-189,2.8,680),"dock_porter")
	owner._person("medicine_request","WorriedNeighbour",Vector3(-396,7.2,327),"village_woman")
	owner._person("medicine_supply","MarketMedicineDispenser",Vector3(-387,7.2,327),"village_farmer")
	owner._person("money_sender","StrandedMoneySender",Vector3(-375,7.2,322),"village_farmer")
	owner._person("money_receiver","PortFamilyReceiver",Vector3(-186,2.8,674),"boatman")
	owner._person("passenger","WaitingBrother",Vector3(-246,7.2,212),"errand_passenger")
	owner._person("family_home","FamilyAtHome",Vector3(-375,7.2,307),"village_woman")
	for id in ["port_cargo","medicine_request","medicine_supply","money_sender","money_receiver","passenger","family_home"]:
		var target: Node3D = owner.targets[id]
		var p: Vector3 = target.person.global_position
		var ground: float = owner.get_parent().layout.height(p.x,p.z)
		# Port quay is a raised built surface. Ray finds its actual support.
		var query := PhysicsRayQueryParameters3D.create(Vector3(p.x,ground+8,p.z),Vector3(p.x,ground-4,p.z),1)
		var exclusions: Array[RID] = []
		for item in owner.targets.values():
			exclusions.append(item.get_rid())
			if item.person != null: exclusions.append(item.person.get_node("BodyCollider").get_rid())
		query.exclude = exclusions
		var hit := owner.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): ground = hit.position.y
		target.person.global_position.y = ground
		owner.floor_levels[id] = ground
	passenger = owner.targets.passenger.person
	home = passenger.global_position
	borrowed = preload("res://vehicles/horse_cart_candidate.gd").new()
	borrowed.name = "EmployerPassengerCart"
	borrowed.position = Vector3(-252,owner.get_parent().layout.height(-252,210),210)
	borrowed.rotation.y = PI
	owner.add_child(borrowed)
	leg_solver = preload("res://world/suryagarh/settlements/household_resident_journey.gd").new()
	leg_solver.actor = passenger; add_child(leg_solver)
	borrowed.add_to_group("live_travel_carts")

func use_endpoint(id: String) -> bool:
	if manager.active != job_id: return false
	if passenger.get_meta("dead",false):
		manager.cancel(); manager._message("The passenger cannot travel. No wage paid."); return true
	if not transfer.is_empty(): return true
	var stage: String = manager.stages.get(job_id,"")
	if id == pickup_id and stage == "accepted":
		for handle in get_tree().get_nodes_in_group("cart_boarding_handles"):
			var vehicle: Node3D = handle.get_parent()
			if not vehicle.get("seat_sockets").has("PassengerSeat"): continue
			if vehicle.global_position.distance_to(passenger.global_position) > 5.0: continue
			if vehicle.boarding.role == "passenger" and vehicle.boarding.rider != null: continue
			if absf(vehicle.boarding.speed) > .15 or vehicle.boarding.transition != "": continue
			if vehicle.has_meta("errand_passenger") or vehicle.boarding.travel.payer != null: continue
			cart = vehicle; seated = true
			passenger.set_process(false); passenger.set("foot_plant_enabled",false)
			passenger.get("animation_tree").active = false
			passenger.get_node("BodyCollider").collision_layer = 0
			manager.targets[pickup_id].collision_layer = 0
			cart.set_meta("errand_passenger",passenger)
			manager._clear_job_waypoint(); manager.stages[job_id] = "carrying"
			_begin_transfer("boarding")
			manager._message("Wait while your passenger boards the cart.")
			return true
		manager._message("Bring a passenger cart beside the traveller and stop.")
		return true
	if id == goal_id and stage == "carrying":
		if not seated or not is_instance_valid(cart):
			manager.stages[job_id] = "accepted"
			manager._message("Collect the passenger by cart first."); return true
		if cart.global_position.distance_to(manager.targets[goal_id].global_position) > 7.0 or absf(cart.boarding.speed) > .15:
			manager._message("Bring the passenger cart beside the destination and stop before unloading."); return true
		var ground := _clear_exit()
		if not ground.is_finite():
			manager._message("Park with clear ground beside the passenger step."); return true
		exit_ground = ground; _begin_transfer("exiting")
		manager._message("Wait while your passenger steps down."); return true
	return false

func release_passenger(at: Vector3 = Vector3.INF) -> void:
	if not is_instance_valid(passenger): return
	if is_instance_valid(cart):
		cart.remove_meta("errand_passenger"); cart.remove_meta("errand_transfer")
	transfer = ""; transfer_time = 0.0
	seated = false; cart = null
	passenger.global_position = home if not at.is_finite() else at
	passenger.remove_meta("seated_coach")
	passenger.set_process(true); passenger.set("foot_plant_enabled",true)
	passenger.get("animation_tree").active = true
	preload("res://world/suryagarh/errands/passenger_contact.gd").cloth(passenger,0.0)
	passenger.set_grip("r",0.0)
	passenger.get_node("BodyCollider").collision_layer = 1
	if manager.targets.has(pickup_id): manager.targets[pickup_id].collision_layer = 1

func _physics_process(delta: float) -> void:
	if manager == null or get_tree().paused: return
	if seated and passenger.get_meta("dead",false):
		manager.cancel(); manager._message("The passenger cannot travel. No wage paid."); return
	if manager.active == job_id:
		var mounting = manager.player.get_meta("mounted_vehicle") if manager.player.has_meta("mounted_vehicle") else null
		if mounting != null and mounting.role == "driver" and absf(mounting.speed) < .15 and mounting.transition == "":
			if manager.stages[job_id] == "accepted" and manager._near(pickup_id):
				use_endpoint(pickup_id)
			elif manager.stages[job_id] == "carrying" and manager._near(goal_id):
				use_endpoint(goal_id)
	if seated and is_instance_valid(cart):
		if transfer.is_empty(): _seat_passenger(delta)
		else: _advance_transfer(delta)
	# A resumed escort returns to the pickup instead of inventing a seated cart.
	if manager.active == job_id and manager.stages[job_id] == "carrying" and not seated:
		manager.stages[job_id] = "accepted"
	call_cooldown = maxf(0,call_cooldown-delta)
	if call_cooldown > 0 or not manager.active.is_empty() or manager.player.get_meta("map_open",false): return
	for request in [["medicine_request","urgent_medicine","Please help! My neighbour needs medicine."],["money_sender","emergency_money","Can someone take money to my family at the port?"],["road","road_meal","Please, traveller! Could you spare some food?"]]:
		if not manager.job_available(request[1]): continue
		var person: Node3D = manager.targets[request[0]].person
		if person.get_meta("dead",false) or person.global_position.distance_to(manager.player.global_position) > 16: continue
		manager._message(request[2] + " — Speak to the person calling.")
		var voice := AudioStreamPlayer3D.new()
		var clip: String = {"medicine_request":"medicine", "money_sender":"money", "road":"food"}[request[0]]
		voice.stream = (load("res://audio/errands/"+clip+"_help.wav") as AudioStreamWAV)
		voice.max_distance = 22; voice.unit_size = 7; voice.volume_db = 3
		person.add_child(voice); voice.finished.connect(voice.queue_free); voice.play()
		call_cooldown = 45.0
		break

func _seat_passenger(delta: float, amount: float = 1.0, hip_target: Vector3 = Vector3.INF) -> void:
	# Keep the pose owned by the seated passenger until disembarkation.
	var skeleton: Skeleton3D = passenger.get("_skeleton")
	var bases: Dictionary = passenger.get("_base_rotations")
	var axes: Dictionary = passenger.get("_pitch_axes")
	for side in ["l","r"]:
		passenger.set_grip(side,0.0)
		for limb in ["upperarm_","lowerarm_","hand_"]:
			var bone_name: String = limb+side
			var bone_index := skeleton.find_bone(bone_name)
			if bone_index >= 0: skeleton.set_bone_pose_rotation(bone_index,bases.get(bone_name,Quaternion.IDENTITY))
		for entry in [["thigh_",-1.5],["calf_",1.5]]:
			var bone: String = entry[0]+side
			var index := skeleton.find_bone(bone)
			if index >= 0: skeleton.set_bone_pose_rotation(index,bases[bone]*Quaternion(axes[bone],entry[1]*amount))
	preload("res://world/suryagarh/errands/passenger_contact.gd").cloth(passenger,amount)
	var socket: Node3D = cart.seat_sockets.PassengerSeat
	passenger.global_rotation.y = lerp_angle(transfer_yaw,socket.global_rotation.y+PI,amount) if not transfer.is_empty() else socket.global_rotation.y+PI
	var hip: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("pelvis")).origin)
	passenger.global_position += (socket.global_position if not hip_target.is_finite() else hip_target)-hip

func _vehicle_state(vehicle: Node3D) -> Dictionary:
	var p := vehicle.global_position
	return {"path":str(manager.get_parent().get_path_to(vehicle)),"position":[p.x,p.y,p.z],"heading":vehicle.rotation.y}

func export_trip() -> Dictionary:
	var result := {"borrowed":_vehicle_state(borrowed)}
	if seated and is_instance_valid(cart): result["occupied"] = _vehicle_state(cart)
	result["job"] = job_id
	return result

func _restore_vehicle(data: Dictionary, require_passenger: bool = true) -> Node3D:
	var path: String = str(data.get("path",""))
	if path.is_empty() or path.begins_with("/") or ".." in path: return null
	var vehicle := manager.get_parent().get_node_or_null(NodePath(path)) as Node3D
	if vehicle == null or vehicle.get("seat_sockets") == null or vehicle.get("boarding") == null: return null
	if require_passenger and not vehicle.get("seat_sockets").has("PassengerSeat"): return null
	var at = data.get("position",[])
	var heading = data.get("heading",0)
	if not at is Array or at.size() != 3 or not (heading is int or heading is float): return null
	for value in at:
		if not (value is int or value is float) or not is_finite(float(value)): return null
	if not is_finite(float(heading)): return null
	var position := Vector3(float(at[0]),float(at[1]),float(at[2]))
	if absf(position.x) > 2000 or absf(position.z) > 2000 or absf(position.y) > 200: return null
	vehicle.global_position = position; vehicle.rotation.y = float(heading)
	return vehicle

func restore_trip(data: Dictionary) -> void:
	if data.get("borrowed",{}) is Dictionary: _restore_vehicle(data.get("borrowed",{}))
	if manager.active != job_id or manager.stages.get(job_id,"") != "carrying": return
	var occupied = data.get("occupied",{})
	cart = _restore_vehicle(occupied) if occupied is Dictionary else null
	if cart == null or passenger.get_meta("dead",false):
		manager.stages[job_id] = "accepted"; cart = null; return
	seated = true
	passenger.set_process(false); passenger.set("foot_plant_enabled",false)
	passenger.get("animation_tree").active = false
	passenger.get_node("BodyCollider").collision_layer = 0
	manager.targets[pickup_id].collision_layer = 0
	cart.set_meta("errand_passenger",passenger)
	_seat_passenger(0)

func _begin_transfer(kind: String) -> void:
	transfer = kind; transfer_time = 0.0
	var skeleton: Skeleton3D = passenger.get("_skeleton")
	transfer_hip = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("pelvis")).origin)
	for side in ["l","r"]:
		transfer_feet[side] = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("foot_"+side)).origin)
	transfer_yaw = passenger.global_rotation.y
	transfer_side = -1.0 if cart.to_local(passenger.global_position).x < 0 else 1.0
	if kind == "exiting": transfer_side = -1.0 if cart.to_local(exit_ground).x < 0 else 1.0
	cart.boarding.speed = 0; cart.set_meta("errand_transfer",true)

func _advance_transfer(delta: float) -> void:
	transfer_time = minf(TRANSFER_SECONDS,transfer_time+delta)
	var u := transfer_time/TRANSFER_SECONDS
	var skeleton: Skeleton3D = passenger.get("_skeleton")
	var seat: Vector3 = cart.seat_sockets.PassengerSeat.global_position
	var step: Vector3 = cart.to_global(Vector3(transfer_side*1.12,1.48,1.50))
	var target: Vector3
	var amount: float
	if transfer == "boarding":
		target = transfer_hip.lerp(step,smoothstep(0,.5,u)) if u < .5 else step.lerp(seat,smoothstep(.5,1,u))
		amount = smoothstep(.55,1,u)
	else:
		var rest_hip: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("pelvis")).origin
		var standing_height: float = skeleton.to_global(rest_hip).y-passenger.global_position.y
		var standing_hip := exit_ground + Vector3.UP*standing_height
		target = transfer_hip.lerp(step,smoothstep(0,.5,u)) if u < .5 else step.lerp(standing_hip,smoothstep(.5,1,u))
		amount = 1.0-smoothstep(0,.45,u)
	_seat_passenger(delta,amount,target)
	for side in ["l","r"]:
		var offset: float = -.10 if side == "l" else .10
		var step_foot := cart.to_global(Vector3(transfer_side*1.12,.68,1.4+offset))
		var finish := cart.to_global(Vector3(.43+offset,1.185,2.02)) if transfer == "boarding" else exit_ground+Vector3(0,.08,offset)
		var lead: bool = side == "r"
		var swing := smoothstep(0,.43,u) if lead else smoothstep(.15,.5,u)
		var foot: Vector3 = transfer_feet[side].lerp(step_foot,swing)+Vector3.UP*sin(swing*PI)*.10
		if u > .5:
			swing = smoothstep(.5,.85,u) if lead else smoothstep(.65,1,u)
			foot = step_foot.lerp(finish,swing)+Vector3.UP*sin(swing*PI)*.10
		leg_solver._solve_leg(side,skeleton.to_local(foot))
	if u > .37 and u < .72:
		var weight := smoothstep(.37,.48,u)*(1.0-smoothstep(.58,.72,u))
		preload("res://world/suryagarh/errands/passenger_contact.gd").grip(passenger,cart,transfer_side,weight)
	if u >= 1:
		var completed := transfer
		transfer = ""; cart.remove_meta("errand_transfer")
		if completed == "exiting":
			release_passenger(exit_ground); manager._finish(job_id)
		else: manager._message("Your passenger is aboard. " + manager.objective(job_id))

func _clear_exit() -> Vector3:
	var space := manager.get_world_3d().direct_space_state
	var body: CollisionShape3D = passenger.get_node("BodyCollider/BodyShape")
	var excluded: Array[RID] = [passenger.get_node("BodyCollider").get_rid(),manager.targets[pickup_id].get_rid(),cart.boarding.collision_body.get_rid(),manager.player.get_rid()]
	for side in [1.0,-1.0]:
		var at := cart.to_global(Vector3(side*2.35,0,1.4))
		var ray := PhysicsRayQueryParameters3D.create(at+Vector3.UP*2,at-Vector3.UP*3,1,excluded)
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y < .7 or absf(hit.position.y-cart.global_position.y) > .35: continue
		at = hit.position + Vector3.UP*.02
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = body.shape; query.transform = body.global_transform
		query.transform.origin += at-passenger.global_position
		query.exclude = excluded; query.collision_mask = 1
		if space.intersect_shape(query,1).is_empty(): return at
	return Vector3.INF

func bind_passenger(request: String, pickup: String, goal: String) -> void:
	if seated: release_passenger()
	job_id=request; pickup_id=pickup; goal_id=goal
	passenger=manager.targets[pickup].person;home=passenger.global_position
	leg_solver.actor=passenger
