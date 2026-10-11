extends Node3D
## Adult MPFB rescue encounter and road patrols; sensing runs at 4 Hz per officer.
const Actor = preload("res://characters/npcs/households/household_npc_actor.gd")
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
var layout := Layout.new()
var player: CharacterBody3D
var peasant: Node3D
var aggressor: Node3D
var encounter_state := "waiting"
var encounter_age := 0.0
var strike_age := 0.0
var strike_hit := false
var awareness_timer := 0.0
var wanted := false
var wanted_level := 0
var crime_score := 0
var evidence: Array[Dictionary] = []
var last_known := Vector3.ZERO
var unseen_age := 0.0
var patrols: Array[Dictionary] = []
var station: Node3D
var escort: Dictionary = {}
var escape_press := 0.0
var ground_exclusions: Array[RID]=[]
var patrol_terrain:Dictionary={}
var profile_enabled:=false
var cost_samples: Array[float]=[]
var sense_ray_count:=0
var ground_query_count:=0
func _ready() -> void:
	process_priority=40
	player=get_parent().get_node("Player")
	station=get_parent().get_node("Settlement/DistrictPolice")
	add_to_group("police_crime_observers")
	call_deferred("build")

func spawn(label: String, path: String, at: Vector3, faction: String, mounted: bool=false) -> Node3D:
	var actor: Node3D = preload("res://combat/mounted_police_actor.gd").new() if mounted else preload("res://characters/npcs/thana/thana_officer.gd").new() if faction=="police" else Actor.new()
	actor.name=label;actor.position=at
	actor.movement_enabled=false
	actor.foot_plant_enabled=false
	actor.set_meta("combat_faction",faction)
	actor.set_meta("external_combat_motion",true)
	actor.add_child(load(path).instantiate())
	add_child(actor)
	ground_exclusions.append(actor.body_collider.get_rid())
	return actor

func build() -> void:
	ground_exclusions=[player.get_rid()]
	patrol_terrain=preload("res://world/suryagarh/tree_trunk_collision.gd").terrain_cache(self)
	for npc in get_tree().get_nodes_in_group("combat_actors"):
		if npc.body_collider!=null:ground_exclusions.append(npc.body_collider.get_rid())
	var origin:=ground(Vector3(321,0,151))
	peasant=spawn("RescuePeasant","res://characters/npcs/rescue_peasant.glb",origin+Vector3(1.5,0,0),"indian")
	peasant.set_meta("adult",true)
	aggressor=spawn("ArrogantPrivate","res://characters/npcs/british/private_man.glb",origin+Vector3(1.5,0,1.0),"british")
	aggressor.rotation.y=PI
	aggressor.set_meta("rescue_aggressor",true)
	for record in [{"id":"PoliceRoadPatrol","route":"police_to_compound","model":"burkundaz","mounted":true},{"id":"CivilLinesPatrol","route":"civil_lines_avenue","model":"daroga","mounted":true},{"id":"CantonmentPatrol","route":"cantonment_approach","model":"burkundaz"}]:
		var points:=PackedVector3Array()
		for p in Layout.ROUTES[record.route]:points.append(ground(Vector3(p.x,0,p.y)))
		var start_index: int=2 if record.id=="CantonmentPatrol" else 0
		var actor:=spawn(record.id,"res://characters/npcs/thana/%s_motion.glb"%record.model,points[start_index],"police",record.get("mounted",false))
		var mount: Node3D=null
		if record.get("mounted",false):mount=install_patrol_mount(actor,points[start_index])
		if record.id == "CantonmentPatrol":
			var firearm := preload("res://combat/climbing_firearm_attack.gd").new()
			firearm.name = "ClimbingFirearm"
			firearm.target = player
			actor.add_child(firearm)
		var marker:=Label3D.new();marker.name="AlertMarker";marker.text="!";marker.font_size=48
		marker.position.y=2.05;marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED;marker.modulate=Color(1,.55,.15);marker.visible=false
		actor.add_child(marker)
		patrols.append({"actor":actor,"points":points,"index":start_index+1,"step":1,"state":"patrol","sense":float(patrols.size())*.08,"attack_age":0.0,"hit":false,"marker":marker,"seen":false,"mount":mount,"horse":mount})

