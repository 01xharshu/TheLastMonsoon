extends Node3D
const Door = preload("res://objects/hinged_door.gd")
class Builder extends "res://world/suryagarh/settlements/settlement_builder.gd":
	func _ready() -> void: pass
func _ready() -> void: run.call_deferred()
func run() -> void:
	var world := Node3D.new()
	add_child(world)
	var door := Door.new()
	door.opened = false
	door.position = Vector3(2,0,3)
	door.build(StandardMaterial3D.new())
	door.rotation.y = PI*.5
	world.add_child(door)
	await get_tree().physics_frame
	assert(door.is_inside(door.to_global(Vector3(0,0,-1))))
	assert(not door.is_inside(door.to_global(Vector3(0,0,1))))
	door._time_changed(1,22,0)
	assert(door.locked)
	door.restore_state(true)
	door._time_changed(1,22,1)
	assert(door.opened and not door.moving)
	door.restore_state(false)
	door._time_changed(2,6,0)
	assert(not door.locked and door.moving)
	for frame in 90: await get_tree().physics_frame
	assert(door.opened and not door.moving)
	var gate := Door.new()
	var gate_floor := StaticBody3D.new()
	gate_floor.position = Vector3(9,-0.1,3)
	var gate_floor_shape := CollisionShape3D.new()
	gate_floor_shape.shape = BoxShape3D.new()
	gate_floor_shape.shape.size = Vector3(8,0.2,8)
	gate_floor.add_child(gate_floor_shape)
	world.add_child(gate_floor)
	gate.name = "ExteriorLatchGate"
	gate.position = Vector3(9,0,3)
	gate.opened = false
	gate.night_lock = false
	gate.outside_latch_access = true
	gate.auto_close_delay = 0.5
	gate.label_name = "gate"
	gate.build(StandardMaterial3D.new())
	world.add_child(gate)
	var game_clock := GameTimeSystem.new()
	game_clock.name = "GameTimeSystem"
	world.add_child(game_clock)
	var player: CharacterBody3D = load("res://player/player.tscn").instantiate()
	world.add_child(player)
	player.set_meta("mounted_vehicle", null)
	player.set_physics_process(false)
	player.global_position = gate.to_global(Vector3(0,0.9,1.15))
	player.visual_root.global_rotation.y = PI
	for frame in 8: await get_tree().physics_frame
	assert(not gate.is_inside(player.global_position))
	assert(player._find_interactable() == gate, "Exterior gate did not receive player targeting")
	var lock_press := InputEventKey.new()
	lock_press.physical_keycode = KEY_F
	lock_press.pressed = true
	player._unhandled_input(lock_press)
	assert(gate.locked and gate.manual_locked, "Exterior lock did not engage")
	var open_press := InputEventKey.new()
	open_press.physical_keycode = KEY_E
	open_press.pressed = true
	player._unhandled_input(open_press)
	for frame in 300:
		await get_tree().physics_frame
		if gate.opened and not gate.moving: break
	assert(gate.opened, "Exterior latch did not reopen the locked gate")
	for frame in 130: await get_tree().physics_frame
	assert(not gate.opened and gate.locked, "Open gate did not close and retain its exterior lock")
	var saved_doors: Dictionary = JSON.parse_string(JSON.stringify(SaveManager._door_states(world)))
	gate.manual_locked = false
	gate.locked = false
	SaveManager._restore_door_states(world,saved_doors)
	assert(gate.manual_locked and gate.locked and not gate.opened, "Serialized exterior lock did not restore")
	# Optional real slot I/O uses a caller-owned OS temporary directory.
	var slot_dir := OS.get_environment("TLM_GATE_SAVE_TEST_DIR")
	if not slot_dir.is_empty():
		var original_root: String = SaveManager.save_root
		SaveManager.save_root = slot_dir
		assert(SaveManager.save_game(world,1), "Gate fixture could not write a real save slot")
		var slot: Dictionary = SaveManager.read_slot(1)
		assert(not slot.is_empty(), "Gate fixture could not read its saved slot")
		gate.manual_locked = false
		gate.locked = false
		SaveManager._restore_door_states(world,slot.door_states)
		assert(gate.manual_locked and gate.locked and not gate.opened, "File-backed gate lock did not restore")
		SaveManager.save_root = original_root
		print("GATE SAVE SLOT: PASS | real slot write/read and lock restore")
	gate.manual_locked = false
	gate.night_lock = true
	gate._time_changed(1,22,0)
	assert(gate.locked, "Night gate did not latch")
	gate.interact(player)
	for frame in 300:
		await get_tree().physics_frame
		if gate.opened and not gate.moving: break
	assert(gate.opened, "Night-locked gate did not reopen from outside")
	player.queue_free()
	gate.queue_free()
	door.auto_open_at_dawn = false
	door.inside_only = true
	door.restore_state(false)
	door._time_changed(2,22,0)
	door.restore_state(true)
	door._time_changed(2,22,1)
	assert(door.opened and not door.moving)
	# A body occupying the normal opening arc must permit the other swing.
	door.restore_state(false)
	var blocker := CharacterBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = .28
	shape.height = 1.8
	collision.shape = shape
	blocker.add_child(collision)
	world.add_child(blocker)
	blocker.global_position = door.to_global(Vector3(.65,.95,.65))
	await get_tree().physics_frame
	await get_tree().physics_frame
	door.swing_direction = 1.0
	door.set_open(true)
	assert(door.moving and door.swing_direction == -1.0)
	for frame in 90: await get_tree().physics_frame
	assert(door.opened and not door.moving)
	var builder := Builder.new()
	world.add_child(builder)
	builder.plaster = StandardMaterial3D.new()
	builder.ochre = builder.plaster
	builder.wood = builder.plaster
	builder.iron = builder.plaster
	var home := builder.make_building("ShutterHome",Vector2(100,100),Vector2(6,6),false,false,false,true)
	var detail := preload("res://world/suryagarh/settlements/bhairavpur_house_detail.gd").new()
	var palette: Array[Material] = [builder.plaster]
	detail.configure(builder,palette)
	detail._openings(home,Vector2(6,6),1)
	assert(get_tree().get_nodes_in_group("climbable_windows").size() == 2)
	assert(home.has_node("TimberWindowFrameEast/PairedWoodShutters"))
	var courtyard_home := builder.make_building("CourtyardHome",Vector2(120,100),Vector2(6,6),false,false,false,true)
	detail.house(courtyard_home,Vector2(6,6),9)
	var placed_gate: Node = courtyard_home.get_node("CourtyardGate")
	assert(placed_gate.outside_latch_access and is_equal_approx(placed_gate.auto_close_delay,12.0), "Placed courtyard gate did not receive exterior latch and auto-close")
	print("ACCESS RECOVERY: PASS rotated inside/outside, exterior gate lock/reopen/auto-close/serialized restore, night egress, dawn unlock, shutter egress, alternate swing, actual shutter-home portals")
	world.queue_free()
	for frame in 3: await get_tree().physics_frame
	get_tree().quit()
