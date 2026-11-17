extends Interactable

const Salvage = preload("res://world/suryagarh/cart_salvage.gd")
var opened := false
var lid: Node3D

func _ready() -> void:
	interaction_text = "Search abandoned cart"
	interaction_icon = "loot"
	interaction_pose = "low_reach"
	interaction_max_distance = 2.25
	hold_duration = .9
	marker_height = .55
	add_to_group("treasure_chests")

func interaction_available() -> bool:
	return not opened and super.interaction_available()

func interact(actor: CharacterBody3D) -> void:
	if not interaction_available() or actor.global_position.distance_to(global_position) > interaction_max_distance:
		return
	var inventory := actor.get_node_or_null("InventoryComponent") as InventoryComponent
	if inventory == null: return
	var random := RandomNumberGenerator.new()
	random.randomize()
	var items := Salvage.roll(random)
	opened = true
	WorldAudio.play_at("chest_open", global_position)
	if is_instance_valid(lid):
		lid.create_tween().tween_property(lid, "rotation:x", 1.15, .35)
	var received := PackedStringArray()
	var found_goods := false
	for item: String in items:
		inventory.add_item(item, items[item])
		var item_name := Salvage.label(item)
		if item == "rupees" and items[item] == 1: item_name = "rupee"
		received.append("%d %s" % [items[item], item_name])
		found_goods = found_goods or Salvage.GOODS.has(item)
	var message := "Cart salvage · " + ", ".join(received)
	if found_goods: message += " · Sell at the merchant household"
	inventory.message_requested.emit(message)

func restore_opened() -> void:
	opened = true
	if is_instance_valid(lid): lid.rotation.x = 1.15