func install_patrol_mount(actor: Node3D, at: Vector3) -> Node3D:
	var horse:=preload("res://horses/police_patrol_horse.gd").new()
	horse.name=actor.name+"Horse";horse.position=at+Vector3.UP*.05
	add_child(horse);horse.officer=actor;horse.goal=at
	actor.patrol_mount=horse;actor.body_collider.collision_layer=8
	ground_exclusions.append(horse.get_rid())
	return horse

func ground(point: Vector3, terrain_only: bool = false) -> Vector3:
	ground_query_count+=1
	var query:=PhysicsRayQueryParameters3D.create(Vector3(point.x,layout.height(point.x,point.z)+4,point.z),Vector3(point.x,layout.height(point.x,point.z)-3,point.z),1)
	if terrain_only:query.collision_mask=preload("res://world/suryagarh/tree_trunk_collision.gd").TERRAIN_SUPPORT_LAYER
	query.exclude=ground_exclusions
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else Vector3(point.x,layout.height(point.x,point.z),point.z)

func report_assault(victim: Node3D, attacker: Node = null) -> void:
	if not is_instance_valid(victim): return
	if attacker == null: attacker= victim.get_meta("last_attacker",null)
	if attacker!=player or victim.get_meta("combat_faction","indian") not in ["british","police"]: return
	var kind: String = victim.get_meta("last_hit_kind","weapon")
	var severity := 10 if kind=="murder" and victim.get_meta("combat_faction","")=="police" else 5 if kind not in ["punch","kick","takedown"] else 2
	record_incident(kind,victim.global_position,incident_witnesses(victim.global_position,victim),severity)
	if victim==aggressor and encounter_state in ["beating","waiting","fallen"]:rescue()

func police_case_started(actor: Node) -> void:
	if actor==player and not wanted:
		var witnesses: Array[String]=["station_officer"]
		record_incident("police_report",player.global_position,witnesses,5)

func report_crime(actor: CharacterBody3D, offence: String, location: Vector3) -> void:
	if actor!=player or not location.is_finite() or offence not in ["theft","assault"]: return
	if actor.global_position.distance_to(location)>5.0: return
	record_incident(offence,location,incident_witnesses(location),5)

func has_pending_police_case(actor: Node) -> bool:
	return actor == player and (wanted or not escort.is_empty())

func complete_custody(actor: Node) -> void:
	if actor != player: return
	wanted = false
	return_recruited_police()
	crime_score=0;wanted_level=0
	unseen_age = 0.0
	for patrol in patrols:
		if patrol.state!="return":patrol.state = "patrol"
		patrol.seen = false
		patrol.attack_age = 0.0
		patrol.hit = false
		patrol.marker.visible = false

func recruit_visible_police() -> void:
	if not wanted: return
	for actor in get_tree().get_nodes_in_group("combat_actors"):
		if not actor is Node3D or actor.get_meta("combat_faction","")!="police": continue
		var already := false
		for patrol in patrols:
			if patrol.actor==actor: already=true;break
		if already or actor.get_meta("dead",false) or actor.get_meta("knocked_out",false) or actor.get_meta("city_custody",false): continue
		var coordinator: Node=station.get_node("ThanaStaff/ArrestCoordinator")
		if coordinator.phase!="idle" and coordinator.get("officer")==actor: continue
		if not visible_to(actor): continue
		var marker := Label3D.new();marker.text="!";marker.position.y=2.05;marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		actor.add_child(marker)
		var home: Vector3=actor.global_position
		patrols.append({"actor":actor,"points":PackedVector3Array([home,home]),"index":0,"step":1,"state":"pursue","sense":0.0,"attack_age":0.0,"hit":false,"marker":marker,"seen":true,"last_seen":player.global_position,"mount":null,"horse":null,"temporary":true,"movement":actor.movement_enabled,"external":actor.get_meta("external_combat_motion",false),"home":actor._home})
		actor.movement_enabled=false;actor.set_meta("external_combat_motion",true)

