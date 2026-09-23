extends Control
## A drawn parchment and rollers keep the dossier independent of texture imports.
const FONT = preload("res://assets/ui/fonts/CormorantGaramond.ttf")
const INK := Color(0.23, 0.17, 0.10)
const BRASS := Color(0.48, 0.31, 0.13)
var player: CharacterBody3D
var opening := false
var progress := 0.0
var previous_mouse_mode := Input.MOUSE_MODE_CAPTURED
var previous_hud_visible := true

func _ready() -> void:
	player = get_parent().get_parent() as CharacterBody3D
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_O:
		if not opening and (player.inventory_ui.is_open() or player.get_meta("map_open", false) or player.get_meta("weapon_wheel_open", false)): return
		set_open(not opening)
		get_viewport().set_input_as_handled()
	elif opening and event.keycode == KEY_ESCAPE:
		set_open(false)
		get_viewport().set_input_as_handled()
	elif opening:
		get_viewport().set_input_as_handled()

func set_open(value: bool) -> void:
	if opening == value: return
	opening = value
	visible = true
	player.set_meta("scroll_open", value)
	if value:
		previous_mouse_mode = Input.mouse_mode
		previous_hud_visible = player.get_node("UI/HUDRoot").visible
		player.get_node("UI/HUDRoot").hide()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		player.get_node("UI/HUDRoot").visible = previous_hud_visible
		Input.mouse_mode = previous_mouse_mode
	queue_redraw()

func _process(delta: float) -> void:
	if not visible: return
	progress = move_toward(progress, 1.0 if opening else 0.0, delta * 2.3)
	if progress <= 0.0 and not opening:
		visible = false
	queue_redraw()

func _line(value: String, x: float, y: float, font_size: int = 24, color: Color = INK) -> void:
	draw_string(FONT, Vector2(x, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	if progress <= 0.0: return
	var ease := 1.0 - pow(1.0-progress, 3.0)
	var width := minf(size.x * 0.78, 710.0)
	var height := minf(size.y * 0.78, 580.0) * ease
	var rect := Rect2((size.x-width)*0.5, (size.y-height)*0.5, width, height)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,0.026,0.018,0.74*progress))
	draw_rect(rect.grow(10),Color(0.08,0.055,0.03,0.6))
	draw_rect(rect,Color(0.78,0.69,0.50))
	for i in 12:
		var stripe_y := rect.position.y + 19.0 + i*37.0
		if stripe_y < rect.end.y-10.0:
			draw_line(Vector2(rect.position.x+12,stripe_y),Vector2(rect.end.x-12,stripe_y),Color(0.52,0.41,0.24,0.08),1)
	for edge_y in [rect.position.y, rect.end.y]:
		draw_rect(Rect2(rect.position.x-19,edge_y-10,width+38,20),Color(0.30,0.18,0.09))
		draw_line(Vector2(rect.position.x-15,edge_y-7),Vector2(rect.end.x+15,edge_y-7),BRASS,2)
	if progress < 0.96: return
	var x := rect.position.x+47.0
	var y := rect.position.y+55.0
	_line("THE TRAVELLER'S RECORD",x,y,34)
	draw_line(Vector2(x,y+14),Vector2(rect.end.x-47,y+14),BRASS,2)
	_line("ARJUN",x,y+65,43)
	_line("A name carried from village to village",x,y+95,19)
	var fame: Node = player.get_node("FameComponent")
	_line("FAME    %d" % fame.points,x,y+148,31)
	_line("Trust grows through deeds. Renown draws watchful eyes.",x,y+175,19)
	var markers: Array[String] = fame.recognition_markers()
	_line("RECOGNITION    %s" % (", ".join(markers) if not markers.is_empty() else "Unknown"),x,y+207,18)
	var survival: Node = player.get_node("SurvivalComponent")
	_line("STRENGTH    %d / %d" % [roundi(survival.stamina),roundi(survival.max_stamina)],x,y+261,25)
	var character: Node = player.get_node("VisualRoot/CharacterVisual")
	var equipment: Node = character.equipment if character else null
	var held: String = equipment.held_name() if equipment else "STOWED"
	_line("WEAPONS    Talwar / Enfield / Bow / Adams",x,y+301,21)
	_line("IN HAND    %s" % held,x,y+324,19)
	_line("WOUNDS    Not yet tracked",x,y+353,23)
	_line("[ O ]   ROLL CLOSED",x,rect.end.y-39,18)
