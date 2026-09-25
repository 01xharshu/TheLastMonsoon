extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	for i in 12: await physics_frame
	var actor: CharacterBody3D = world.get_node("Player")
	var chest: Interactable = world.get_node("Settlement/ColonialCompound/SecludedSupplyChest")
	actor.global_position = chest.global_position + Vector3(0,1.0,2.1)
	actor.get_node("VisualRoot").rotation.y = PI
	for i in 8: await physics_frame
	if actor._find_interactable() != chest or actor.interaction_overlay.markers.has(chest) or not actor.interaction_overlay.marker_world_positions.has(chest):
		push_error("INTERACTION BLOCKED: near chest should show its selector without a world marker")
		quit(1)
		return
	actor._begin_interaction_hold(chest,"interact")
	Input.action_press("interact")
	for i in 25: await physics_frame
	if not actor.get_meta("interaction_reach",false) or actor.get_meta("interaction_pose_kind","") != "kneel" or actor.get_node("InteractionPoseComponent").amount < .1:
		push_error("INTERACTION BLOCKED: Arjun did not enter chest kneel")
		quit(1)
		return
	Input.action_release("interact")
	for i in 3: await physics_frame
	if chest.opened or actor.inventory.get_item_count("rupees") != 0:
		push_error("INTERACTION BLOCKED: canceled hold opened chest")
		quit(1)
		return
	actor._begin_interaction_hold(chest,"interact")
	Input.action_press("interact")
	for i in 85: await physics_frame
	Input.action_release("interact")
	if not chest.opened or actor.inventory.get_item_count("rupees") != 26 or actor.inventory.get_item_count("paper_cartridges") < 6 or actor.inventory.get_item_count("pistol_ball") < 4:
		push_error("INTERACTION BLOCKED: completed hold failed to grant supplies")
		quit(1)
		return
	if actor.get_meta("interaction_reach",false):
		push_error("INTERACTION BLOCKED: Arjun remained locked in kneel")
		quit(1)
		return
	if chest.interaction_available() or actor.interaction_overlay.rewards.size() != 3:
		push_error("INTERACTION BLOCKED: opened chest still prompts or reward notices missing")
		quit(1)
		return
	var mango: Interactable = load("res://objects/mango.gd").new()
	world.add_child(mango)
	mango.global_position = actor.global_position + Vector3(0,-.9,-.65)
	if mango.interaction_pose != "low_reach" or mango.hold_duration <= 0.0:
		push_error("INTERACTION BLOCKED: fallen mango missing low reach hold")
		quit(1)
		return
	chest.restore_opened()
	if not chest.opened or chest.lid.rotation.x < 1.0:
		push_error("INTERACTION BLOCKED: opened state did not restore")
		quit(1)
		return
	var saves: Node = root.get_node("SaveManager")
	saves.save_root = "user://codex_interaction_validation"
	if not saves.save_game(world,1):
		push_error("INTERACTION BLOCKED: chest state did not save")
		quit(1)
		return
	chest.opened = false
	chest.lid.rotation.x = 0.0
	saves.pending_slot = 1
	saves.apply_pending(world)
	if not chest.opened or chest.lid.rotation.x < 1.0 or actor.inventory.get_item_count("rupees") != 26:
		push_error("INTERACTION BLOCKED: chest state or rewards did not survive reload")
		quit(1)
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(1)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_root))
	print("INTERACTION CHEST: PASS | marker, canceled/restarted hold, rewards, saved opened state")
	quit()