func return_recruited_police() -> void:
	for index in range(patrols.size()-1,-1,-1):
		var patrol: Dictionary=patrols[index]
		if not patrol.get("temporary",false): continue
		if is_instance_valid(patrol.actor) and not patrol.actor.get_meta("dead",false) and not patrol.actor.get_meta("knocked_out",false) and not patrol.actor.get_meta("city_custody",false):
			patrol.state="return";patrol.seen=false;patrol.marker.visible=false
			continue
		restore_recruited_duty(patrol)
		patrols.remove_at(index)

func restore_recruited_duty(patrol: Dictionary) -> void:
	if is_instance_valid(patrol.actor):
		patrol.actor.travel_speed=0.0
		patrol.actor.movement_enabled=patrol.movement
		patrol.actor.set_meta("external_combat_motion",patrol.external)
		patrol.actor._home=patrol.home
	if is_instance_valid(patrol.marker):patrol.marker.queue_free()
	if is_instance_valid(patrol.get("navigation")):patrol.navigation.queue_free()

func navigate_patrol(patrol: Dictionary, goal: Vector3, speed: float, delta: float) -> bool:
	if not is_instance_valid(patrol.get("navigation")):
		var navigation:=preload("res://combat/police_search_navigation.gd").new()
		patrol.actor.add_child(navigation);patrol["navigation"]=navigation
	return patrol.navigation.move(self,patrol.actor,goal,speed,delta)

func incident_witnesses(location: Vector3, victim: Node3D = null) -> Array[String]:
	var result: Array[String] = []
	for observer in get_tree().get_nodes_in_group("combat_actors"):
		if not observer is Node3D or observer.get_meta("dead",false) or observer.get_meta("knocked_out",false): continue
		if observer.global_position.distance_to(location)>30.0: continue
		if visible_to(observer): result.append(str(observer.get_path()))
	var recognized_police := false
	for patrol in patrols:
		if patrol.actor==victim and patrol.state=="pursue": recognized_police=true;break
	# A conscious victim knows who struck them even at close range behind their back.
	if is_instance_valid(victim) and not victim.get_meta("dead",false) and not victim.get_meta("knocked_out",false) and (victim.global_position.distance_to(player.global_position)<3.0 or recognized_police):
		var identity := str(victim.get_path())
		if identity not in result: result.append(identity)
	return result

func record_incident(kind: String, location: Vector3, witnesses: Array[String], severity: int) -> bool:
	if witnesses.is_empty(): return false
	crime_score=mini(25,crime_score+severity)
	wanted_level=clampi(ceili(float(crime_score)/5.0),1,5)
	wanted=true;unseen_age=0.0
	# Reports identify a location, but never give police the suspect's hidden live position.
	last_known=location
	evidence.append({"kind":kind,"location":location,"witnesses":witnesses,"time":Time.get_ticks_msec()})
	if evidence.size()>32: evidence.pop_front()
	player.inventory.message_requested.emit("Crime reported · %d star%s" % [wanted_level,"s" if wanted_level!=1 else ""])
	return true

func report_vehicle_theft(actor: CharacterBody3D, vehicle: Node3D, kind: String) -> void:
	if actor!=player or not is_instance_valid(vehicle) or vehicle.get_meta("restore_in_progress",false) or preload("res://systems/vehicle_permissions.gd").lawful(vehicle,actor): return
	var location := player.global_position
	if location.distance_to(vehicle.global_position)>7.0: return
	record_incident(kind,location,incident_witnesses(location),5)

func advance_wanted(delta: float, seen: bool) -> void:
	if not wanted or not escort.is_empty() or player.get_meta("detention_action","")!="": return
	unseen_age=0.0 if seen else unseen_age+delta
	if unseen_age>=15.0+float(wanted_level)*8.0:
		crime_score=maxi(0,crime_score-5)
		wanted_level=ceili(float(crime_score)/5.0)
		wanted=crime_score>0;unseen_age=0.0
		if not wanted:
			return_recruited_police()
			for patrol in patrols:
				if patrol.state!="return":patrol.state="patrol"
				patrol.seen=false;patrol.marker.visible=false

func rescue() -> void:
	encounter_state="rescued";encounter_age=0
	if is_instance_valid(peasant):
		peasant.set_meta("rescued",true)
	player.inventory.message_requested.emit("Peasant protected · Police alerted")

