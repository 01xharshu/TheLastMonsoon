extends Control
## A drawn parchment and rollers keep the dossier independent of texture imports.
const FONT = preload("res://assets/ui/fonts/MFBOldstyle-Regular.otf")
const INK := Color(0.23, 0.17, 0.10)
const BRASS := Color(0.48, 0.31, 0.13)
var player: CharacterBody3D
var opening := false
var progress := 0.0
var previous_mouse_mode := Input.MOUSE_MODE_CAPTURED
var previous_hud_visible := true
var motion: Node3D
var source_notice: Node3D
var content: ScrollContainer
var grid: GridContainer
var values: Dictionary = {}
var details: Dictionary = {}
var bars: Dictionary = {}
var refresh_elapsed := 0.0
var open_elapsed := 0.0
var snapshot := ""
var redraw_count := 0

func _ready() -> void:
	player = get_parent().get_parent() as CharacterBody3D
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	motion = preload("res://player/document_motion.gd").new()
	motion.name = "DocumentMotion"
	player.add_child.call_deferred(motion)
	_build_cards()

func _input(event: InputEvent) -> void:
	if not opening and is_instance_valid(motion) and motion.active:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("identity_scroll") and not event.is_echo():
		if not opening and not can_open(): return
		set_open(not opening)
		get_viewport().set_input_as_handled()
		return
	if opening and event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed:
		set_open(false)
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_O:
		if not opening and not can_open(): return
		set_open(not opening)
		get_viewport().set_input_as_handled()
	elif opening and event.keycode == KEY_ESCAPE:
		set_open(false)
		get_viewport().set_input_as_handled()
	elif opening:
		get_viewport().set_input_as_handled()

func can_open() -> bool:
	return not (player.inventory_ui.is_open() or player.get_meta("map_open",false) or player.get_meta("weapon_wheel_open",false) or player.get_meta("document_busy",false) or player.get_meta("climbing",false) or player.has_meta("mounted_vehicle") or player.get_meta("rest_action","") != "" or player.get_meta("river_action","") != "" or player.get_meta("stealth_stance","") != "" or player.first_person or player.health <= 0)

func open_notice(notice: Node3D) -> void:
	source_notice = notice
	set_open(true)

func set_open(value: bool) -> void:
	if opening == value: return
	if value and not can_open(): return
	WorldAudio.play_at("paper",player.global_position)
	opening = value
	visible = true
	player.set_meta("scroll_open", value or motion.active)
	if value:
		open_elapsed = 0.0
		motion.begin(source_notice)
		_refresh_cards()
		previous_mouse_mode = Input.mouse_mode
		previous_hud_visible = player.get_node("UI/HUDRoot").visible
		player.get_node("UI/HUDRoot").hide()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		motion.finish()
		player.get_node("UI/HUDRoot").visible = previous_hud_visible
		Input.mouse_mode = previous_mouse_mode
	queue_redraw()

func _process(delta: float) -> void:
	if not visible: return
	open_elapsed += delta
	var before := progress
	# Give the world motion time to reach and lift before presenting the cards.
	progress = move_toward(progress, 1.0 if opening and open_elapsed >= .65 else 0.0, delta * 2.3)
	content.visible = opening and progress >= .96
	if progress != before:
		_layout_cards()
		queue_redraw()
		redraw_count += 1
	refresh_elapsed += delta
	if opening and refresh_elapsed >= .25:
		refresh_elapsed = 0.0
		_refresh_cards()
	if progress <= 0.0 and not opening:
		visible = false
		source_notice = null

