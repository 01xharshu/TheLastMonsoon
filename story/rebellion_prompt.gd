extends Interactable
## Mission interaction uses the shared hold/proximity system.
var director: Node
var action_id := ""
func interaction_available() -> bool:
 return super.interaction_available() and is_instance_valid(director) and director.can_request(action_id)
func interact(actor: CharacterBody3D) -> void:
 if interaction_available() and actor.global_position.distance_to(global_position)<=interaction_max_distance:
  director.request(action_id,actor)
