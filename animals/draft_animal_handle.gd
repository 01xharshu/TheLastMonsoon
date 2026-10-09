extends Interactable
var animal:CharacterBody3D
func _ready()->void:
	interaction_text="Lead animal";hold_duration=.6;collision_layer=1;collision_mask=0
func interaction_available()->bool:
	return super.interaction_available() and animal.can_lead()
func interact(actor:CharacterBody3D)->void:
	if not interaction_available() or actor.global_position.distance_to(global_position)>3:return
	if animal.leader==actor:animal.leader=null;interaction_text="Lead animal";return
	for other in get_tree().get_nodes_in_group("draft_animals"):
		if other.leader==actor:other.leader=null
	animal.leader=actor;interaction_text="Release animal"
