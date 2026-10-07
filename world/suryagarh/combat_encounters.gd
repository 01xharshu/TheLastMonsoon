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
var wanted := false
var unseen_age := 0.0
var patrols: Array[Dictionary] = []
var station: Node3D
var escort: Dictionary = {}
var escape_press := 0.0
var ground_exclusions: Array[RID]=[]
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

func spawn(label: String, path: String, at: Vector3, faction: String) -> Node3D:
	var actor: Node3D = preload("res://characters/npcs/thana/thana_officer.gd").new() if faction=="police" else Actor.new()
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
	for npc in get_tree().get_nodes_in_group("combat_actors"):
		if npc.body_collider!=null:ground_exclusions.append(npc.body_collider.get_rid())
	var origin:=ground(Vector3(321,0,151))
	peasant=spawn("RescuePeasant","res://characters/npcs/rescue_peasant.glb",origin+Vector3(1.5,0,0),"indian")
	peasant.set_meta("adult",true)
	aggressor=spawn("ArrogantPrivate","res://characters/npcs/british/private_man.glb",origin+Vector3(1.5,0,1.0),"british")
	aggressor.rotation.y=PI
	aggressor.set_meta("rescue_aggressor",true)
	for record in [{"id":"PoliceRoadPatrol","route":"police_to_compound","model":"burkundaz"},{"id":"CivilLinesPatrol","route":"civil_lines_avenue","model":"daroga"},{"id":"CantonmentPatrol","route":"cantonment_approach","model":"burkundaz"}]:
		var points:=PackedVector3Array()
		for p in Layout.ROUTES[record.route]:points.append(ground(Vector3(p.x,0,p.y)))
		var start_index: int=2 if record.id=="CantonmentPatrol" else 0
		var actor:=spawn(record.id,"res://characters/npcs/thana/%s_motion.glb"%record.model,points[start_index],"police")
		if record.id == "CantonmentPatrol":
			var firearm := preload("res://combat/climbing_firearm_attack.gd").new()
			firearm.name = "ClimbingFirearm"
			firearm.target = player
			actor.add_child(firearm)
		var marker:=Label3D.new();marker.name="AlertMarker";marker.text="!";marker.font_size=48
		marker.position.y=2.05;marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED;marker.modulate=Color(1,.55,.15);marker.visible=false
		actor.add_child(marker)
		patrols.append({"actor":actor,"points":points,"index":start_index+1,"step":1,"state":"patrol","sense":float(patrols.size())*.08,"attack_age":0.0,"hit":false,"marker":marker,"seen":false})

func ground(point: Vector3) -> Vector3:
	ground_query_count+=1
	var query:=PhysicsRayQueryParameters3D.create(Vector3(point.x,layout.height(point.x,point.z)+4,point.z),Vector3(point.x,layout.height(point.x,point.z)-3,point.z),1)
	query.exclude=ground_exclusions
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else Vector3(point.x,layout.height(point.x,point.z),point.z)

func report_assault(victim: Node3D) -> void:
	if victim.get_meta("combat_faction","indian") in ["british","police"]:
		wanted=true;unseen_age=0
		if victim==aggressor and encounter_state in ["beating","waiting","fallen"]:rescue()

func rescue() -> void:
	encounter_state="rescued";encounter_age=0
	if is_instance_valid(peasant):
		peasant.set_meta("rescued",true)
	player.inventory.message_requested.emit("Peasant protected · Police alerted")

