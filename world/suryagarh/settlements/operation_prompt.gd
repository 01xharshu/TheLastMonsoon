extends Interactable
var operations: Node
var action_id := ""
var attendant: Node3D

func interaction_available() -> bool:
	return super.interaction_available() and is_instance_valid(operations) and (attendant == null or (is_instance_valid(attendant) and not attendant.get_meta("dead",false) and not attendant.get_meta("knocked_out",false)))

func interact(player: CharacterBody3D) -> void:
	if not interaction_available() or player.global_position.distance_to(global_position) > interaction_max_distance: return
	operations.request(action_id,player)
