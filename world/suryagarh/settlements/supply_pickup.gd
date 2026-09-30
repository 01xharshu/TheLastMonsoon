extends Interactable
@export var item_id := "paper_cartridges"
@export var count := 6
@export var display_name := "Paper cartridges · lead bullets"
var taken := false
func _ready() -> void:
	interaction_text = "Take " + display_name
	interaction_icon = preload("res://interaction/item_catalog.gd").icon(item_id)
	hold_duration = .65
	add_to_group("period_supplies")
func interact(actor: CharacterBody3D) -> void:
	if taken or actor.global_position.distance_to(global_position)>3.0: return
	var already_owned: bool = actor.inventory.has_item(item_id)
	if not actor.inventory.add_item(item_id,count): return
	if not already_owned and item_id == "pistol":
		preload("res://player/ammunition_loadout.gd").grant_for_weapon(actor, item_id)
	taken = true
	queue_free()
