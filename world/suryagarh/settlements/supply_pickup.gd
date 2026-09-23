extends Interactable
@export var item_id := "paper_cartridges"
@export var count := 6
@export var display_name := "Paper cartridges · lead bullets"
var taken := false
func _ready() -> void:
	interaction_text = "Take " + display_name
	add_to_group("period_supplies")
func interact(actor: CharacterBody3D) -> void:
	if taken or actor.global_position.distance_to(global_position)>3.0: return
	if not actor.inventory.add_item(item_id,count): return
	taken = true
	actor.inventory.message_requested.emit("Acquired " + display_name)
	queue_free()