func visible_to(actor: Node3D) -> bool:
	sense_ray_count+=1
	return preload("res://systems/visual_perception.gd").sees(actor,player)

func move_actor(actor: Node3D, goal: Vector3, speed: float, delta: float) -> bool:
	var offset:=goal-actor.global_position;offset.y=0
	actor.set_meta("patrol_turning",false)
	if offset.length()<.13:
		actor.travel_speed=0;actor.set_meta("patrol_speed",0.0);return true
	var desired:float=atan2(offset.x,offset.z)
	var turn:float=absf(angle_difference(actor.global_rotation.y,desired))
	actor.global_rotation.y=rotate_toward(actor.global_rotation.y,desired,delta*3.2)
	if turn>1.05:
		actor.travel_speed=0;actor._turn_progress=clampf(1.0-turn/PI,0,1)
		actor.set_meta("patrol_turning",true);actor.set_meta("patrol_speed",0.0);return false
	var pace:float=move_toward(float(actor.get_meta("patrol_speed",0.0)),minf(speed,sqrt(offset.length()*2.0)),delta*1.8)
	actor.set_meta("patrol_speed",pace)
	var change:=offset.normalized()*minf(delta*pace,offset.length())
	var next:=ground(actor.global_position+change,actor.has_meta("population_route"))
	if absf(next.y-actor.global_position.y)>.3:actor.travel_speed=0;return false
	var query:=PhysicsShapeQueryParameters3D.new()
	query.margin=.002
	query.shape=actor.body_collider.get_node("BodyShape").shape
	query.transform=actor.body_collider.get_node("BodyShape").global_transform
	query.transform.origin=next+Vector3.UP*(actor.body_collider.get_node("BodyShape").position.y+.025)
	query.exclude=[actor.body_collider.get_rid()]
	query.collision_mask=1
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		# Survey a small curb before lifting; tall walls and occupants still block.
		var support:=ground(actor.global_position+change+offset.normalized()*.24,actor.has_meta("population_route"))
		if support.y<next.y or support.y-next.y>.16:actor.travel_speed=0;return false
		query.transform.origin.y+=.16
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():actor.travel_speed=0;return false
		next.y=support.y

	# Remote cadence still sweeps the whole capsule across thin obstacles.
	query.exclude=[actor.body_collider.get_rid()]
	query.exclude.append_array(patrol_terrain.get("rids",[]))
	query.transform=actor.body_collider.get_node("BodyShape").global_transform
	query.transform.origin+=Vector3.UP*.025;query.motion=next-actor.global_position
	if actor.get_world_3d().direct_space_state.cast_motion(query)[0]<.99:
		actor.travel_speed=0;return false
	actor.global_position=next;actor.travel_speed=change.length()/maxf(delta,.001)
	actor.body_collider.force_update_transform()
	return false

func _unhandled_input(event: InputEvent) -> void:
	if escort.is_empty() or escort.state!="capture":return
	if event.is_action_pressed("jump") and not event.is_echo():
		escape_press+=1
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if is_instance_valid(player) and player.get_meta("story_cinematic",false):return
	if not profile_enabled:_tick(delta);return
	var start:=Time.get_ticks_usec()
	_tick(delta)
	if cost_samples.size()<600:cost_samples.append(float(Time.get_ticks_usec()-start))

func update_rescue(delta: float) -> void:
	encounter_age+=delta
	if encounter_state=="waiting" and player.global_position.distance_to(peasant.global_position)<24:
		encounter_state="beating";encounter_age=0;strike_age=1.5
	if encounter_state=="beating":
		if aggressor.get_meta("dead",false) or aggressor.get_meta("knocked_out",false):rescue()
		else:
			strike_age+=delta
			if strike_age>=1.5:
				strike_age=0;strike_hit=false
				aggressor.combat_react("strike")
			if strike_age>=.28 and strike_age<=.60 and not strike_hit and strike_hits_actor(aggressor,peasant):
				strike_hit=true
				var vitality:=peasant.get_node("Vitality")
				vitality.receive_hit(28,aggressor,"abuse")
				if peasant.get_meta("knocked_out",false):encounter_state="fallen"
	if encounter_state=="fallen" and (aggressor.get_meta("dead",false) or aggressor.get_meta("knocked_out",false)):rescue()
	if encounter_state=="rescued" and encounter_age>3 and peasant.get_meta("knocked_out",false):
		peasant.set_meta("knocked_out",false);peasant.get_node("Vitality").health=75
		peasant.get_node("BodyCollider/BodyShape").disabled=false
		peasant.combat_react("rise")
		encounter_state="recovering"
	if encounter_state in ["rescued","recovering"] and escort.is_empty() and player.get_meta("detention_action","")=="" and not aggressor.get_meta("dead",false) and not aggressor.get_meta("knocked_out",false) and not aggressor.get_meta("grappled",false):
		fight_aggressor(delta)

