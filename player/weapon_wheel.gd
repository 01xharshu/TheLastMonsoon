extends Control
## Hold the physical backtick/tilde key; pointer or arrows select; release commits.
const Equipment = preload("res://player/arjun_equipment.gd")
const SERIF = preload("res://assets/ui/fonts/CormorantGaramond.ttf")
const LABELS := ["TALWAR", "ENFIELD", "BOW", "PISTOL", "KNIFE", "DOUBLE GUN", "STOW WEAPONS"]
const DESCRIPTIONS := ["Curved sword", "Pattern 1853 rifle", "Bow and arrows", "Holstered sidearm", "Utility blade", "Two-barrel percussion sporting gun", "Hands free · weapons carried"]
const STOW_INDEX := 6
const IVORY := Color(0.93, 0.89, 0.78)
const BRASS := Color(0.67, 0.51, 0.29)
var actor: CharacterBody3D
var equipment: Node3D
var selected := 0
var previous_mouse_mode: Input.MouseMode
var previous_mouse_position := Vector2.ZERO
var previous_hud_visible := true

func _ready() -> void:
	name = "WeaponWheel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	hide()
	get_window().focus_exited.connect(_cancel)
	resized.connect(queue_redraw)

func open() -> void:
	if visible or actor.inventory_ui.is_open() or actor.get_meta("map_open", false) or (actor.has_meta("mounted_vehicle") and actor.get_meta("mounted_vehicle") != null) or actor.get_meta("climbing",false): return
	if not actor.is_physics_processing(): return
	selected = int(equipment.selected)
	previous_mouse_mode = Input.mouse_mode
	previous_mouse_position = get_viewport().get_mouse_position()
	actor.set_meta("weapon_wheel_open", true)
	previous_hud_visible = actor.get_node("UI/HUDRoot").visible
	actor.get_node("UI/HUDRoot").hide()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.warp_mouse(size * 0.5)
	queue_redraw()

func close(commit: bool) -> void:
	if not visible: return
	if commit:
		if selected == STOW_INDEX:
			equipment.stowed = true
			equipment._refresh()
		elif equipment.owns(selected):
			equipment.select_weapon(selected)
			# Swimming always wins over a wheel selection; selection is remembered.
			equipment.stowed = equipment.swimming or actor.is_swimming
			equipment._refresh()
	hide()
	actor.set_meta("weapon_wheel_open", false)
	actor.get_node("UI/HUDRoot").visible = previous_hud_visible
	Input.mouse_mode = previous_mouse_mode
	if previous_mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.warp_mouse(previous_mouse_position)

func _cancel() -> void:
	close(false)

func select_from_pointer(point: Vector2) -> void:
	var offset := point - size * 0.5
	if offset.length() < 82.0: return
	# Five evenly spaced sectors start at the top.
	selected = int(floor(fposmod(offset.angle() + PI / 2.0 + PI / LABELS.size(), TAU) / (TAU / LABELS.size())))
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("weapon_wheel") and not event.is_echo():
		open()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released("weapon_wheel"):
		close(true)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		if SaveManager.active_input_device == "controller": return
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_QUOTELEFT or event.keycode == KEY_ASCIITILDE:
			if event.pressed and not event.echo:
				open()
			elif not event.pressed:
				close(true)
			get_viewport().set_input_as_handled()
			return
		if not visible: return
		if event.pressed:
			match key:
				KEY_ESCAPE:
					close(false)
				KEY_RIGHT, KEY_DOWN:
					selected = posmod(selected + 1, LABELS.size())
				KEY_LEFT, KEY_UP:
					selected = posmod(selected - 1, LABELS.size())
			queue_redraw()
	if visible:
		if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
			var direction := Input.get_vector("move_left","move_right","move_forward","move_backward")
			if direction.length() > 0.45:
				select_from_pointer(size * 0.5 + direction * 160.0)
		if event is InputEventMouseMotion: select_from_pointer(event.position)
		get_viewport().set_input_as_handled()

