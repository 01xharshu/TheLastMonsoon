extends "res://combat/climbing_firearm_attack.gd"
## Evaluated by the mounted mission actor after the saddle/rein pose.
func can_engage() -> bool:
 return hostile and is_instance_valid(target) and target.health>0 and target.get_meta("consignment_rear_combat",false) and owner_actor.global_position.distance_to(target.global_position)<45

func turn_owner_to_target() -> bool:
 return false # Hips remain aligned to the saddle; the mounted actor aims its torso.
