extends Node
## Exercises the live player E route and movement through the estate gate.
var world: Node3D
var player: CharacterBody3D
var gate: Interactable
var failures: Array[String] = []
var checks: Array[Dictionary] = []

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"check":label,"pass":ok})
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)

func place(z: float, yaw: float) -> void:
	player.global_position = Vector3(-390,9.7,z)
	player.velocity = Vector3.ZERO
	player.get_node("CameraPivot").global_rotation.y = yaw
	player.get_node("VisualRoot").global_rotation.y = yaw + PI
	for i in 12: await get_tree().physics_frame

func press_e() -> void:
	check(player._find_interactable() == gate,"normal interaction selects gate")
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventAction.new()
	event.action = "interact"
	event.pressed = false
	Input.parse_input_event(event)
	for i in 150: await get_tree().physics_frame

func walk(yaw: float, target_z: float, maximum_frames: int) -> void:
	player.get_node("CameraPivot").global_rotation.y = yaw
	Input.action_press("move_forward")
	for i in maximum_frames:
		await get_tree().physics_frame
		if (yaw == 0.0 and player.global_position.z <= target_z) or (yaw != 0.0 and player.global_position.z >= target_z): break
	Input.action_release("move_forward")
	for i in 8: await get_tree().physics_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.global_position = Vector3(-377,15,-4)
	camera.look_at(Vector3(-390,11,-18))
	camera.make_current()
	for i in 5: await get_tree().process_frame
	RenderingServer.force_draw(false)
	get_tree().root.get_texture().get_image().save_png("res://docs/world/captures/government_gate_"+label+".png")
	camera.queue_free()
	player.get_node("CameraPivot/SpringArm3D/Camera3D").make_current()

func _run() -> void:
	world = preload("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	player = world.get_node("Player")
	gate = world.get_node("Settlement/GovernmentHouse/FortEntranceGate")
	var clock: GameTimeSystem = world.get_node("GameTimeSystem")
	clock.clock_paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 12: await get_tree().physics_frame
	gate.restore_state(false)
	await place(-15.6,0.0)
	await press_e()
	check(gate.opened and is_equal_approx(gate.swing,1.0),"daytime E opens both leaves")
	await capture("open")
	await walk(0.0,-124,1900)
	check(player.global_position.z <= -124 and absf(player.global_position.x+390)<1.0,"outside gate to portico on foot")
	await walk(PI,-15,1900)
	check(player.global_position.z >= -15,"portico to outside gate on foot")
	clock.advance_minutes(900)
	for i in 150: await get_tree().physics_frame
	check(gate.locked and not gate.opened and is_zero_approx(gate.swing),"21:00 closes and latches gate")
	await place(-15.6,0.0)
	await press_e()
	check(not gate.opened,"outside E cannot release night latch")
	await walk(0.0,-20,120)
	check(player.global_position.z > -18,"closed gate physically stops outside player")
	await capture("night_locked")
	await place(-20.4,PI)
	await press_e()
	check(gate.opened and gate.locked,"inside E releases gate for night exit")
	await walk(PI,-15,160)
	check(player.global_position.z >= -15,"night exit through opened gate")
	gate.restore_state(false)
	clock.advance_minutes(540)
	for i in 150: await get_tree().physics_frame
	check(not gate.locked and gate.opened,"06:00 restores gate access")
	var file := FileAccess.open("res://docs/world/government_gate_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"display_server":DisplayServer.get_name()},"\t")+"\n")
	print("GOVERNMENT GATE ","PASS" if failures.is_empty() else "FAIL")
	get_tree().quit(0 if failures.is_empty() else 1)
