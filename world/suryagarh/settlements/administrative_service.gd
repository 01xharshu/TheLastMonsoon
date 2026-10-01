extends Interactable
## Local fictional office transactions, kept with the district for save/load.
var role := "petition"
var completed := false
var staff: Node3D
func _ready() -> void:
	add_to_group("administrative_services")
	marker_height = 1.1
	interaction_max_distance = 2.5
	refresh()
func refresh() -> void:
	interaction_text = {"petition":"File a petition", "court":"Register petition at court", "revenue":"Pay recorded revenue · 2 rupees"}[role] if not completed else "Ask about completed paperwork"
func interaction_available() -> bool:
	return super.interaction_available() and is_instance_valid(staff) and not staff.get_meta("dead",false)
func interact(player: CharacterBody3D) -> void:
	if not interaction_available() or player.global_position.distance_to(global_position) > 3.0: return
	var inventory = player.get_node("InventoryComponent")
	var time = get_tree().current_scene.find_child("GameTimeSystem",true,false)
	if time != null and (time.current_hour < 9 or time.current_hour >= 17):
		inventory.message_requested.emit("Office services reopen at 9 in the morning")
		return
	if completed:
		inventory.message_requested.emit("Your transaction is already recorded")
		return
	if role == "petition":
		inventory.add_item("petition_receipt",1)
	elif role == "court":
		if not inventory.has_item("petition_receipt"):
			inventory.message_requested.emit("Bring the Collectorate petition receipt")
			return
		inventory.remove_item("petition_receipt",1)
		inventory.add_item("court_receipt",1)
	else:
		if inventory.get_item_count("rupees") < 2:
			inventory.message_requested.emit("The recorded payment needs 2 rupees")
			return
		inventory.remove_item("rupees",2)
		inventory.add_item("revenue_receipt",1)
	completed = true
	refresh()
func export_state() -> Dictionary:
	return {"completed":completed}
func restore_state(data: Dictionary) -> void:
	completed = bool(data.get("completed",false))
	refresh()