func visible_to(actor: Node3D) -> bool:
	var toward:=player.global_position-actor.global_position
	var stance: Node = player.get_node("StealthStance")
	var observer := actor.global_position+Vector3.UP*1.4
	if toward.length()>stance.visible_range(observer,28.0):return false
	if toward.normalized().dot(actor.global_basis.z)<.2 and toward.length()>3:return false
	sense_ray_count+=1
	var sight:=PhysicsRayQueryParameters3D.create(observer,stance.sight_target(),1)
	sight.exclude=[player.get_rid(),actor.body_collider.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(sight).is_empty()

func move_actor(actor: Node3D, goal: Vector3, speed: float, delta: float) -> bool:
	var offset:=goal-actor.global_position;offset.y=0
	if offset.length()<.13:actor.travel_speed=0;return true
	var change:=offset.normalized()*minf(delta*speed,offset.length())
	actor.global_rotation.y=rotate_toward(actor.global_rotation.y,atan2(offset.x,offset.z),delta*4)
	var next:=ground(actor.global_position+change)
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
		var support:=ground(actor.global_position+change+offset.normalized()*.24)
		if support.y<next.y or support.y-next.y>.16:actor.travel_speed=0;return false
		query.transform.origin.y+=.16
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():actor.travel_speed=0;return false
		next.y=support.y

	actor.global_position=next;actor.travel_speed=change.length()/maxf(delta,.001)
	actor.body_collider.force_update_transform()
	return false

func _unhandled_input(event: InputEvent) -> void:
	if escort.is_empty() or escort.state!="capture":return
	if event.is_action_pressed("jump") and not event.is_echo():
		escape_press+=1
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if not profile_enabled:_tick(delta);return
	var start:=Time.get_ticks_usec()
	_tick(delta)
	if cost_samples.size()<600:cost_samples.append(float(Time.get_ticks_usec()-start))

func _tick(delta: float) -> void:
	if not is_instance_valid(aggressor):return
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
	if not escort.is_empty():update_capture(delta)
	var seen:=false
	for patrol in patrols:
		var actor: Node3D=patrol.actor
		var firearm := actor.get_node_or_null("ClimbingFirearm")
		if firearm != null: firearm.hostile = wanted and patrol.state == "pursue"
		if player.get_meta("detention_action","")!="" and (escort.is_empty() or escort.actor!=actor):
			actor.travel_speed=0
			continue
		if actor.get_meta("combat_action","")=="hit":actor.travel_speed=0;patrol.attack_age=0;continue
		if actor.get_meta("dead",false) or actor.get_meta("knocked_out",false) or actor.get_meta("grappled",false):
			patrol.marker.visible=false
			continue
		if actor.get_meta("city_custody",false):
			if station.get_node("ThanaStaff/ArrestCoordinator").phase!="idle":continue
			actor.set_meta("city_custody",false)
		if not escort.is_empty() and escort.actor==actor:continue
		patrol.sense-=delta
		if patrol.sense<=0:
			patrol.sense=.25
			patrol.seen=wanted and visible_to(actor)
			if patrol.seen:patrol.state="pursue";unseen_age=0
		patrol.marker.visible=patrol.state=="pursue"
		if patrol.state=="patrol":
			var point: Vector3=patrol.points[patrol.index]
			if move_actor(actor,point,1.3,delta):
				if patrol.index==patrol.points.size()-1:patrol.step=-1
				elif patrol.index==0:patrol.step=1
				patrol.index+=patrol.step
		else:
			seen=seen or patrol.seen
			if firearm != null and firearm.can_engage():
				actor.travel_speed = 0
				continue
			var offset:=player.global_position-actor.global_position;offset.y=0
			if offset.length()>1.15:move_actor(actor,player.global_position,2.8,delta)
			else:
				actor.travel_speed=0
				var rear: Vector3=actor.global_position-player.global_position;rear.y=0
				if escort.is_empty() and station.get_node("ThanaStaff/ArrestCoordinator").phase=="idle" and (rear.normalized().dot(player.get_node("VisualRoot").global_basis.z)<-.55 or player.health<=10) and player.get_meta("detention_action","")=="" and player.get_node("DetentionComponent").begin_detention():
					escort={"actor":actor,"state":"capture","age":0.0,"route":PackedVector3Array(),"index":0};escape_press=0
					actor.combat_react("held")
					player.inventory.message_requested.emit("Caught · Press Space four times to escape")
				else:
					patrol.attack_age+=delta
					if patrol.attack_age>=1.2:patrol.attack_age=0;patrol.hit=false;actor.combat_react("strike")
					if patrol.attack_age>=.28 and patrol.attack_age<=.60 and not patrol.hit and strike_hits_player(actor):
						patrol.hit=true;player.receive_combat_hit(minf(8,maxf(0,player.health-1)),actor)
			if not wanted:patrol.state="patrol"
	if wanted and escort.is_empty():
		unseen_age=0 if seen else unseen_age+delta
		if unseen_age>15:wanted=false

func update_capture(delta: float) -> void:
	var actor: Node3D=escort.actor
	escort.age+=delta
	if actor.get_meta("dead",false) or actor.get_meta("knocked_out",false):release();return
	if escort.state=="capture":
		if escape_press>=4:release();return
		if escort.age>=2.8:
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
			escort={};wanted=false
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
	player.get_node("DetentionComponent").release_detention()
	if not escort.is_empty():
		var actor: Node3D=escort.actor
		actor.get_node("CombatMotion").state=""
		actor.set_meta("combat_action","")
		actor.animation_tree.set("parameters/combat/blend_amount",0.0)
		actor.detainee=null
		actor.duty_state="idle"
	escort={};wanted=false;unseen_age=0

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
	var actor: Node3D=escort.actor
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
