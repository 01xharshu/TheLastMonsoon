extends Node
## An unidentified body draws an inspection, never knowledge of its killer.
var victim: Node3D
var encounters: Node3D
var record: Dictionary
var scene_position := Vector3.ZERO
var officer: Node3D
var route: Dictionary = {}
var origin := Vector3.ZERO
var prior_movement := false
var prior_external := false
var added_ground_exclusion := false
var phase := "discover"
var clock := 0.0
var inspect_age := 0.0
var scene_watch_age := 0.0
var question_age := 0.0
var approach_age := 0.0
var question_start := Vector3.ZERO
var supporters: Array[Dictionary] = []
var dialogue_layer: CanvasLayer
var dialogue_label: Label
const LINES := [
	"Constable: Do you know who did this? Where are you going?",
	"Arjun: I do not know, sir. I am going to my uncle's home.",
	"Constable: All right, you may go. Be careful. Crime is increasing.",
	"Arjun: I will, sir."
]
const LINE_SECONDS := [4.5, 4.5, 4.5, 2.5]
const RESPONSE_RANGE := 60.0
func _ready() -> void:
	process_priority=30
	var at: Array=record.location
	scene_position=Vector3(float(at[0]),float(at[1]),float(at[2]))
func _process(delta: float) -> void:
	if phase=="inspect" and is_instance_valid(officer) and not officer.get_meta("police_engaged",false) and not officer.get_meta("dead",false) and not officer.get_meta("knocked_out",false):
		for bone in ["spine_01","head"]:
			if officer._bones.has(bone):
				var index: int=officer._bones[bone]
				var weight := smoothstep(0.0,.7,inspect_age)*(1.0-smoothstep(5.3,6.0,inspect_age))
				var bend := (.35 if bone=="spine_01" else .60)*weight
				officer._skeleton.set_bone_pose_rotation(index,officer._base_rotations[bone]*Quaternion(officer._pitch_axes[bone],bend)*Quaternion(officer._yaw_axes[bone],sin(inspect_age*1.5)*.12*weight))
	clock += delta
	if clock < (1.0 if phase=="discover" else .2): return
	var elapsed := clock;clock=0.0
	if record.get("retired",false):finish();return
	if is_instance_valid(victim) and not victim.get_meta("dead",false):return
	if phase=="discover":
		var nearest := RESPONSE_RANGE
		for candidate in get_tree().get_nodes_in_group("combat_actors"):
			if not candidate is Node3D or candidate==victim or candidate.get_meta("combat_faction","")!="police":continue
			if not available_officer(candidate):continue
			var distance: float=candidate.global_position.distance_to(scene_position)
			if distance<nearest:officer=candidate;nearest=distance
		if not is_instance_valid(officer):return
		origin=officer.global_position;prior_movement=officer.movement_enabled;prior_external=officer.get_meta("external_combat_motion",false)
		officer.set_meta("body_inspection_previous",{"movement":prior_movement,"external":prior_external})
		officer.movement_enabled=false;officer.set_meta("external_combat_motion",true);officer.set_meta("inspecting_body",true)
		var officer_rid: RID = officer.body_collider.get_rid()
		added_ground_exclusion = not encounters.ground_exclusions.has(officer_rid)
		if added_ground_exclusion: encounters.ground_exclusions.append(officer_rid)
		route={"actor":officer};phase="approach"
		if record.get("anonymous", false):enlist_support()
	if not is_instance_valid(officer):release_officer();phase="discover";return
	if officer.get_meta("police_engaged",false) or officer.get_meta("dead",false) or officer.get_meta("knocked_out",false) or officer.get_meta("city_custody",false) or officer.get_meta("grappled",false) or officer.get_meta("mission_active",false):
		release_officer()
		if record.get("inspected",false):queue_free()
		else:phase="discover";inspect_age=0.0
		return
	tick_supporters(elapsed)
	if phase == "support_return":
		if supporters.is_empty():finish()
		return
	var player: CharacterBody3D = encounters.player
	if record.get("anonymous", false) and not record.get("question_resolved", false) and phase in ["approach", "inspect", "watch"]:
		if can_question(player):
			phase = "question_approach"
			approach_age = 0.0
			question_start = player.global_position
			show_dialogue("Constable: Excuse me. Please stop a moment.")
	if phase == "question_approach":
		approach_age += elapsed
		if not is_instance_valid(player) or player.health <= 0:
			clear_dialogue()
			phase = "watch"
		elif observed_flight(player):
			report_flight(player)
			return
		elif player.global_position.distance_to(officer.global_position) <= 2.5:
			start_question(player)
		elif approach_age < 15.0 and encounters.visible_to(officer) and player.global_position.distance_to(scene_position) < 10.0:
			var toward: Vector3 = officer.global_position - player.global_position
			toward.y = 0
			var stop := player.global_position + toward.normalized() * 2.0
			encounters.navigate_patrol(route, stop, 1.4, elapsed)
		else:
			clear_dialogue()
			phase = "watch"
	if phase == "question":
		tick_question(player, elapsed)
		return
	var goal: Vector3=origin if phase=="return" else scene_position+(origin-scene_position).normalized()*1.2
	if phase in ["approach","return"]:
		if encounters.navigate_patrol(route,goal,1.4,elapsed):
			if phase=="return":
				if supporters.is_empty():finish()
				else:phase="support_return"
				return
			phase="inspect"
	if phase=="inspect":
		officer.travel_speed=0.0;inspect_age+=elapsed
		var direction: Vector3=scene_position-officer.global_position
		officer.global_rotation.y=atan2(direction.x,direction.z)
		if inspect_age>6.0:
			if record.get("anonymous", false) and not record.get("question_resolved", false):
				phase="watch"
			else:
				record.inspected=true;phase="return"
	if phase=="watch":
		officer.travel_speed=0.0
		scene_watch_age += elapsed
		if scene_watch_age >= 45.0:
			record.inspected=true
			phase="return"

