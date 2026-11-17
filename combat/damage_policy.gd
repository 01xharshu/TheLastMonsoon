extends RefCounted
## Shared damage permissions, including ordinary civilian assault reactions.
static func receiver(body: Object) -> Node:
	if body is Node and is_instance_valid(body.get("damage_receiver")):
		return body.get("damage_receiver")
	return body as Node

static func player_protected(actor: Node, attacker: Node, default_faction: String = "") -> bool:
	if attacker == null or attacker.name != "Player" or actor.get_meta("combat_faction", default_faction) != "indian":
		return false
	return actor.get_node_or_null("CivilianReaction") == null or actor.get_meta("mission_active", false) or actor.get_meta("external_combat_motion", false)

static func apply(body: Object, amount: float, attacker: Node, kind: String = "weapon", point := Vector3.INF, direction := Vector3.ZERO) -> bool:
	if not is_instance_valid(body) or not is_finite(amount) or amount <= 0.0: return false
	var target := receiver(body)
	if target == null: return false
	var actor: Node = target.get_parent() if target.name == "Vitality" else target
	if player_protected(actor, attacker): return false
	if actor is Node3D and point.is_finite():
		actor.set_meta("pending_impact_context",{"point":point,"direction":direction.normalized(),"kind":kind,"strength":clampf(amount/35.0,.25,1.0)})
	elif actor.has_meta("pending_impact_context"):
		actor.remove_meta("pending_impact_context")
	if target.has_method("receive_hit"):
		var accepted: bool=target.receive_hit(amount, attacker, kind)
		if actor.has_meta("pending_impact_context"):actor.remove_meta("pending_impact_context")
		return accepted
	if target.has_method("take_damage"):
		target.take_damage(amount)
		return true
	return false
