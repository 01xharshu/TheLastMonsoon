extends "res://world/suryagarh/combat_encounters.gd"
## Exercise production logic with existing rigged station actors, without building roads.
func _ready() -> void:
	player = get_parent().get_node("Player")
	station = get_parent().get_node("Settlement/DistrictPolice")
	add_to_group("police_crime_observers")
	set_process(false)
	set_physics_process(false)