func available_officer(candidate: Node3D) -> bool:
	if candidate.get_meta("dead", false) or candidate.get_meta("knocked_out", false) or candidate.get_meta("police_engaged", false) or candidate.get_meta("city_custody", false) or candidate.get_meta("grappled", false) or candidate.get_meta("mission_police_owner", "") != "" or candidate.get_meta("mission_active", false) or candidate.get_meta("station_records_duty", false) or candidate.get_meta("story_cinematic", false) or candidate.get_meta("inspecting_body", false):
		return false
	if not candidate.get_meta("external_combat_motion", false):
		return true
	for patrol in encounters.patrols:
		if patrol.get("actor") == candidate and patrol.get("state") == "patrol" and not is_instance_valid(patrol.get("mount")):
			return true
	return false

func enlist_support() -> void:
	var closest: Node3D
	var distance := RESPONSE_RANGE
	for candidate in get_tree().get_nodes_in_group("combat_actors"):
		if not candidate is Node3D or candidate == victim or candidate == officer or candidate.get_meta("combat_faction", "") != "police": continue
		if not available_officer(candidate): continue
		var candidate_distance: float = candidate.global_position.distance_to(scene_position)
		if candidate_distance < distance:
			closest = candidate
			distance = candidate_distance
	if not is_instance_valid(closest): return
	var previous := {"movement": closest.movement_enabled, "external": closest.get_meta("external_combat_motion", false)}
	closest.set_meta("body_inspection_previous", previous)
	closest.movement_enabled = false
	closest.set_meta("external_combat_motion", true)
	closest.set_meta("inspecting_body", true)
	var helper_rid: RID = closest.body_collider.get_rid()
	var added_exclusion: bool = not encounters.ground_exclusions.has(helper_rid)
	if added_exclusion: encounters.ground_exclusions.append(helper_rid)
	supporters.append({"actor": closest, "origin": closest.global_position, "previous": previous,
		"route": {"actor": closest}, "arrived": false, "added_exclusion": added_exclusion})

func tick_supporters(elapsed: float) -> void:
	for entry in supporters.duplicate():
		var helper: Node3D = entry.actor
		if not is_instance_valid(helper) or helper.get_meta("police_engaged", false) or helper.get_meta("dead", false) or helper.get_meta("knocked_out", false) or helper.get_meta("city_custody", false) or helper.get_meta("mission_active", false):
			release_supporter(entry)
			continue
		var returning := phase in ["return", "support_return"]
		var direction: Vector3 = entry.origin - scene_position
		direction.y = 0
		if direction.length_squared() < .01: direction = Vector3.RIGHT
		var destination: Vector3 = entry.origin if returning else scene_position + direction.normalized() * 2.5
		if encounters.navigate_patrol(entry.route, destination, 1.4, elapsed):
			if returning:
				release_supporter(entry)
			else:
				entry.arrived = true
				helper.travel_speed = 0.0
				var toward := scene_position - helper.global_position
				helper.global_rotation.y = atan2(toward.x, toward.z)

func release_supporter(entry: Dictionary) -> void:
	var helper: Node3D = entry.actor
	if is_instance_valid(helper):
		if entry.added_exclusion and not helper.get_meta("police_engaged", false):
			encounters.ground_exclusions.erase(helper.body_collider.get_rid())
		helper.set_meta("inspecting_body", false)
		helper.remove_meta("body_inspection_previous")
		if not helper.get_meta("police_engaged", false) and not helper.get_meta("dead", false) and not helper.get_meta("knocked_out", false) and not helper.get_meta("city_custody", false) and not helper.get_meta("mission_active", false):
			helper.movement_enabled = bool(entry.previous.movement)
			helper.set_meta("external_combat_motion", entry.previous.external)
			helper.travel_speed = 0.0
	if is_instance_valid(entry.route.get("navigation")): entry.route.navigation.queue_free()
	supporters.erase(entry)

