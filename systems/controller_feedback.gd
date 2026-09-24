extends Node
## Capability-checked controller feedback. Never required for gameplay input.
const PATTERNS := {
	"shot": Vector3(0.65, 0.9, 0.18),
	"bow": Vector3(0.35, 0.28, 0.13),
	"melee": Vector3(0.24, 0.46, 0.12),
	"land": Vector3(0.16, 0.30, 0.10),
	"jump": Vector3(0.10, 0.17, 0.08),
	"water": Vector3(0.14, 0.10, 0.12),
	"interaction": Vector3(0.12, 0.10, 0.07),
	"mount": Vector3(0.24, 0.32, 0.15),
	"menu": Vector3(0.08, 0.06, 0.05),
}
var _last_pulse_ms := 0
var _light_elapsed := 0.0
var _last_light := Color.BLACK

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.input_device_changed.connect(_on_device_changed)
	Input.joy_connection_changed.connect(_on_connection_changed)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A,JOY_BUTTON_B]:
		var focus := get_viewport().gui_get_focus_owner()
		if focus and focus.is_visible_in_tree(): pulse("menu")

func usable_device() -> int:
	var device: int = SaveManager.active_joypad_id
	if SaveManager.active_input_device != "controller" or device not in Input.get_connected_joypads(): return -1
	return device

func pulse(kind: String) -> void:
	var device := usable_device()
	if device < 0 or not PATTERNS.has(kind) or not Input.has_joy_vibration(device): return
	var amount := clampf(float(SaveManager.options.get("vibration",0.65)),0.0,1.0)
	if amount <= 0.0: return
	var now := Time.get_ticks_msec()
	if now - _last_pulse_ms < 45 and kind != "shot": return
	_last_pulse_ms = now
	var pattern: Vector3 = PATTERNS[kind]
	Input.start_joy_vibration(device,pattern.x * amount,pattern.y * amount,pattern.z)

func stop() -> void:
	for device in Input.get_connected_joypads():
		if Input.has_joy_vibration(device): Input.stop_joy_vibration(device)

func _on_device_changed(device: String) -> void:
	if device != "controller":
		stop()
		for pad in Input.get_connected_joypads():
			if Input.has_joy_light(pad): Input.set_joy_light(pad,Color.BLACK)
	_update_light(true)

func _on_connection_changed(_device: int, connected: bool) -> void:
	if not connected: stop()
	_update_light(true)

func _process(delta: float) -> void:
	_light_elapsed += delta
	if _light_elapsed >= 0.35:
		_light_elapsed = 0.0
		_update_light()

func _update_light(force: bool = false) -> void:
	var device := usable_device()
	if device < 0 or not Input.has_joy_light(device): return
	var color := Color.BLACK
	if bool(SaveManager.options.get("controller_light",true)):
		color = Color(0.14,0.34,0.54)
		var world := get_tree().current_scene
		if world and world.has_node("Player/SurvivalComponent"):
			var survival: Node = world.get_node("Player/SurvivalComponent")
			var ratio: float = minf(float(survival.stamina) / maxf(float(survival.max_stamina),1.0), float(survival.hydration) / maxf(float(survival.max_hydration),1.0))
			if ratio < 0.25: color = Color(0.65,0.06,0.04)
			elif ratio < 0.5: color = Color(0.58,0.26,0.04)
	if force or color != _last_light:
		Input.set_joy_light(device,color)
		_last_light = color

func can_calibrate_gyro() -> bool:
	var device := usable_device()
	return device >= 0 and Input.has_joy_motion_sensors(device)

func capability_summary() -> String:
	var device := usable_device()
	if device < 0: return "No active controller connected"
	var features: Array[String] = []
	if Input.has_joy_vibration(device): features.append("rumble")
	if Input.has_joy_light(device): features.append("light")
	if Input.has_joy_motion_sensors(device): features.append("motion")
	return "%s · %s" % [Input.get_joy_name(device), ", ".join(features) if not features.is_empty() else "standard buttons"]

func calibrate_gyro() -> bool:
	if not can_calibrate_gyro(): return false
	var device := usable_device()
	Input.set_joy_motion_sensors_enabled(device,true)
	Input.start_joy_motion_sensors_calibration(device)
	await get_tree().create_timer(1.0,true).timeout
	if device not in Input.get_connected_joypads(): return false
	Input.stop_joy_motion_sensors_calibration(device)
	return Input.is_joy_motion_sensors_calibrated(device)