func _build_cards() -> void:
	content = ScrollContainer.new()
	content.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(content)
	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	content.add_child(grid)
	var icons := ["chest","coin","food","sword","medicine","ammo"]
	var titles := ["ARJUN","FAME","STRENGTH","WEAPONS","WOUNDS","NOTICES"]
	for i in titles.size():
		var title: String = titles[i]
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Color(.16,.125,.085)
		style.border_color = Color(.51,.37,.19)
		style.border_width_top = 3
		style.set_corner_radius_all(5)
		style.set_content_margin_all(12)
		style.shadow_color = Color(0,0,0,.24)
		style.shadow_size = 3
		panel.add_theme_stylebox_override("panel",style)
		grid.add_child(panel)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation",7)
		panel.add_child(column)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",9)
		column.add_child(row)
		var icon := TextureRect.new()
		icon.texture = load("res://assets/ui/record_icons/"+({"ARJUN":"identity","STRENGTH":"strength","NOTICES":"notice"}[title])+".svg") if title in ["ARJUN","STRENGTH","NOTICES"] else load("res://assets/ui/collection_icons/"+icons[i]+".svg")
		icon.custom_minimum_size = Vector2(32,32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var heading := Label.new()
		heading.text = "IDENTITY" if title == "ARJUN" else title
		heading.add_theme_font_override("font",FONT)
		heading.add_theme_font_size_override("font_size",17)
		heading.add_theme_color_override("font_color",Color(.80,.66,.40))
		row.add_child(heading)
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_override("font",preload("res://assets/ui/fonts/MFBOldstyle-Bold.otf"))
		label.add_theme_font_size_override("font_size",29 if title in ["FAME","STRENGTH","WOUNDS"] else 24)
		label.add_theme_color_override("font_color",Color(.96,.90,.76))
		column.add_child(label)
		values[title] = label
		if title in ["STRENGTH","WOUNDS"]:
			var bar := ProgressBar.new()
			bar.show_percentage = false
			bar.custom_minimum_size.y = 5
			var back := StyleBoxFlat.new()
			back.bg_color = Color(.28,.23,.16)
			var fill := StyleBoxFlat.new()
			fill.bg_color = Color(.64,.66,.40) if title == "STRENGTH" else Color(.67,.39,.27)
			bar.add_theme_stylebox_override("background",back)
			bar.add_theme_stylebox_override("fill",fill)
			column.add_child(bar)
			bars[title] = bar
		var detail := Label.new()
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_font_override("font",FONT)
		detail.add_theme_font_size_override("font_size",17)
		detail.add_theme_color_override("font_color",Color(.73,.67,.55))
		detail.custom_minimum_size.y = 26
		column.add_child(detail)
		details[title] = detail
	resized.connect(_layout_cards)

func _layout_cards() -> void:
	var width := minf(size.x*(.40 if size.x >= 900 else .85),710.0)
	var height := minf(size.y*.85,640.0)
	var x := size.x-width-38.0 if size.x >= 900 else (size.x-width)*.5
	content.position = Vector2(x+24,(size.y-height)*.5+76)
	content.size = Vector2(width-48,height-125)
	grid.columns = 2 if size.x >= 900 and width >= 490 else 1

func _refresh_cards() -> void:
	var fame: Node = player.get_node("FameComponent")
	var survival: Node = player.get_node("SurvivalComponent")
	var character: Node = player.get_node("VisualRoot/CharacterVisual")
	var held: String = character.equipment.held_name() if character.equipment else "STOWED"
	var markers: Array[String] = fame.recognition_markers()
	var owned: Array[String] = []
	for i in 6:
		if character.equipment.owns(i): owned.append(["Talwar","Enfield","Bow","Adams","Knife","Double gun"][i])
	var data := [
		["Arjun","Traveller · Suryagarh"],
		[str(fame.points),", ".join(markers) if not markers.is_empty() else "Not yet known"],
		["%d / %d" % [roundi(survival.stamina),roundi(survival.max_stamina)],"Stamina"],
		[str(owned.size())+" carried",", ".join(owned) if not owned.is_empty() else "No weapons acquired"],
		["%d / %d" % [roundi(player.health),roundi(player.MAX_HEALTH)],"Healthy" if player.health >= player.MAX_HEALTH else "Injured · bandage to recover"],
		[source_notice.headline,source_notice.message] if is_instance_valid(source_notice) else ["Market news","Bhairavpur notice board"]
	]
	var current := str(data)
	if current == snapshot: return
	snapshot = current
	var keys := ["ARJUN","FAME","STRENGTH","WEAPONS","WOUNDS","NOTICES"]
	for i in keys.size():
		values[keys[i]].text = data[i][0]
		details[keys[i]].text = data[i][1]
	bars["STRENGTH"].value = 100.0 * survival.stamina / maxf(survival.max_stamina,1.0)
	bars["WOUNDS"].value = player.health


func _line(value: String, x: float, y: float, font_size: int = 24, color: Color = INK) -> void:
	draw_string(FONT, Vector2(x, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	if progress <= 0.0: return
	var ease := 1.0 - pow(1.0-progress, 3.0)
	var width := minf(size.x * (.40 if size.x >= 900 else .85), 710.0)
	var height := minf(size.y * 0.85, 640.0) * ease
	var rect := Rect2(size.x-width-38.0 if size.x >= 900 else (size.x-width)*.5, (size.y-height)*.5, width, height)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,0.026,0.018,0.24*progress))
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
	_line("POSTED NOTICE" if is_instance_valid(source_notice) else "THE TRAVELLER'S RECORD",rect.position.x+24,rect.position.y+43,26)
	_line("[ O / Esc ]   Return sheet" if is_instance_valid(source_notice) else "[ O / Esc ]   Roll closed",rect.position.x+24,rect.end.y-22,18)
