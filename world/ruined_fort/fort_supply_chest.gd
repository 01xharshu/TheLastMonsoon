extends "res://interaction/treasure_chest.gd"
var encounter: Node
func _ready() -> void:
	super._ready()
	interaction_text = "Recover fort supplies"
func interaction_available() -> bool:
	return encounter != null and encounter.is_cleared() and super.interaction_available()
func interact(actor: CharacterBody3D) -> void:
	if not interaction_available(): return
	super.interact(actor)
	if opened:
		encounter.completed = true
		actor.inventory.message_requested.emit("Fort secured · Supplies recovered")
