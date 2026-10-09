extends Node
## Witnessed local offences -> approach -> restraint -> escort -> seated custody -> release.
## A gameplay prototype, not a reconstruction of historical police procedure.
signal phase_changed(phase: String)
@export var custody_seconds := 5.0
@export var cinematic_transfers := true
@export_range(1,30) var sentence_days := 3
var transfer: RefCounted
var fight_age := 0.0
var strike_landed := false
var approach_side := 1.0
var phase := "idle"
var phase_age := 0.0
var suspect: CharacterBody3D
var officer: Node3D
var detention: Node
var station: Node3D
var gate: Node3D
var route: PackedVector3Array = []
var route_index := 0
var reason := ""
var route_blocked := false
var escort_distance := 0.0
var home := Vector3.ZERO
var exclusions: Array[RID] = []
var last_chase_goal := Vector3.ZERO
var chase_age := 0.0
var cooldown := 0.0
var nav_cache: Dictionary = {}
var debug_contacts:=false
var last_clear_failure: String=""
func _ready() -> void:
	station = get_parent().get_parent()
	process_physics_priority = 20
	add_to_group("police_crime_observers")
	transfer = preload("res://world/suryagarh/settlements/police_custody_transfer.gd").new()
	transfer.setup(self)
	transfer.sentence_days = sentence_days
func report_assault(victim: Node3D, attacker: Node = null) -> void:
	var player := get_tree().root.find_child("Player",true,false) as CharacterBody3D
	if attacker == null and victim.has_meta("last_attacker"): attacker = victim.get_meta("last_attacker")
	if player != null and attacker == player: report_crime(player,"assault",victim.global_position)

func resolve_case() -> void:
	for observer in get_tree().get_nodes_in_group("police_crime_observers"):
		if observer.has_method("complete_custody"): observer.complete_custody(suspect)

func has_pending_police_case(player: Node) -> bool:
	return player == suspect and phase not in ["idle","return"]

func accept_external_arrest(player: CharacterBody3D, guard: Node3D) -> bool:
	if phase != "idle" or player.health <= 0 or not is_instance_valid(guard) or guard.get_meta("dead",false) or guard.get_meta("knocked_out",false): return false
	var held: Node = player.get_node("DetentionComponent")
	if held.mode.is_empty() and not held.begin_detention("arrest"): return false
	if held.mode not in ["arrest","escort","waiting"]: return false
	suspect = player
	detention = held
	officer = guard
	home = station.to_global(Vector3(1,0,20))
	reason = "wanted"
	exclusions.assign([player.get_rid(),guard.body_collider.get_rid()])
	officer.detainee = player
	officer.duty_state = "restraint"
	officer.travel_speed = 0.0
	officer.set_meta("city_custody",true)
	transfer.start()
	return true
func report_crime(player: CharacterBody3D, offence: String, location: Vector3) -> bool:
	if phase!="idle" or cooldown>0 or player.health <= 0 or not location.is_finite() or offence not in ["theft","assault"]: return false
	var local := station.to_local(player.global_position)
	if absf(local.y-.9)>.5 or absf(local.x)>18 or absf(local.z)>18: return false
	var offence_local := station.to_local(location)
	if absf(offence_local.x)>18 or absf(offence_local.z)>18 or absf(offence_local.y)>2: return false
	var best := 31.0
	var chosen: Node3D
	for candidate in get_parent().get_children():
		if candidate==self or candidate.get_meta("thana_role","")=="mohurrir" or candidate.get_meta("dead",false) or candidate.get_meta("knocked_out",false): continue
		if not candidate is Node3D: continue
		var distance: float = candidate.global_position.distance_to(location)
		if distance>=best: continue
		if not can_see(candidate,player): continue
		var query := PhysicsRayQueryParameters3D.create(candidate.global_position+Vector3.UP*1.35,player.global_position+Vector3.UP*.4,1)
		query.exclude = [player.get_rid(),candidate.body_collider.get_rid()]
		if preload("res://combat/escape_smoke.gd").obscures(station.get_tree(),query.from,query.to):continue
		if not station.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		chosen = candidate
		best = distance
	if chosen==null: return false
	suspect = player
	detention = player.get_node("DetentionComponent")
	officer = chosen
	home = officer.global_position
	reason = offence
	approach_side = 1.0
	exclusions = [player.get_rid()]
	for candidate in get_parent().get_children():
		if candidate is Node3D and candidate.has_method("palm_world"): exclusions.append(candidate.body_collider.get_rid())
	var approach: Vector3 = player.global_position + player.get_node("VisualRoot").global_basis*Vector3(.72,-.9,-.34)
	route = path(officer.global_position,approach,.29)
	if route.is_empty(): return false
	route_index = 0
	last_chase_goal=player.global_position
	chase_age=0
	officer.detainee = suspect
	officer.duty_state = "approach"
	set_phase("approach")
	for observer in get_tree().get_nodes_in_group("police_crime_observers"):
		if observer.has_method("police_case_started"): observer.police_case_started(player)
	player.inventory.message_requested.emit("Police witnessed " + offence)
	return true
