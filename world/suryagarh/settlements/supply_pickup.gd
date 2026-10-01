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
	var owner: Node = get_parent()
	while owner != null and owner.name != "DistrictPolice": owner=owner.get_parent()
	if owner != null: get_tree().call_group("police_crime_observers","report_crime",actor,"theft",global_position)
	queue_free()
