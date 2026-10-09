extends SceneTree

class TestDoor extends Node:
	var manual_locked := false
	var night_lock := true
	var always_open := false
	var locked := false
	var opened := false
	var swing_direction := 1.0
	func hours_allow_entry(hour: int) -> bool:
		return hour >= 6 and hour < 20
	func restore_state(value: bool) -> void:
		opened = value

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var clock := GameTimeSystem.new()
	clock.name = "GameTimeSystem"
	world.add_child(clock)
	clock.set_process(false)
	var door := TestDoor.new()
	door.name = "Door"
	world.add_child(door)
	door.add_to_group("house_doors")
	var saves := root.get_node("SaveManager")
	var failures: Array[String] = []
	for hour in [12,22]:
		clock.current_hour = hour
		for manual in [false,true]:
			saves._restore_door_states(world,{"Door":{"opened":false,"manual_locked":manual,"swing_direction":-1.0}})
			if door.locked != (manual or hour == 22) or door.manual_locked != manual or door.opened or door.swing_direction != -1.0:
				failures.append("Door lock restoration failed at hour %d, manual %s" % [hour,manual])
	saves._restore_door_states(world,{"Door":true})
	if not door.opened: failures.append("Legacy boolean door state failed")
	for failure in failures: push_error(failure)
	print("DOOR SAVE CLOCK: ","PASS" if failures.is_empty() else "FAIL")
	world.queue_free()
	await process_frame
	await saves.quit_game(0 if failures.is_empty() else 1)
