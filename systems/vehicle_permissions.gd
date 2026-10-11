extends RefCounted
## Acquisition is persistent state; restore never publishes a new taking event.
static func lawful(vehicle: Node, actor: Node) -> bool:
	return vehicle.get_meta("player_owned",false) or str(vehicle.get_meta("owner","")) == "Arjun" or str(vehicle.get_meta("driver_permission","")) == str(actor.name)

static func take(vehicle: Node3D, actor: Node, offence: String) -> void:
	if actor.name != "Player": return
	if vehicle.get_meta("restore_in_progress",false): return
	if lawful(vehicle,actor): return
	if vehicle.get_meta("crime_taken",false): return
	vehicle.set_meta("crime_taken",true)
	for observer in vehicle.get_tree().get_nodes_in_group("police_crime_observers"):
		if observer.has_method("report_vehicle_theft"): observer.report_vehicle_theft(actor,vehicle,offence)

static func export_state(vehicle: Node) -> Dictionary:
	return {"crime_taken":bool(vehicle.get_meta("crime_taken",false)),"player_owned":bool(vehicle.get_meta("player_owned",false)),"owner":str(vehicle.get_meta("owner","")),"driver_permission":str(vehicle.get_meta("driver_permission",""))}

static func restore_state(vehicle: Node, state: Dictionary, legacy_driver := false) -> void:
	# Old occupied saves already acquired the vehicle, even without this field.
	vehicle.set_meta("crime_taken",bool(state.get("crime_taken",legacy_driver)))
	for key in ["player_owned","owner","driver_permission"]:
		if state.has(key): vehicle.set_meta(key,state[key])

static func reclaim(vehicle: Node) -> void:
	vehicle.set_meta("crime_taken",false)
	vehicle.set_meta("driver_permission","")
