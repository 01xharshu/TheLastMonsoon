extends RefCounted
## Authored IDs survive reparenting; legacy paths remain a compatible fallback.
static func id_for(world: Node, entity: Node) -> String:
	var identity := str(entity.get_meta("entity_id",""))
	if identity.is_empty():
		identity="world:"+str(world.get_path_to(entity))
		entity.set_meta("entity_id",identity)
	return identity

static func index_group(world: Node, group: StringName) -> Dictionary:
	var result: Dictionary={}
	for entity in world.get_tree().get_nodes_in_group(group):
		if not world.is_ancestor_of(entity): continue
		var identity:=id_for(world,entity)
		if result.has(identity):
			push_error("Duplicate persistent entity ID: "+identity)
			continue
		result[identity]=entity
	return result

static func resolve(world: Node, state: Dictionary, index: Dictionary) -> Node:
	var identity:=str(state.get("entity_id",""))
	if index.has(identity): return index[identity]
	var legacy:=str(state.get("path",""))
	if legacy.is_empty() or legacy.begins_with("/") or ".." in legacy: return null
	return world.get_node_or_null(NodePath(legacy))