func _tick(delta: float) -> void:
	if not is_instance_valid(player):
		if not escort.is_empty(): release()
		return
	if is_instance_valid(aggressor) and is_instance_valid(peasant): update_rescue(delta)
	if not escort.is_empty():update_capture(delta)
	awareness_timer-=delta
	if awareness_timer<=0.0:
		awareness_timer=.25;recruit_visible_police()
	var seen:=false
	var coordinator: Node=station.get_node("ThanaStaff/ArrestCoordinator")
	if coordinator.phase in ["approach","fight"] and coordinator.has_method("officer_has_sight"):
		seen=coordinator.officer_has_sight()
	for patrol in patrols.duplicate():
		var actor: Node3D=patrol.actor
		if not is_instance_valid(actor): continue
		actor.set_meta("police_engaged",wanted and patrol.state=="pursue")
		var mount: Node3D=patrol.get("mount")
		if is_instance_valid(mount):
			if actor.get_meta("dead",false) or actor.get_meta("knocked_out",false):mount.commanded_speed=0
			elif mount.vitality.dead or mount.blocked_age>1.5 or (wanted and patrol.seen and actor.global_position.distance_to(player.global_position)<5.0):
				dismount_patrol(patrol)
				mount=patrol.get("mount")
		if actor.get_meta("police_dismounting",false) or actor.get_meta("police_mounting",false):
			if is_instance_valid(mount):mount.commanded_speed=0
			actor.travel_speed=0;continue
		var firearm := actor.get_node_or_null("ClimbingFirearm")
		if firearm != null: firearm.hostile = wanted and patrol.state == "pursue"
		if player.get_meta("detention_action","")!="" and (escort.is_empty() or escort.actor!=actor):
			if is_instance_valid(mount):mount.commanded_speed=0
			actor.travel_speed=0
			patrol.marker.visible=false
			continue
		if actor.get_meta("combat_action","")=="hit":
			if is_instance_valid(mount):mount.commanded_speed=0
			actor.travel_speed=0;patrol.attack_age=0;continue
		if actor.get_meta("dead",false) or actor.get_meta("knocked_out",false) or actor.get_meta("grappled",false):
			patrol.marker.visible=false
			continue
		if actor.get_meta("city_custody",false):
			if station.get_node("ThanaStaff/ArrestCoordinator").phase!="idle":continue
			actor.set_meta("city_custody",false)
		if not escort.is_empty() and escort.actor==actor:continue
		var essential:bool=patrol.state=="pursue" or actor.get_meta("mission_active",false) or actor.get_meta("combat_action","")!=""
		var cadence:float=preload("res://systems/simulation_budget.gd").interval(actor,player,essential)
		patrol["motion_elapsed"]=float(patrol.get("motion_elapsed",0.0))+delta
		if float(patrol.motion_elapsed)<cadence:continue
		var patrol_delta:float=patrol.motion_elapsed
		patrol.motion_elapsed=0.0
		if patrol.state=="return":
			if wanted and visible_to(actor):
				patrol.state="pursue";patrol.seen=true;patrol["last_seen"]=player.global_position
			elif navigate_patrol(patrol,patrol.points[0],1.3,patrol_delta):
				restore_recruited_duty(patrol);patrols.erase(patrol);continue
			else:continue
		patrol.sense-=patrol_delta
		if patrol.sense<=0:
			patrol.sense=.25
			patrol.seen=wanted and visible_to(actor)
			if patrol.seen:patrol.state="pursue";unseen_age=0;last_known=player.global_position;patrol["last_seen"]=player.global_position
		seen=seen or patrol.seen
		patrol.marker.visible=patrol.state=="pursue"
		if is_instance_valid(mount):
			mount.goal=patrol.points[patrol.index] if patrol.state=="patrol" else patrol.get("last_seen",last_known)
			mount.commanded_speed=2.0 if patrol.state=="patrol" else 6.0+float(wanted_level)
			if patrol.state=="patrol" and mount.global_position.distance_to(mount.goal)<1.0:
				if patrol.index==patrol.points.size()-1:patrol.step=-1
				elif patrol.index==0:patrol.step=1
				patrol.index+=patrol.step
			continue
		var parked: Node3D=patrol.get("horse")
		if not wanted and is_instance_valid(parked) and not parked.vitality.dead:
			if actor.global_position.distance_to(parked.global_position)<1.9:
				actor.begin_mount(parked);patrol.mount=parked
			else:navigate_patrol(patrol,parked.global_position+parked.global_basis.x*1.55,1.3,patrol_delta)
			continue
		if patrol.state=="patrol":
			var point: Vector3=patrol.points[patrol.index]
			var arrived:bool=navigate_patrol(patrol,point,1.3,patrol_delta) if actor.has_meta("population_route") else move_actor(actor,point,1.3,patrol_delta)
			if arrived:
				if patrol.index==patrol.points.size()-1:patrol.step=-1
				elif patrol.index==0:patrol.step=1
				patrol.index+=patrol.step
		else:
			seen=seen or patrol.seen
			if firearm != null and firearm.can_engage():
				actor.travel_speed = 0
				continue
			var offset:=player.global_position-actor.global_position;offset.y=0
			if not patrol.seen:
				navigate_patrol(patrol,patrol.get("last_seen",last_known),2.8,patrol_delta)
				continue
			if offset.length()>1.15:navigate_patrol(patrol,player.global_position,2.8,patrol_delta)
			else:
				actor.travel_speed=0
				var rear: Vector3=actor.global_position-player.global_position;rear.y=0
				if escort.is_empty() and station.get_node("ThanaStaff/ArrestCoordinator").phase=="idle" and (rear.normalized().dot(player.get_node("VisualRoot").global_basis.z)<-.55 or player.health<=10) and player.get_meta("detention_action","")=="" and player.get_node("DetentionComponent").begin_detention():
					escort={"actor":actor,"state":"capture","age":0.0,"route":PackedVector3Array(),"index":0};escape_press=0
					actor.combat_react("held")
					player.inventory.message_requested.emit("Caught · Press Space four times to escape")
				else:
					patrol.attack_age+=patrol_delta
					if patrol.attack_age>=1.2:patrol.attack_age=0;patrol.hit=false;actor.combat_react("strike")
					if patrol.attack_age>=.28 and patrol.attack_age<=.60 and not patrol.hit and strike_hits_player(actor):
						patrol.hit=true;player.receive_combat_hit(minf(8,maxf(0,player.health-1)),actor)
			if not wanted:patrol.state="patrol"
	advance_wanted(delta,seen)

