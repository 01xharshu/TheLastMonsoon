extends "res://combat/npc_vitality.gd"
## Consenting farm practice: no crime, death, bounty or lethal weapon damage.
func receive_hit(amount: float,attacker: Node,kind: String="weapon") -> bool:
 if attacker==null or attacker.name!="Player" or amount<=0:return false
 var lesson: Node=get_tree().root.find_child("DevStory",true,false)
 if lesson==null or not lesson.practice_allowed(actor,kind):return false
 actor.set_meta("training_hit",kind);actor.set_meta("training_hit_time",Time.get_ticks_msec())
 if kind=="takedown":
  actor.set_meta("knocked_out",true);actor.movement_enabled=false;actor.combat_react("fall")
 else:actor.combat_react("hit")
 return true
