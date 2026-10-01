extends Node
## Drives the live player from each surveyed approach to the building entrance.

const Layout = preload("res://world/suryagarh/landscape_layout.gd")
var failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _walk(player: CharacterBody3D, label: String, start: Vector2, target_z: float, frames: int) -> void:
	var layout := Layout.new()
	player.global_position = Vector3(start.x, layout.height(start.x,start.y) + 1.05, start.y)
	player.velocity = Vector3.ZERO
	player.get_node("CameraPivot").global_rotation.y = 0.0
	for i in 12: await get_tree().physics_frame
	var beginning := player.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for i in frames: await get_tree().physics_frame
	Input.action_release("move_forward")
	Input.action_release("sprint")
	for i in 8: await get_tree().physics_frame
	var end := player.global_position
	var ok := end.z <= target_z and absf(end.x - start.x) < 2.0 and end.y > layout.height(end.x,end.z) - 0.5
	print(("PASS " if ok else "FAIL "),label," from=",beginning," to=",end," target_z=",target_z)
	if not ok: failures.append(label)

func _run() -> void:
	var world := preload("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	var player: CharacterBody3D = world.get_node("Player")
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 12: await get_tree().physics_frame
	await _walk(player,"Town Hall road to porch",Vector2(-320,-432),-451.0,340)
	await _walk(player,"Police road to porch",Vector2(320,150),131.0,340)
	await _walk(player,"Government House gate to portico",Vector2(-390,-20),-93.0,1100)
	print("BUILDING APPROACHES ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