func approach_goal() -> Vector3:
	return suspect.global_position + suspect.get_node("VisualRoot").global_basis * Vector3(.72*approach_side,-.9,-.34)

func resume_pursuit() -> void:
	route = path(officer.global_position,approach_goal(),.29)
	route_index = 0
	last_chase_goal = suspect.global_position
	chase_age = 0.0
	officer.strike_progress = -1.0
	officer.duty_state = "approach"
	if route.is_empty(): abort(); return
	set_phase("approach")

func set_phase(value: String) -> void:
	phase = value
	phase_age = 0.0
	phase_changed.emit(value)
func clear_at(at: Vector3, radius: float) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(1.72,radius*2)
	query.shape = capsule
	query.transform.origin = at+Vector3.UP*(capsule.height*.5+.02)
	query.exclude = exclusions
	query.collision_mask = 1
	query.margin = .005
	var contacts:=station.get_world_3d().direct_space_state.intersect_shape(query,4)
	if not contacts.is_empty():
		if debug_contacts:last_clear_failure=str(contacts[0].collider.get_path())+" at "+str(station.to_local(at))
		return false
	var floor_query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*.2,at-Vector3.UP*.3,1)
	floor_query.exclude = exclusions
	return not station.get_world_3d().direct_space_state.intersect_ray(floor_query).is_empty()
func path(from: Vector3, to: Vector3, radius: float) -> PackedVector3Array:
	var grid: AStarGrid2D = nav_cache.get(radius)
	if grid == null:
		grid = AStarGrid2D.new()
		grid.region = Rect2i(0,0,89,94)
		grid.cell_size = Vector2(.4,.4)
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.update()
		for z in 94:
			for x in 89:
				var point := station.to_global(Vector3(-17.6+x*.4,0,-16.8+z*.4))
				grid.set_point_solid(Vector2i(x,z),not clear_at(point,radius))
		nav_cache[radius]=grid
	var a: Vector2i = nearest(grid,station.to_local(from))
	var b: Vector2i = nearest(grid,station.to_local(to))
	if a.x<0 or b.x<0: return []
	var ids := grid.get_id_path(a,b)
	var result := PackedVector3Array()
	for id in ids: result.append(station.to_global(Vector3(-17.6+id.x*.4,0,-16.8+id.y*.4)))
	if not result.is_empty() and clear_at(station.to_global(Vector3(station.to_local(to).x,0,station.to_local(to).z)),radius): result.append(station.to_global(Vector3(station.to_local(to).x,0,station.to_local(to).z)))
	return result
func nearest(grid: AStarGrid2D, point: Vector3) -> Vector2i:
	var best := 2.0
	var found := Vector2i(-1,-1)
	for z in 94:
		for x in 89:
			var id := Vector2i(x,z)
			if grid.is_point_solid(id): continue
			var distance := Vector2(-17.6+x*.4,-16.8+z*.4).distance_to(Vector2(point.x,point.z))
			if distance<best: best=distance; found=id
	return found
func follow_officer(delta: float, speed: float) -> bool:
	if route_index>=route.size(): officer.travel_speed=0.0; return true
	var target := route[route_index]
	var change := target-officer.global_position
	change.y = 0
	if change.length()<(.02 if route_index==route.size()-1 else .12): route_index+=1; return false
	var step := change.normalized()*minf(speed*delta,change.length())
	if not clear_at(officer.global_position+step,.29): route_blocked=true; officer.travel_speed=0.0; return false
	officer.global_position+=step
	officer.global_rotation.y = atan2(change.x,change.z)
	officer.travel_speed=step.length()/maxf(delta,.001)
	officer.body_collider.force_update_transform()
	return false
func can_see(candidate: Node3D, subject: CharacterBody3D) -> bool:
	if not is_instance_valid(candidate) or not is_instance_valid(subject): return false
	if candidate.get_meta("dead",false) or candidate.get_meta("knocked_out",false): return false
	var from := candidate.global_position+Vector3.UP*1.4
	var stance := subject.get_node_or_null("StealthStance")
	var target: Vector3=stance.sight_target() if stance!=null else subject.global_position+Vector3.UP*.4
	var toward: Vector3=target-from
	var visible_range: float=stance.visible_range(from,28.0) if stance!=null else 28.0
	if toward.length()>visible_range: return false
	if toward.length()>3.0 and toward.normalized().dot(candidate.global_basis.z)<.2: return false
	var query := PhysicsRayQueryParameters3D.create(from,target,1)
	query.exclude=[subject.get_rid(),candidate.body_collider.get_rid()]
	if preload("res://combat/escape_smoke.gd").obscures(get_tree(),from,target):return false
	return station.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func officer_has_sight() -> bool:
	return can_see(officer,suspect)

