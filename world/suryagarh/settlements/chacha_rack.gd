extends Interactable
## Family-owned stock stays visible and usable after collection.
var item_id := "talwar"
var display_name := "talwar"
func _ready() -> void:
	add_to_group("family_weapon_racks")
	interaction_text = "Collect / equip " + display_name
	interaction_icon = "weapon"
	hold_duration = .6
	marker_height = 0
	interaction_max_distance = 2.6
func interact(actor: CharacterBody3D) -> void:
	if actor.global_position.distance_to(global_position)>2.6: return
	if actor.get_meta("climbing",false) or (actor.has_meta("mounted_vehicle") and actor.get_meta("mounted_vehicle")!=null): return
	var kit: Node = actor.get_node_or_null("ChachaKit")
	if kit == null: return
	if item_id == "smoke_bomb":
		var count: int = int(actor.inventory.items.get(item_id,0))
		if count < 3: actor.inventory.add_item(item_id,3-count)
		actor.inventory.message_requested.emit("Smoke pouches replenished · B to throw")
		return
	if not actor.inventory.has_item(item_id): actor.inventory.add_item(item_id,1)
	kit.equip(item_id)
	actor.inventory.message_requested.emit("Equipped " + display_name)