func dismount_patrol(patrol: Dictionary) -> bool:
	var horse: Node3D=patrol.get("mount")
	if not is_instance_valid(horse):return false
	horse.commanded_speed=0
	var actor: Node3D=patrol.actor
	for side in [-1.0,1.0]:
		var at:Vector3=horse.global_position+horse.global_basis.x*side*1.55
		var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.65,at-Vector3.UP*.7,1,[horse.get_rid(),actor.body_collider.get_rid()])
		var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y<.7:continue
		at.y=hit.position.y
		var shape:CollisionShape3D=actor.body_collider.get_node("BodyShape")
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.collision_mask=1
		query.exclude=[horse.get_rid(),actor.body_collider.get_rid()]
		query.transform=shape.global_transform;query.transform.origin=at+Vector3.UP*(shape.position.y+.03)
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
		actor.begin_dismount(at);patrol.mount=null;horse.blocked_age=0.0
		return true
	return false

func update_capture(delta: float) -> void:
	if escort.is_empty(): return
	var actor: Node3D=escort.get("actor")
	if not is_instance_valid(actor) or not is_instance_valid(player) or not is_instance_valid(station):
		release()
		return
	escort.age+=delta
	if actor.get_meta("dead",false) or actor.get_meta("knocked_out",false):release();return
	if escort.state=="capture":
		if escape_press>=4:release();return
		if escort.age>=2.8:
			var coordinator: Node = station.get_node("ThanaStaff/ArrestCoordinator")
			if coordinator.cinematic_transfers:
				actor.get_node("CombatMotion").state=""
				actor.set_meta("combat_action","")
				actor.animation_tree.set("parameters/combat/blend_amount",0.0)
				if coordinator.accept_external_arrest(player,actor):
					escort = {}
				else: release()
				return
			actor.get_node("CombatMotion").state=""
			actor.set_meta("combat_action","");actor.animation_tree.set("parameters/combat/blend_amount",0.0)
			escort.route=road_path(player.global_position,Vector3(320,10,150))
			if escort.route.is_empty():release();return
			escort.state="escort";escort.age=0
			actor.detainee=player;actor.duty_state="escort"
			player.get_node("DetentionComponent").mode="escort"
			player.set_meta("detention_action","escort")
	else:
		if escort.age>240:release();return
		if escort.index>=escort.route.size():
			var coordinator:=station.get_node("ThanaStaff/ArrestCoordinator")
			if coordinator.phase!="idle":release();return
			coordinator.suspect=player;coordinator.detention=player.get_node("DetentionComponent")
			coordinator.officer=actor;coordinator.home=actor.global_position
			coordinator.exclusions.assign([player.get_rid(),actor.body_collider.get_rid()])
			coordinator.route=coordinator.path(player.global_position-Vector3.UP*.9,station.to_global(Vector3(4,0,15.8)),1.05)
			if coordinator.route.is_empty():release();return
			coordinator.route_index=0;coordinator.officer.detainee=player;coordinator.officer.duty_state="escort"
			actor.set_meta("city_custody",true)
			coordinator.set_phase("escort")
			escort={}
			return
		var goal: Vector3=escort.route[escort.index]+Vector3.UP*.9
		var offset:=goal-player.global_position;offset.y=0
		if offset.length()<.2:escort.index+=1;return
		var previous:=player.global_position
		player.global_rotation.y=rotate_toward(player.global_rotation.y,atan2(offset.x,offset.z),delta*3)
		player.get_node("VisualRoot").rotation.y=0
		player.velocity=offset.normalized()*1.2+Vector3.DOWN
		player.move_and_slide()
		player.get_node("DetentionComponent").anchor=player.global_transform
		player.set_meta("detention_speed",player.global_position.distance_to(previous)/maxf(delta,.001))
		var formation:=player.global_position+player.global_basis*Vector3(.74,-.9,-.15)
		var relative:=actor.global_position-player.global_position;relative.y=0
		var desired:=formation-player.global_position;desired.y=0
		var current_angle:=atan2(relative.x,relative.z)
		var desired_angle:=atan2(desired.x,desired.z)
		if absf(angle_difference(current_angle,desired_angle))>.25:
			var angle:=rotate_toward(current_angle,desired_angle,delta*1.8)
			formation=player.global_position+Vector3(sin(angle),-.9,cos(angle))*.84
		move_actor(actor,formation,1.6,delta)

