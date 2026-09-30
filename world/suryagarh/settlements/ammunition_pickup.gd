extends "res://world/suryagarh/settlements/supply_pickup.gd"
var supply_id := ""
func _ready() -> void:
	super._ready()
	interaction_text = "Take %s · %d" % [display_name, count]
	interaction_max_distance = 3.0
	marker_height = 0.12
	add_to_group("ammunition_pickups")
func persistence_id() -> String:
	return supply_id
