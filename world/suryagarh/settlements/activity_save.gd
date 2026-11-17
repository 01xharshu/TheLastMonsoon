extends RefCounted
static func collect(world: Node) -> Dictionary:
	var result: Dictionary=world.get_meta("npc_activity_restore",{}).duplicate(true)
	for activity in world.get_tree().get_nodes_in_group("independent_npc_activities"):
		if world.is_ancestor_of(activity):result[str(world.get_path_to(activity))]=activity.export_state()
	return result
static func restore(world: Node, data: Dictionary) -> void:
	world.set_meta("npc_activity_restore",data.duplicate(true))
	for activity in world.get_tree().get_nodes_in_group("independent_npc_activities"):
		if world.is_ancestor_of(activity):activity.restore_state(data.get(str(world.get_path_to(activity)),{}))

static func apply_late(activity: Node) -> void:
	var world:=preload("res://systems/world_context.gd").find_world(activity)
	if world==null:return
	var data: Dictionary=world.get_meta("npc_activity_restore",{})
	activity.restore_state(data.get(str(world.get_path_to(activity)),{}))