func release() -> void:
	if is_instance_valid(player):
		player.get_node("DetentionComponent").release_detention()
	if not escort.is_empty():
		var actor: Node3D=escort.get("actor")
		if is_instance_valid(actor):
			actor.get_node("CombatMotion").state=""
			actor.set_meta("combat_action","")
			actor.animation_tree.set("parameters/combat/blend_amount",0.0)
			actor.detainee=null
			actor.duty_state="idle"
	escort={};unseen_age=0
	if wanted and is_instance_valid(player): player.inventory.message_requested.emit("Arrest interrupted · Police are still searching")

func road_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var graph:=AStar3D.new()
	var ids: Dictionary={}
	for route in Layout.ROUTES.values():
		var previous: int=-1
		for point in route:
			if not ids.has(point):
				var id:=ids.size();ids[point]=id
				graph.add_point(id,ground(Vector3(point.x,0,point.y)))
			var id: int=ids[point]
			if previous>=0:graph.connect_points(previous,id)
			previous=id
	var a:=graph.get_closest_point(from);var b:=graph.get_closest_point(to)
	var path:=graph.get_point_path(a,b)
	if path.is_empty():return []
	path.append(station.to_global(Vector3(0,0,23)))
	path.append(station.to_global(Vector3(0,0,16.4)))
	return path