func _text(value: String, point: Vector2, font_size: int, color: Color = IVORY, serif: bool = false) -> void:
	var font: Font = SERIF if serif else ThemeDB.fallback_font
	var extent := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, point - Vector2(extent.x * 0.5, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _icon(slot: int, centre: Vector2, color: Color) -> void:
	if slot == 0:
		var blade := PackedVector2Array([centre+Vector2(-34,21),centre+Vector2(-17,6),centre+Vector2(0,-5),centre+Vector2(20,-14),centre+Vector2(43,-13)])
		draw_polyline(blade,color,5,true)
		draw_line(centre+Vector2(-24,17),centre+Vector2(-37,1),BRASS,4,true)
		draw_line(centre+Vector2(-35,22),centre+Vector2(-46,32),BRASS,7,true)
	elif slot == 1:
		draw_line(centre+Vector2(-46,16),centre+Vector2(48,-17),color,4,true)
		draw_polyline(PackedVector2Array([centre+Vector2(-48,21),centre+Vector2(-31,23),centre+Vector2(-20,7),centre+Vector2(20,-7)]),BRASS,8,true)
		draw_arc(centre+Vector2(-13,12),7,0,PI,16,color,2,true)
	elif slot == 2:
		draw_arc(centre+Vector2(8,0),30,-PI/2,PI/2,20,color,3,true)
		draw_line(centre+Vector2(8,-30),centre+Vector2(8,30),BRASS,2,true)
		draw_line(centre+Vector2(-22,0),centre+Vector2(37,0),color,2,true)
	elif slot == 3:
		draw_line(centre+Vector2(-32,-7),centre+Vector2(28,-7),color,7,true)
		draw_arc(centre+Vector2(-9,8),13,0,PI,14,BRASS,3,true)
	elif slot == 4:
		draw_line(centre+Vector2(-25,16),centre+Vector2(28,-16),color,5,true)
		draw_line(centre+Vector2(-30,19),centre+Vector2(-20,13),BRASS,8,true)
	elif slot == 5:
		draw_line(centre+Vector2(-34,-11),centre+Vector2(34,-11),color,3,true)
		draw_line(centre+Vector2(-34,-5),centre+Vector2(34,-5),color,3,true)
		draw_line(centre+Vector2(-24,-3),centre+Vector2(-34,13),BRASS,6,true)
	else:
		draw_arc(centre,25,0,TAU,48,color,2,true)
		draw_line(centre+Vector2(-17,17),centre+Vector2(17,-17),BRASS,3,true)

func _draw() -> void:
	if not visible: return
	var centre := size * 0.5
	var outer := minf(242.0, size.y * 0.35)
	var inner := 97.0
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.015,0.019,0.015,0.66))
	_text("ARJUN’S ARMAMENT",centre+Vector2(0,-outer-46),30,IVORY,true)
	for slot in LABELS.size():
		var angle := -PI/2 + slot*TAU/LABELS.size()
		var polygon := PackedVector2Array()
		for i in 41:
			var a := angle - PI/LABELS.size()+.018 + (TAU/LABELS.size()-.036)*i/40
			polygon.append(centre+Vector2.from_angle(a)*outer)
		for i in range(40,-1,-1):
			var a := angle - PI/LABELS.size()+.018 + (TAU/LABELS.size()-.036)*i/40
			polygon.append(centre+Vector2.from_angle(a)*inner)
		draw_colored_polygon(polygon,Color(0.23,0.19,0.115,0.98) if slot==selected else Color(0.047,0.059,0.047,0.97))
		polygon.append(polygon[0])
		draw_polyline(polygon,IVORY if slot==selected else BRASS,2 if slot==selected else 1,true)
		var point := centre + Vector2.from_angle(angle)*(inner+outer)*.5
		_icon(slot,point-Vector2(0,9),IVORY if slot==selected else Color(0.64,0.65,0.57))
		var available: bool = slot == STOW_INDEX or equipment.owns(slot)
		_text(LABELS[slot],point+Vector2(0,40),18,IVORY if available else BRASS,true)
		if not available: _text("FIND IN STORES",point+Vector2(0,59),11,BRASS)
	draw_circle(centre,inner-4,Color(0.027,0.038,0.030,0.98))
	_text(LABELS[selected],centre+Vector2(0,-6),19,IVORY,true)
	_text("RELEASE TO SELECT",centre+Vector2(0,17),10,BRASS)
	_text(DESCRIPTIONS[selected] if selected == STOW_INDEX or equipment.owns(selected) else "Find this weapon in a guarded store",centre+Vector2(0,outer+32),17)
	_text("Hold ~   ·   Move pointer or use arrow keys   ·   Esc cancels",centre+Vector2(0,outer+62),14)
	if actor.is_swimming:
		_text("Swimming — weapons stay stowed",centre+Vector2(0,outer+86),14,BRASS)
