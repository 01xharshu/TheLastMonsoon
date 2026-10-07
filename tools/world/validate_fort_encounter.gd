extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var fort: Node3D = load("res://world/ruined_fort/ruined_fort.tscn").instantiate()
	root.add_child(fort)
	for frame in range(6): await physics_frame
	var encounter := fort.get_node("Gameplay/FortEncounter")
	assert(encounter.activated and encounter.guards.size() == 4,"Garrison failed to activate")
	assert(not encounter.chest.interaction_available(),"Chest unlocked before garrison cleared")
	for guard in encounter.guards:
		var actor: Node3D = guard.actor
		assert(actor.animation_tree != null and actor.animation_tree.active,"Guard AnimationTree inactive")
		assert(actor.get_node_or_null("CombatMotion") != null,"Guard lacks combat transitions")
		assert(actor.get_node("Vitality").health == 75)
		assert(actor.find_children("*","Skeleton3D",true,false).size() == 1)
	var first: Dictionary = encounter.guards[0]
	first.actor.get_node("Vitality").receive_hit(100,encounter.player,"kick")
	assert(first.actor.get_meta("knocked_out",false),"Nonlethal defeat did not resolve")
	for index in range(1,4): encounter.guards[index].actor.get_node("Vitality").receive_hit(100,encounter.player,"gun")
	assert(encounter.is_cleared() and encounter.chest.interaction_available(),"Cleared garrison did not unlock supplies")
	var state: Dictionary = encounter.export_state()
	assert(state.guards.size() == 4 and state.guards[0].defeated)
	encounter.restore_state(state)
	await process_frame
	encounter.activate()
	assert(encounter.guards.is_empty() and encounter.is_cleared(),"Defeated guards respawned after restore")
	encounter.restore_state({"completed":true})
	assert(encounter.chest.opened and not encounter.chest.interaction_available(),"Completed objective paid again")
	print("FORT ENCOUNTER PASS | 4 MPFB rigs/trees | lethal/nonlethal clearance | chest gating | save restore")
	quit()