func _process(_delta: float) -> void:
	if escort.is_empty() or escort.state!="capture":return
	var actor: Node3D=escort.get("actor")
	if not is_instance_valid(actor) or not is_instance_valid(player): return
	var visual: Node3D=player.get_node("VisualRoot/CharacterVisual")
	var rig: Skeleton3D=visual.skeleton
	for side in ["l","r"]:
		var target:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("upperarm_"+side)).origin)
		actor.solve_hand_contact(side,target);actor.set_grip(side,.3)

func strike_hits_player(actor: Node3D) -> bool:
	return visible_to(actor) and strike_hits_actor(actor,player)

func strike_hits_actor(actor: Node3D, target: Node3D) -> bool:
	actor._skeleton.force_update_all_bone_transforms()
	var hand: int=actor._skeleton.find_bone("hand_r")
	var point: Vector3=actor._skeleton.to_global(actor._skeleton.get_bone_global_pose(hand).origin)
	var query:=PhysicsShapeQueryParameters3D.new()
	var sphere:=SphereShape3D.new();sphere.radius=.14
	query.shape=sphere;query.transform.origin=point
	query.exclude=[actor.body_collider.get_rid()];query.collision_mask=9
	var policy=preload("res://combat/damage_policy.gd")
	for hit in get_world_3d().direct_space_state.intersect_shape(query,8):
		var receiver: Node=policy.receiver(hit.collider)
		if receiver!=target and (receiver==null or receiver.get_parent()!=target):continue
		var sight:=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*1.2,point,1)
		sight.exclude=[actor.body_collider.get_rid()]
		var obstacle:=get_world_3d().direct_space_state.intersect_ray(sight)
		if not obstacle.is_empty() and policy.receiver(obstacle.collider)!=receiver:continue
		return true
	return false

func fight_aggressor(delta: float) -> void:
	if aggressor.get_meta("combat_action","")=="hit":aggressor.travel_speed=0;return
	var offset:=player.global_position-aggressor.global_position;offset.y=0
	if offset.length()>20:aggressor.travel_speed=0;return
	if offset.length()>1.0:move_actor(aggressor,player.global_position,2.2,delta);return
	aggressor.travel_speed=0
	aggressor.global_rotation.y=atan2(offset.x,offset.z)
	strike_age+=delta
	if strike_age>=1.2:strike_age=0;strike_hit=false;aggressor.combat_react("strike")
	if strike_age>=.28 and strike_age<=.60 and not strike_hit and strike_hits_player(aggressor):
		strike_hit=true;player.receive_combat_hit(minf(8,maxf(0,player.health-1)),aggressor)

func export_crime_state() -> Dictionary:
	var records: Array[Dictionary]=[]
	for item in evidence:
		var record: Dictionary=item.duplicate(true)
		var at: Vector3=record.location
		record.location=[at.x,at.y,at.z]
		records.append(record)
	return {"score":crime_score,"unseen":unseen_age,"last_known":[last_known.x,last_known.y,last_known.z],"evidence":records}

func restore_crime_state(data: Dictionary) -> void:
	crime_score=clampi(int(data.get("score",0)),0,25)
	wanted_level=ceili(float(crime_score)/5.0);wanted=crime_score>0
	unseen_age=clampf(float(data.get("unseen",0)),0,55)
	var at: Array=data.get("last_known",[0,0,0])
	if at.size()==3:last_known=Vector3(float(at[0]),float(at[1]),float(at[2]))
	evidence.clear()
	for value in data.get("evidence",[]):
		if not value is Dictionary:continue
		var record: Dictionary=value.duplicate(true)
		var coords: Array=record.get("location",[0,0,0])
		if coords.size()!=3:continue
		record.location=Vector3(float(coords[0]),float(coords[1]),float(coords[2]))
		evidence.append(record)
		if evidence.size()>=32:break