func _physics_process(delta: float) -> void:
	cooldown = maxf(0,cooldown-delta)
	if phase=="idle": return
	phase_age+=delta
	if not is_instance_valid(suspect) or suspect.health <= 0: abort(); return
	if not is_instance_valid(officer) or officer.get_meta("dead",false) or officer.get_meta("knocked_out",false): abort(); return
	if cinematic_transfers and transfer.tick(): return
	match phase:
		"approach":
			var crime := suspect.get_parent().get_node_or_null("CombatEncounters")
			if crime!=null and not crime.wanted and crime.escort.is_empty():abort();return
			if not officer_has_sight():
				if phase_age>35:abort();return
				if route_index<route.size():follow_officer(delta,3.8)
				else:officer.travel_speed=0
				return
			chase_age+=delta
			if chase_age>.25 and suspect.global_position.distance_to(last_chase_goal)>.35:
				last_chase_goal=suspect.global_position
				chase_age=0
				var chase: Vector3=approach_goal()
				route=path(officer.global_position,chase,.29)
				route_index=0
				if route.is_empty(): abort(); return
			if suspect.global_position.distance_to(officer.global_position)>35 or phase_age>35: abort(); return
			if follow_officer(delta,3.8):
				if suspect.global_position.distance_to(officer.global_position)>1.8: resume_pursuit(); return
				var visual: Node = suspect.get_node("VisualRoot/CharacterVisual")
				if suspect.health > 25.0 and (not visual.equipment.stowed or visual.punch_phase >= 0.0 or visual.kick_phase >= 0.0):
					fight_age = 0.0
					strike_landed = false
					officer.duty_state = "fight"
					set_phase("fight")
					return
				if not detention.begin_detention("arrest"): officer.travel_speed=0; phase_age=0; return
				var face: Vector3=suspect.global_position-officer.global_position
				officer.global_rotation.y=atan2(face.x,face.z)
				officer.duty_state="restraint"
				set_phase("restraint")
		"fight":
			if officer.get_meta("combat_action","") == "hit":
				officer.strike_progress = -1.0
				officer.travel_speed = 0.0
				fight_age = 0.0
				strike_landed = false
				return
			var distance: float = suspect.global_position.distance_to(officer.global_position)
			if distance > 2.0:
				resume_pursuit()
				return
			var obstruction := PhysicsRayQueryParameters3D.create(officer.global_position+Vector3.UP*1.3,officer.strike_target(),1)
			obstruction.exclude = exclusions
			if not station.get_world_3d().direct_space_state.intersect_ray(obstruction).is_empty():
				approach_side *= -1.0
				nav_cache.clear()
				resume_pursuit()
				return
			var face: Vector3 = suspect.global_position-officer.global_position
			officer.global_rotation.y = atan2(face.x,face.z)
			officer.travel_speed = 0.0
			var visual: Node = suspect.get_node("VisualRoot/CharacterVisual")
			if suspect.health <= 25.0 or (visual.equipment.stowed and visual.punch_phase < 0.0 and visual.kick_phase < 0.0):
				officer.strike_progress = -1.0
				if not detention.begin_detention("arrest"): set_phase("approach"); return
				officer.duty_state = "restraint"
				set_phase("restraint")
				return
			fight_age += delta
			if fight_age >= 1.2:
				fight_age = 0.0
				strike_landed = false
			officer.strike_progress = clampf(fight_age/.9,0,1)
			officer.apply_fight_pose()
			if fight_age >= .45 and not strike_landed:
				strike_landed = true
				var ray := PhysicsRayQueryParameters3D.create(officer.global_position+Vector3.UP*1.3,officer.strike_target(),1)
				ray.exclude = exclusions
				if distance < 1.8 and officer.strike_contact_error < .10 and station.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
					suspect.receive_combat_hit(minf(8.0,maxf(0.0,suspect.health-20.0)),officer)
		"restraint":
			if phase_age<2.4: return
			if cinematic_transfers:
				transfer.start()
				return
			route=path(suspect.global_position-Vector3.UP*.9,station.to_global(Vector3(4,0,15.8)),1.05)
			if route.is_empty(): abort(); return
			route_index=0
			detention.mode="escort"
			suspect.set_meta("detention_action","escort")
			officer.duty_state="escort"
			set_phase("escort")
		"escort":
			if phase_age>50: abort(); return
			if route_index>=route.size():
				officer.travel_speed=0
				officer.duty_state="idle"
				suspect.set_meta("detention_action","waiting")
				detention.mode="waiting"
				gate=station.get_node("GroundCell0Gate")
				gate.set_open(true)
				route=path(suspect.global_position-Vector3.UP*.9,station.to_global(Vector3(7.2,0,15.2)),.43)
				route_index=0
				set_phase("enter_cell")
				return
			move_suspect(delta,1.15,true)
		"enter_cell":
			if phase_age>15: abort(); return
			if route_index<route.size(): move_suspect(delta,.85,false); return
			detention.seat_world = station.to_global(Vector3(7.2,.47,14.55))
			detention.floor_world = station.to_global(Vector3(7.2,0,15.20))
			detention.seat_rising=false
			detention.mode="seated"
			suspect.set_meta("detention_action","seated")
			suspect.set_meta("detention_seat_blend",0.0)
			suspect.global_basis=station.global_basis*Basis(Vector3.UP,0)
			suspect.get_node("VisualRoot").rotation.y=0
			detention.anchor=suspect.global_transform
			gate.set_locked(true)
			nav_cache.clear()
			set_phase("custody")
		"custody":
			if phase_age>=custody_seconds:
				detention.seat_rising=true
				set_phase("stand")
				return
		"stand":
			if phase_age<1.3: return
			gate.set_locked(false)
			nav_cache.clear()
			detention.mode="waiting"
			suspect.set_meta("detention_action","waiting")
			route=path(suspect.global_position-Vector3.UP*.9,station.to_global(Vector3(8,0,17.2)),.43)
			route_index=0
			set_phase("leave_cell")
		"leave_cell":
			if route_index<route.size() and phase_age<15: move_suspect(delta,.9,false); return
			resolve_case()
			detention.release_detention()
			suspect.inventory.message_requested.emit("Released from custody")
			route=path(officer.global_position,home,.29)
			route_index=0
			officer.detainee=null
			officer.duty_state="return"
			set_phase("return")
		"return":
			if follow_officer(delta,1.5) or phase_age>25:
				officer.travel_speed=0
				officer.duty_state="idle"
				cooldown=8
				set_phase("idle")
