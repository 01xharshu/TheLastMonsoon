extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://world/suryagarh/suryagarh_world.tscn")
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	for i in 12: await physics_frame
	var horse: CharacterBody3D = world.get_node_or_null("VillageHorse")
	var actor: CharacterBody3D = world.get_node("Player")
	if horse == null:
		push_error("HORSE STABLE BLOCKED: horse did not spawn")
		quit(1)
		return
	actor.global_position = horse.global_position + Vector3(0,1.0,2.0)
	for i in 3: await physics_frame
	if not horse.can_board(actor) or not horse.board(actor) or not horse.stolen:
		push_error("HORSE STABLE BLOCKED: stable horse cannot be taken")
		quit(1)
		return
	if horse.get_node_or_null("HorseVoice") == null or horse.get_node_or_null("TackSound") == null or horse.get_node_or_null("LandingSound") == null:
		push_error("HORSE STABLE BLOCKED: required horse sounds missing")
		quit(1)
		return
	for i in 50: await physics_frame
	if horse.transition != "" or actor.global_position.distance_to(horse.seat_world()) > 1.0:
		push_error("HORSE STABLE BLOCKED: mount transition did not reach saddle")
		quit(1)
		return
	for i in 30: await process_frame
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	for side in ["l","r"]:
		var sign_side: float = -1.0 if side=="l" else 1.0
		var hand: int = visual.skeleton.find_bone("hand_"+side)
		var foot: int = visual.skeleton.find_bone("foot_"+side)
		var hand_at: Vector3 = horse.to_local(visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(hand).origin))
		var foot_at: Vector3 = horse.to_local(visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(foot).origin))
		if hand_at.distance_to(Vector3(sign_side*.38,2.21,-.29)) > .14 or foot_at.distance_to(Vector3(sign_side*.48,1.38,.21)) > .14:
			push_error("HORSE STABLE BLOCKED: mounted hand/rein or foot/stirrup alignment")
			quit(1)
			return
	var before: Vector3 = horse.global_position
	Input.action_press("move_forward")
	for i in 120: await physics_frame
	Input.action_release("move_forward")
	if before.distance_to(horse.global_position) < 4.0 or horse.global_position.z < 198.5:
		push_error("HORSE STABLE BLOCKED: horse did not leave stable through open front")
		quit(1)
		return
	if horse.hoof_events < 3:
		push_error("HORSE STABLE BLOCKED: gait did not trigger hoof sounds")
		quit(1)
		return
	for clearance in horse.hoof_clearances:
		if clearance < -.04 or clearance > .17:
			push_error("HORSE STABLE BLOCKED: moving hoof lost ground clearance (%0.3f m)" % clearance)
			quit(1)
			return
	Input.action_press("jump")
	for i in 3: await physics_frame
	Input.action_release("jump")
	if horse.velocity.y <= 0.0:
		push_error("HORSE STABLE BLOCKED: jump did not lift horse")
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
	var bridge: Node3D = world.get_node("TimberBridge")
	horse.global_position = Vector3(bridge.global_position.x,bridge.deck_height+.15,165.0)
	for i in 3: await physics_frame
	if horse.ground_sound_surface() != "timber":
		push_error("HORSE STABLE BLOCKED: bridge deck did not select timber hoof sound")
		quit(1)
		return
	print("HORSE STABLE: PASS | mount, tack alignment, stable exit, gait/hoof clearance, jump landing, dismount, road and timber sounds")
	quit()
