extends "res://combat/npc_vitality.gd"
## Silent paired mission takedown: other sentries still detect the action normally.
func receive_hit(amount: float,attacker: Node,kind: String="weapon") -> bool:
 if kind!="silent_takedown":return super.receive_hit(amount,attacker,kind)
 if dead or attacker==null or attacker.name!="Player":return false
 health=0;dead=true;actor.set_meta("dead",true);actor.set_meta("knocked_out",false);actor.movement_enabled=false;actor.combat_react("fall");actor.get_node("BodyCollider/BodyShape").set_deferred("disabled",true);died.emit();return true
