extends Node
## Actor-owned action leases complement legacy action state during migration.
var leases: Dictionary={}
var next_token:=0

static func install(actor: Node) -> Node:
	var service:=actor.get_node_or_null("ActionPermissions")
	if service==null:
		service=load("res://systems/action_permissions.gd").new()
		service.name="ActionPermissions"
		actor.add_child(service)
	return service

static func allowed(actor: Node, domain: StringName) -> bool:
	if actor.get_meta("tutorial_reading",false) or actor.get_meta("story_cinematic",false) or actor.get_meta("door_latch_active",false): return false
	if actor.get_meta("paired_combat",false) or actor.get_meta("document_busy",false): return false
	for key in ["rest_action","detention_action","river_action"]:
		if actor.get_meta(key,"")!="": return false
	if domain in [&"attack",&"board"]:
		for key in ["map_open","weapon_wheel_open","scroll_open","telescope_open"]:
			if actor.get_meta(key,false): return false
	var service:=actor.get_node_or_null("ActionPermissions")
	return service==null or service.domain_free(domain)

func acquire(owner_node: Node, domains: Array[StringName]) -> int:
	prune()
	for domain in domains:
		if not domain_free(domain): return -1
	next_token+=1
	leases[next_token]={"owner":weakref(owner_node),"domains":domains.duplicate()}
	return next_token

func release(token: int) -> void:
	leases.erase(token)

func prune() -> void:
	for token in leases.keys():
		var owner_node: Node=leases[token].owner.get_ref()
		if not is_instance_valid(owner_node) or not owner_node.is_inside_tree() or owner_node.is_queued_for_deletion(): leases.erase(token)

func domain_free(domain: StringName) -> bool:
	prune()
	for lease in leases.values():
		if domain in lease.domains: return false
	return true
