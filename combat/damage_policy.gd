extends RefCounted
## Player weapons stop at friendly bodies without damaging or passing through them.
static func receiver(body: Object) -> Node:
	if body is Node and is_instance_valid(body.get("damage_receiver")):
		return body.get("damage_receiver")
	return body as Node

static func apply(body: Object, amount: float, attacker: Node, kind: String = "weapon") -> bool:
	if not is_instance_valid(body) or not is_finite(amount) or amount <= 0.0: return false
	var target := receiver(body)
	if target == null: return false
	var actor: Node = target.get_parent() if target.name == "Vitality" else target
	if attacker != null and attacker.name == "Player" and actor.get_meta("combat_faction", "") == "indian": return false
	if target.has_method("receive_hit"):
		return target.receive_hit(amount, attacker, kind)
	if target.has_method("take_damage"):
		target.take_damage(amount)
		return true
	return false
