extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://world/suryagarh/suryagarh_world.tscn")
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	current_scene = world
	for i in 65: await physics_frame
	var horse: CharacterBody3D = world.get_node_or_null("VillageHorse")
	var actor: CharacterBody3D = world.get_node("Player")
	if horse == null:
		push_error("HORSE STABLE BLOCKED: horse did not spawn")
		quit(1)
		return
	actor.global_position = horse.global_position + Vector3(0,1.0,2.0)
	for i in 3: await physics_frame
	var expect_stolen: bool = horse.get_meta("owner", "") != "Arjun"
	if not horse.can_board(actor) or not horse.board(actor) or horse.stolen != expect_stolen:
		push_error("HORSE STABLE BLOCKED: stable horse cannot be taken")
		quit(1)
		return
	if horse.get_node_or_null("HorseVoice") == null or horse.get_node_or_null("TackSound") == null or horse.get_node_or_null("LandingSound") == null:
		push_error("HORSE STABLE BLOCKED: required horse sounds missing")
		quit(1)
		return
	for i in 110: await physics_frame
	if horse.transition != "" or actor.global_position.distance_to(horse.seat_world()) > 1.0:
		push_error("HORSE STABLE BLOCKED: mount transition did not reach saddle")
		quit(1)
		return
	if horse.rigged_anim == null or horse.rigged_model.find_child("Skeleton3D",true,false) == null or horse.rigged_anim.current_animation != "AnimalArmature|Idle":
		push_error("HORSE STABLE BLOCKED: rigged body or idle animation missing")
		quit(1)
		return
	if horse.MAX_STAMINA <= actor.survival.max_stamina or horse.GALLOP_SPEED <= actor.sprint_speed:
		push_error("HORSE STABLE BLOCKED: horse endurance or gallop speed does not exceed Arjun's")
		quit(1)
		return
	for i in 30: await process_frame
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	for side in ["l","r"]:
		var hand: int = visual.skeleton.find_bone("hand_"+side)
		var foot: int = visual.skeleton.find_bone("foot_"+side)
		var palm: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(hand) * visual.equipment.palm_offsets[side])
		var boot: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(foot).origin)
		if palm.distance_to(horse.riding_rein_world(side)) > .14 or boot.distance_to(horse.stirrup_world(side)) > .14:
			push_error("HORSE STABLE BLOCKED: mounted hand/rein or foot/stirrup alignment")
			quit(1)
			return
	var before: Vector3 = horse.global_position
	Input.action_press("move_forward")
	for i in 120: await physics_frame
	Input.action_release("move_forward")
	if before.distance_to(horse.global_position) < 4.0 or (expect_stolen and horse.global_position.z < 198.5):
		var blockers: Array[String] = []
		for index in horse.get_slide_collision_count():
			var collider = horse.get_slide_collision(index).get_collider()
			if collider is Node: blockers.append(str(collider.get_path()))
		push_error("HORSE STABLE BLOCKED: ride-away %s → %s, pace %.2f, cinematic %s, collisions %s" % [before, horse.global_position, horse.pace, actor.get_meta("story_cinematic", false), blockers])
		quit(1)
		return
	if horse.hoof_events < 3:
		push_error("HORSE STABLE BLOCKED: gait did not trigger hoof sounds")
		quit(1)
		return
	if horse.rigged_anim.current_animation != "AnimalArmature|Walk":
		push_error("HORSE STABLE BLOCKED: rigged walk animation did not play")
		quit(1)
		return
	var arjun_stamina: float = actor.survival.stamina
	var horse_stamina: float = horse.stamina
	Input.action_press("sprint")
	Input.action_press("move_forward")
	for i in 90: await physics_frame
	Input.action_release("move_forward")
	Input.action_release("sprint")
	if horse.pace <= actor.sprint_speed or horse.stamina >= horse_stamina or actor.survival.stamina < arjun_stamina - .1:
		push_error("HORSE STABLE BLOCKED: gallop speed or independent stamina drain")
		quit(1)
		return
	if horse.rigged_anim.current_animation != "AnimalArmature|Gallop":
		push_error("HORSE STABLE BLOCKED: rigged gallop animation did not play")
		quit(1)
		return
	Input.action_press("jump")
	for i in 3: await physics_frame
	Input.action_release("jump")
	if horse.velocity.y <= 0.0:
		push_error("HORSE STABLE BLOCKED: jump did not lift horse")
		quit(1)
		return
	var airborne_hoofs: int = horse.hoof_events
	for i in 8: await physics_frame
	if horse.hoof_events != airborne_hoofs:
		push_error("HORSE STABLE BLOCKED: hoofbeat played while airborne")
		quit(1)
		return
	for i in 90: await physics_frame
	if horse.landing_events < 1:
		push_error("HORSE STABLE BLOCKED: landing sound did not trigger")
		quit(1)
		return
	if not horse.dismount():
		push_error("HORSE STABLE BLOCKED: could not dismount")
		quit(1)
		return
	for i in 50: await physics_frame
	if horse.rider != null or actor.has_meta("mounted_vehicle"):
		push_error("HORSE STABLE BLOCKED: dismount transition did not clear rider")
		quit(1)
		return
	var road_x: float = world.layout.road_x(210.0)
	horse.global_position = Vector3(road_x,world.layout.height(road_x,210.0)+.15,210.0)
	for i in 3: await physics_frame
	if horse.ground_sound_surface() != "road":
		push_error("HORSE STABLE BLOCKED: packed road did not select road hoof sound")
		quit(1)
		return
	horse._hoof_sound()
	if horse.hoof_players[(horse.hoof_events-1) % horse.hoof_players.size()].stream != horse.HoofRoadRecordedA and horse.hoof_players[(horse.hoof_events-1) % horse.hoof_players.size()].stream != horse.HoofRoadRecordedB:
		push_error("HORSE STABLE BLOCKED: road did not use recorded pavement hoof")
		quit(1)
		return
	var bridge: Node3D = world.get_node("TimberBridge")
	horse.global_position = Vector3(bridge.global_position.x,bridge.deck_height+.15,165.0)
	for i in 3: await physics_frame
	if horse.ground_sound_surface() != "timber":
		push_error("HORSE STABLE BLOCKED: bridge deck did not select timber hoof sound")
		quit(1)
		return
	print("HORSE STABLE: PASS | mount, tack, rigged idle/walk/gallop, speed, horse stamina, jump landing, dismount, surface sounds")
	quit()
