extends "res://objects/hinged_door.gd"
## Strongroom remains locked from the public side; occupants retain egress.
var picking_actor: CharacterBody3D
var picking_remaining := 0.0

func _ready() -> void:
	super._ready()
	secondary_interaction_text = "Pick strongroom lock · requires lock tools"

func interact(player: CharacterBody3D) -> void:
	if player.global_position.distance_to(global_position) > interaction_max_distance: return
	var inventory: InventoryComponent = player.get_node("InventoryComponent")
	if inventory.has_item("treasury_key"):
		locked = false
		super.interact(player)
		return
	super.interact(player)

func secondary_interact(player: CharacterBody3D) -> void:
	if opened or moving or picking_remaining > 0 or player.health <= 0 or player.global_position.distance_to(global_position) > interaction_max_distance: return
	if not player.get_node("InventoryComponent").has_item("lock_tools"): return
	picking_actor = player
	picking_remaining = 8
	player.get_node("InventoryComponent").message_requested.emit("Working the lock — remain beside the door")

func _process(delta: float) -> void:
	if picking_remaining <= 0: return
	if not is_instance_valid(picking_actor) or picking_actor.health <= 0 or picking_actor.global_position.distance_to(global_position) > interaction_max_distance:
		picking_remaining = 0
		return
	picking_remaining -= delta
	if picking_remaining <= 0:
		if not picking_actor.get_node("InventoryComponent").has_item("lock_tools"): return
		locked = false
		super.interact(picking_actor)
		get_tree().call_group("police_crime_observers","report_crime",picking_actor,"theft",global_position)

func _time_changed(_day: int,_hour: int,_minute: int) -> void:
	locked = true
	_label()
func _label() -> void:
	interaction_text = "Treasury strongroom · staff access only" if not opened else "Close strongroom door"
