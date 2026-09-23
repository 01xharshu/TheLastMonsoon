extends Node
@onready var actor: CharacterBody3D = get_parent()

func nearest_vehicle() -> Node3D:
	var closest: Node3D
	var distance: float = 5.0
	for vehicle in get_tree().get_nodes_in_group("mountable_vehicles"):
		var d: float = actor.global_position.distance_to(vehicle.seat_world())
		if d < distance and vehicle.can_board(actor):
			var query := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*0.3,vehicle.seat_world()+Vector3.UP*0.3)
			query.exclude = [actor.get_rid(),vehicle.get_rid()]
			if actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				closest = vehicle
				distance = d
	return closest

func try_toggle() -> bool:
	if actor.inventory_ui.is_open() or actor.get_meta("map_open",false) or actor.get_meta("weapon_wheel_open",false): return false
	var mounted: Node = (actor.get_meta("mounted_vehicle") if actor.has_meta("mounted_vehicle") else null)
	if is_instance_valid(mounted): return mounted.dismount()
	var vehicle := nearest_vehicle()
	return vehicle.board(actor) if vehicle else false

func _process(_delta: float) -> void:
	if actor.inventory_ui.is_open() or actor.get_meta("map_open",false) or actor.get_meta("weapon_wheel_open",false): return
	var mounted: Node = (actor.get_meta("mounted_vehicle") if actor.has_meta("mounted_vehicle") else null)
	if is_instance_valid(mounted):
		actor.secondary_interaction_label.text = "[F] Dismount " + ("horse" if mounted.is_in_group("horses") else "boat")
		actor.secondary_interaction_label.visible = true
	else:
		var nearby := nearest_vehicle()
		if nearby == null: return
		actor.secondary_interaction_label.text = "[F] Take horse" if nearby.is_in_group("horses") else "[F] Board river boat"
		actor.secondary_interaction_label.visible = true