func can_question(player: CharacterBody3D) -> bool:
	if not is_instance_valid(player) or player.health <= 0 or encounters.wanted:
		return false
	if player.get_meta("story_cinematic", false) or player.get_meta("detention_action", "") != "":
		return false
	if player.has_meta("police_question_owner"):
		var owner: Variant = player.get_meta("police_question_owner")
		if is_instance_valid(owner) and owner != self:
			return false
	return player.global_position.distance_to(scene_position) <= 8.0 and encounters.visible_to(officer)

func start_question(player: CharacterBody3D) -> void:
	phase = "question"
	question_age = 0.0
	question_start = player.global_position
	officer.travel_speed = 0.0
	preload("res://story/conversation_facing.gd").toward(officer, player.global_position)
	if player.velocity.length_squared() < .09:
		preload("res://story/conversation_facing.gd").toward(player, officer.global_position)
	show_dialogue(LINES[0])

func show_dialogue(text: String) -> void:
	if is_instance_valid(encounters.player):
		encounters.player.set_meta("police_question_owner", self)
	if not is_instance_valid(dialogue_layer):
		dialogue_layer = CanvasLayer.new()
		dialogue_layer.layer = 80
		add_child(dialogue_layer)
		dialogue_label = Label.new()
		dialogue_layer.add_child(dialogue_label)
		dialogue_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		dialogue_label.offset_left = 70
		dialogue_label.offset_right = -70
		dialogue_label.offset_top = -115
		dialogue_label.offset_bottom = -25
		dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dialogue_label.add_theme_font_size_override("font_size", 23)
		dialogue_label.add_theme_constant_override("outline_size", 5)
	dialogue_label.text = text

func clear_dialogue() -> void:
	if is_instance_valid(encounters) and is_instance_valid(encounters.player) and encounters.player.has_meta("police_question_owner") and encounters.player.get_meta("police_question_owner") == self:
		encounters.player.remove_meta("police_question_owner")
	if is_instance_valid(dialogue_layer):
		dialogue_layer.queue_free()
	dialogue_layer = null
	dialogue_label = null

func observed_flight(player: CharacterBody3D) -> bool:
	var survival := player.get_node_or_null("SurvivalComponent")
	return survival != null and survival.is_sprinting and player.global_position.distance_to(officer.global_position) > 3.5 and player.global_position.distance_to(question_start) > 2.0 and encounters.visible_to(officer)

func report_flight(player: CharacterBody3D) -> void:
	var witnesses: Array[String] = [str(officer.get_path())]
	encounters.record_incident("fled_questioning", player.global_position, witnesses, 5)
	record.question_resolved = true
	record.inspected = true
	end_question(true)

func tick_question(player: CharacterBody3D, elapsed: float) -> void:
	if not is_instance_valid(player) or player.health <= 0:
		end_question(false)
		return
	var distance := player.global_position.distance_to(officer.global_position)
	if observed_flight(player):
		report_flight(player)
		return
	if distance > 8.0:
		record.question_resolved = true
		record.inspected = true
		end_question(false)
		return
	officer.travel_speed = 0.0
	preload("res://story/conversation_facing.gd").toward(officer, player.global_position)
	if player.velocity.length_squared() < .09:
		preload("res://story/conversation_facing.gd").toward(player, officer.global_position)
	question_age += elapsed
	var remaining := question_age
	for index in LINES.size():
		if remaining < LINE_SECONDS[index]:
			dialogue_label.text = LINES[index]
			return
		remaining -= LINE_SECONDS[index]
	record.question_resolved = true
	record.inspected = true
	end_question(false)

func end_question(fled: bool) -> void:
	clear_dialogue()
	preload("res://story/conversation_facing.gd").release(officer)
	if is_instance_valid(encounters.player):
		preload("res://story/conversation_facing.gd").release(encounters.player)
	if fled:
		release_officer()
		queue_free()
	else:
		phase = "return"

func release_officer() -> void:
	for entry in supporters.duplicate():
		release_supporter(entry)
	clear_dialogue()
	preload("res://story/conversation_facing.gd").release(officer)
	if is_instance_valid(encounters.player):
		preload("res://story/conversation_facing.gd").release(encounters.player)
	if is_instance_valid(officer):
		if added_ground_exclusion and not officer.get_meta("police_engaged", false):
			encounters.ground_exclusions.erase(officer.body_collider.get_rid())
		officer.set_meta("inspecting_body",false)
		officer.remove_meta("body_inspection_previous")
		if not officer.get_meta("police_engaged",false) and not officer.get_meta("dead",false) and not officer.get_meta("knocked_out",false) and not officer.get_meta("city_custody",false) and not officer.get_meta("mission_active",false):
			officer.movement_enabled=prior_movement;officer.set_meta("external_combat_motion",prior_external);officer.travel_speed=0.0
	if is_instance_valid(route.get("navigation")):route.navigation.queue_free()
	route.clear();officer=null;added_ground_exclusion=false
func finish() -> void:
	release_officer()
	queue_free()
