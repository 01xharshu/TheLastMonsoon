extends Control
## New-journey onboarding. The existing HUD remains the sole renderer of its stats.
const FONT = preload("res://assets/ui/fonts/MFBOldstyle-Regular.otf")
const COPY := [
	"Use %s to move forward.",
	"Use %s to move left, %s to move right, or %s to move backward.",
	"This is your map. It shows nearby roads, places and your destination. Press Escape to open the full map; press Escape again to return.",
	"Water: this diamond shows hydration. Drink from your water bag and refill it at a water source.",
	"Food: this diamond shows how well fed you are. Eat food from your satchel to restore it.",
	"Stamina: this diamond shows your remaining effort. Sprinting uses it; slow down to recover.",
	"Rest: this diamond shows your energy. Sleep on a charpai when you need rest.",
	"Vitality: this bar shows your health. Damage lowers it. Keep an eye on it during danger.",
	"Rupees: this is the money in your satchel. Work earns it; purchases spend it.",
	"The compass shows direction. Your weapon and ammunition appear when you carry them.",
	"Go to the marked horse beside the village house. Approach it and press %s to mount."]
var step := 11
var age := 0.0
var responded := false
var hud: Control
var player: CharacterBody3D
var map: Control
var prompt: Label
var horse: Node3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hud = get_parent()
	player = hud.player
	map = player.get_node("UI/WorldMap")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt = Label.new()
	prompt.position = Vector2(24,32)
	prompt.size = Vector2(430,120)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_font_override("font",FONT)
	prompt.add_theme_font_size_override("font_size",21)
	prompt.add_theme_color_override("font_color",Color(.96,.91,.77))
	prompt.add_theme_color_override("font_outline_color",Color(.025,.03,.025,.95))
	prompt.add_theme_constant_override("outline_size",6)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt)
	hide()

func key(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey: return (event.as_text_physical_keycode() if event.physical_keycode else event.as_text_keycode()).replace(" (Physical)","")
	return action.replace("_"," ")

func begin() -> void:
	restore_step(0)

func restore_step(value: int) -> void:
	step = clampi(value,0,11)
	player.set_meta("morning_tutorial_active",step < 11)
	_enter()

func _enter() -> void:
	age = 0.0
	responded = false
	player.set_meta("tutorial_reading",step >= 3 and step <= 9)
	_apply_reveal()
	visible = step < 11
	if step >= 11: return
	var text: String = COPY[step]
	if step == 0: text = text % key("move_forward")
	if step == 1: text = text % [key("move_left"),key("move_right"),key("move_backward")]
	if step == 10:
		text = text % key("interact")
		horse = player.get_parent().get_node_or_null("VillageHorse")
		if is_instance_valid(horse):
			map.follow_story = false
			map.selected_site = ""
			map.waypoint = Vector2(horse.global_position.x,horse.global_position.z)
	prompt.text = text

func _apply_reveal() -> void:
	hud.tutorial_reveal = step if step < 11 else 99
	hud.get_node("InteractionOverlay").visible = step >= 10
	if step < 10:
		for label_name in ["PrimaryInteractionLabel","SecondaryInteractionLabel","PickupMessageLabel"]:
			hud.get_node(label_name).hide()
	hud.weapon_label.visible = step >= 9
	hud.weapon_label.modulate.a = pulse(9)
	hud.money_label.visible = step >= 8
	hud.money_label.modulate.a = pulse(8)
	var rings: Array = [hud.get_node("SurvivalHUD/HydrationRing"),hud.get_node("SurvivalHUD/SatietyRing"),hud.get_node("SurvivalHUD/StaminaRing"),hud.get_node("SurvivalHUD/EnergyRing")]
	hud.get_node("SurvivalHUD").visible = step >= 3
	for i in rings.size():
		rings[i].visible = step >= 3+i
		rings[i].modulate.a = pulse(3+i)
	if is_instance_valid(map.minimap):
		map.minimap.visible = step >= 2
		map.minimap.modulate.a = pulse(2)
	hud.queue_redraw()

func _input(event: InputEvent) -> void:
	if step >= 11 or get_tree().paused or player.get_meta("opening_active",false): return
	if event is InputEventKey and event.echo: return
	if step == 0 and event.is_action_pressed("move_forward"):
		advance()
	elif step == 1 and (event.is_action_pressed("move_left") or event.is_action_pressed("move_right") or event.is_action_pressed("move_backward")):
		advance()
	elif step >= 3 and step <= 9:
		if event.is_pressed(): responded = true
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if step >= 11: return
	if player.get_meta("map_open",false):
		if step == 2: responded = true
		return
	if get_tree().paused: return
	age += delta
	_apply_reveal()
	if step >= 2 and step <= 9 and ((responded and age >= 5.0) or age >= 10.0): advance()
	if step == 10 and is_instance_valid(horse):
		var mount: Node = player.get_meta("mounted_vehicle") if player.has_meta("mounted_vehicle") else null
		if mount == horse: advance()

func advance() -> void:
	step += 1
	if step >= 11:
		player.set_meta("morning_tutorial_active",false)
		var inquiry := player.get_parent().get_node_or_null("DevInquiry")
		if inquiry != null: inquiry.begin()
		map.follow_story_destination()
	_enter()


func pulse(element: int) -> float:
	return 0.35+0.65*(sin(age*TAU*1.3)*.5+.5) if step == element else 1.0

func blink_on(element: int) -> bool:
	return step != element or fmod(age,0.8) < 0.55