func move_suspect(delta: float, speed: float, paired: bool) -> void:
	var goal := route[route_index]+Vector3.UP*.9
	var change := goal-suspect.global_position
	change.y=0
	if change.length()<.12: route_index+=1; suspect.set_meta("detention_speed",0.0); return
	var direction := change.normalized()
	var previous := suspect.global_position
	suspect.global_rotation.y=rotate_toward(suspect.global_rotation.y,atan2(direction.x,direction.z),delta*2.8)
	suspect.get_node("VisualRoot").rotation.y=0
	suspect.velocity=direction*speed+Vector3.DOWN*.5
	suspect.move_and_slide()
	detention.anchor=suspect.global_transform
	var actual := suspect.global_position.distance_to(previous)/maxf(delta,.001)
	suspect.set_meta("detention_speed",actual)
	escort_distance+=previous.distance_to(suspect.global_position)
	if paired:
		var desired := suspect.global_position+suspect.global_basis*Vector3(.74,-.9,-.15)
		var next_officer: Vector3=officer.global_position.move_toward(desired,delta*2.4)
		var support_query:=PhysicsRayQueryParameters3D.create(next_officer+Vector3.UP*.25,next_officer-Vector3.UP*.25,1)
		support_query.exclude=exclusions
		var support:=station.get_world_3d().direct_space_state.intersect_ray(support_query)
		if not support.is_empty():next_officer.y=support.position.y+.001
		if clear_at(next_officer,.29):
			var travel: float=officer.global_position.distance_to(next_officer)
			officer.global_position=next_officer
			officer.global_rotation.y=rotate_toward(officer.global_rotation.y,suspect.global_rotation.y,delta*4.0)
			officer.travel_speed=travel/maxf(delta,.001)
		else:
			if debug_contacts and not route_blocked:print("ESCORT SOLID ",station.to_local(next_officer)," BLOCKER ",last_clear_failure," SUPPORT ",support)
			route_blocked=true
func abort() -> void:
	if transfer != null: transfer.abort()
	if is_instance_valid(detention): detention.release_detention()
	if is_instance_valid(gate): gate.set_locked(false)
	if is_instance_valid(officer): officer.detainee=null; officer.duty_state="idle"; officer.travel_speed=0; officer.strike_progress=-1.0
	set_phase("idle")
	cooldown=5
