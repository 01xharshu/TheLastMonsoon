extends Interactable
var opened := false
func _ready() -> void:
	interaction_text = "Compound gate · barred from inside"
	interaction_icon = "gate"
	marker_height = 1.2
func interact(actor: CharacterBody3D) -> void:
	if actor.global_position.distance_to(global_position)>4.5: return
	if not opened and actor.global_position.z < global_position.z:
		actor.inventory.message_requested.emit("Barred inside · find a climbable wall")
		return
	opened = not opened
	collision_layer = 0 if opened else 1
	visible = not opened
	actor.inventory.message_requested.emit("Compound gate unbarred" if opened else "Gate barred")
