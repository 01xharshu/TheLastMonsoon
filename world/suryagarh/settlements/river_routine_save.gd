extends RefCounted
static func collect(world: Node) -> Dictionary:
	var states := {}
	for routine in world.get_tree().get_nodes_in_group("village_river_routine"):
		if world.is_ancestor_of(routine): states[str(world.get_path_to(routine))]=routine.export_state()
	return states
static func restore(world: Node, states: Dictionary) -> void:
	for routine in world.get_tree().get_nodes_in_group("village_river_routine"):
		if world.is_ancestor_of(routine): routine.restore_state(states.get(str(world.get_path_to(routine)),{}))
