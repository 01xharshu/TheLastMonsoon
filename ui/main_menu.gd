extends Control
## Historical title screen with live controls over a clean riverside background plate.

const Style = preload("res://ui/menu_style.gd")
const SettingsPanel = preload("res://ui/settings_panel.gd")
const ARRIVAL = preload("res://assets/ui/backgrounds/monsoon_arrival.png")

var secondary_root: CenterContainer
var column: VBoxContainer
var content_root: Control
var main_panel: Control
var page_shade: ColorRect
var continuation: Button
var play_button: Button
var page := "main"
var action_hint: Label
var footer: Label
var transition_cover: ColorRect
var transitioning := false
var background: TextureRect
var reference_canvas: Control
var alert_plate: TextureRect
var tiles: Array[Button] = []
const STORY = preload("res://assets/ui/story_reference/story.png")
const ALERT = preload("res://assets/ui/story_reference/alert.png")
var menu_time := 0.0
var focus_tweens: Dictionary = {}
const ACTION_HINTS := {
	"New Game": "Start a New Game",
	"Save Game": "Save your current progress.",
	"Exit Game": "Exit Game",
	"Continue": "Return to your most recent saved journey.",
	"Load Game": "Choose a saved journey to resume.",
	"Settings": "Adjust display, sound and controls.",
	"Quit": "Leave The Last Monsoon.",
}

# ── Lifecycle ────────────────────────────────────────────────
func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.make_theme()

	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)

	page_shade = ColorRect.new()
	page_shade.color = Color.BLACK
	page_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_shade.hide()
	add_child(page_shade)

	# Foreground container
	content_root = Control.new()
	content_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content_root)

	_build_main_panel()

	# Centre column
	var centre := CenterContainer.new()
	secondary_root = centre
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_root.add_child(centre)

	column = VBoxContainer.new()
	column.custom_minimum_size.x = 480
	column.add_theme_constant_override("separation", 10)
	centre.add_child(column)

	resized.connect(_layout_main_panel)
	_layout_main_panel()
	show_main()
	_build_footer()
	transition_cover = ColorRect.new()
	transition_cover.color = Color(0.008, 0.012, 0.012, 1.0)
	transition_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(transition_cover)
	var entrance := create_tween()
	entrance.tween_property(transition_cover, "modulate:a", 0.0, 0.65)

func _build_footer() -> void:
	footer = Label.new()
	footer.text = "Select  ↵     Back  Esc"
	footer.add_theme_font_override("font", Style.MENU_BOLD)
	footer.add_theme_font_size_override("font_size", 26)
	footer.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	reference_canvas.add_child(footer)
	action_hint = Label.new()
	action_hint.add_theme_font_size_override("font_size", 23)
	action_hint.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	reference_canvas.add_child(action_hint)
	_layout_main_panel()
	_update_hint("New Game")

func _update_hint(action: String) -> void:
	if is_instance_valid(action_hint):
		action_hint.text = ACTION_HINTS.get(action, "")

func _begin_journey(slot: int) -> void:
	if transitioning: return
	transitioning = true
	var loading := preload("res://ui/journey_loading.gd").new()
	get_tree().root.add_child(loading)
	var succeeded: bool = await loading.begin(slot)
	if not succeeded and is_inside_tree():
		transitioning = false
		var reason: String = SaveManager.last_error if not SaveManager.last_error.is_empty() else "Unable to open the journey. Please try again."
		if slot > 0:
			show_slots()
			var message := Style.label(reason, 18)
			column.add_child(message)
			column.move_child(message, 1)
		else:
			show_main()
			action_hint.text = reason

func _request_new_game() -> void:
	page = "new_game"
	main_panel.hide()
	page_shade.show()
	column.show()
	clear_content()
	alert_plate = TextureRect.new()
	alert_plate.texture = ALERT
	alert_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	alert_plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	alert_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alert_plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_root.add_child(alert_plate)
	content_root.move_child(alert_plate, secondary_root.get_index())
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 28)
	column.add_child(actions)
	var confirm := _alert_action("Confirm", _begin_journey.bind(0))
	actions.add_child(confirm)
	var back := _alert_action("Back", show_main)
	actions.add_child(back)
	_focus_when_ready.call_deferred(back)
	_layout_main_panel()

func _alert_action(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.add_theme_font_override("font", Style.MENU_BOLD)
	button.add_theme_font_size_override("font_size", 24)
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var selected := StyleBoxFlat.new()
	selected.bg_color = Color.TRANSPARENT
	selected.border_color = Color(0.78, 0, 0)
	selected.border_width_bottom = 2
	button.add_theme_stylebox_override("focus", selected)
	button.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	button.pressed.connect(action)
	return button

# Reference artwork is sampled losslessly. Controls, focus and actions stay live.
func _region(rect: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = STORY
	var ratio := Vector2(STORY.get_width() / 2048.0, STORY.get_height() / 1118.0)
	atlas.region = Rect2(rect.position * ratio, rect.size * ratio)
	atlas.filter_clip = true
	return atlas

func _plate(parent: Control, rect: Rect2) -> TextureRect:
	var plate := TextureRect.new()
	plate.texture = _region(rect)
	plate.position = rect.position
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.size = rect.size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(plate)
	plate.set_deferred("size", rect.size)
	return plate

func _build_main_panel() -> void:
	reference_canvas = Control.new()
	reference_canvas.size = Vector2(2048, 1118)
	reference_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_root.add_child(reference_canvas)
	main_panel = Control.new()
	main_panel.size = reference_canvas.size
	main_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reference_canvas.add_child(main_panel)
	_plate(main_panel, Rect2(0, 0, 2048, 120))
	_plate(main_panel, Rect2(70, 985, 1844, 15))
	var save := _tile("Save Game", Rect2(72, 200, 574, 690), Callable())
	save.disabled = true
	save.tooltip_text = "Saving is available during gameplay."
	continuation = _tile("Load Game", Rect2(704, 200, 574, 690), show_slots)
	play_button = _tile("New Game", Rect2(1340, 204, 572, 312), _request_new_game)
	_tile("Exit Game", Rect2(1338, 576, 574, 314), func(): SaveManager.quit_game())
	# Explicit grid neighbours avoid diagonal focus jumps in the asymmetric layout.
	continuation.focus_neighbor_right = continuation.get_path_to(play_button)
	play_button.focus_neighbor_left = play_button.get_path_to(continuation)
	play_button.focus_neighbor_bottom = play_button.get_path_to(tiles[3])
	tiles[3].focus_neighbor_top = tiles[3].get_path_to(play_button)
	tiles[3].focus_neighbor_left = tiles[3].get_path_to(continuation)

func _tile(value: String, rect: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.name = value.replace(" ", "")
	button.accessibility_name = value
	button.tooltip_text = value
	button.position = rect.position
	button.size = rect.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color(0.78, 0, 0)
	focus.set_border_width_all(5)
	focus.set_expand_margin_all(5)
	button.add_theme_stylebox_override("focus", focus)
	main_panel.add_child(button)
	var art := TextureRect.new()
	art.texture = _region(rect)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Focus must draw over artwork, so use show_behind_parent.
	art.show_behind_parent = true
	button.add_child(art)
	button.focus_entered.connect(_update_hint.bind(value))
	button.mouse_entered.connect(func():
		if not button.disabled: button.grab_focus()
	)
	button.pressed.connect(func():
		if not transitioning and action.is_valid():
			Style.play_ui_sound(button, Style.UI_CLICK)
			action.call()
	)
	tiles.append(button)
	return button

func _layout_main_panel() -> void:
	if not is_instance_valid(reference_canvas): return
	var factor := minf(size.x / 2048.0, size.y / 1118.0)
	reference_canvas.scale = Vector2.ONE * factor
	reference_canvas.position = (size - Vector2(2048, 1118) * factor) * 0.5
	if is_instance_valid(footer):
		footer.position = Vector2(1650, 1018)
	if is_instance_valid(action_hint):
		action_hint.position = Vector2(72, 1020)
		action_hint.visible = page == "main"
	if is_instance_valid(secondary_root):
		secondary_root.pivot_offset = size * 0.5
		secondary_root.scale = Vector2.ONE * minf(1.0, minf(size.x / 600.0, size.y / 780.0))
		if page == "new_game":
			secondary_root.position = Vector2(size.x * 0.25, size.y * 0.43)
		else:
			secondary_root.position = Vector2.ZERO

# ── Pages ────────────────────────────────────────────────────
func clear_content() -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()

func show_main() -> void:
	page = "main"
	_layout_main_panel()
	clear_content()
	column.hide()
	page_shade.hide()
	main_panel.show()
	continuation.disabled = false
	if is_instance_valid(alert_plate):
		alert_plate.queue_free()
	_focus_when_ready.call_deferred(play_button)

func show_slots() -> void:
	page = "slots"
	_layout_main_panel()
	main_panel.hide()
	page_shade.show()
	column.show()
	clear_content()
	column.add_child(Style.heading("Load Game", 42))

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	column.add_child(spacer)

	var first: Button
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var selected := slot
		var btn := Style.button(
			SaveManager.slot_label(selected),
			func(): _begin_journey(selected)
		)
		btn.disabled = SaveManager.read_slot(selected).is_empty()
		column.add_child(btn)
		if first == null and not btn.disabled:
			first = btn

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 4
	column.add_child(spacer2)

	var back := Style.button("Back", func(): show_main())
	column.add_child(back)
	_focus_when_ready.call_deferred(first if first else back)

	Style.stagger_children(column, 0.06)

func show_settings() -> void:
	page = "settings"
	_layout_main_panel()
	main_panel.hide()
	page_shade.show()
	column.show()
	clear_content()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, minf(600.0, get_viewport_rect().size.y - 120.0))
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var settings := SettingsPanel.new()
	settings.back_requested.connect(show_main)
	scroll.add_child(settings)
	column.add_child(scroll)
	settings.focus_first_control.call_deferred()

# ── Input ────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if transitioning: return
	if page == "main" and event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		show_settings()
		get_viewport().set_input_as_handled()
	if page != "main" and (event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed)):
		var settings:=column.find_child("SettingsPanel",true,false)
		if page!="settings" or settings==null or not settings.handle_back():show_main()
		get_viewport().set_input_as_handled()

# ── Helpers ──────────────────────────────────────────────────
func _focus_when_ready(btn: Button) -> void:
	if is_instance_valid(btn) and btn.is_inside_tree() and btn.is_visible_in_tree():
		btn.grab_focus()

func _add_watermark() -> void:
	var wm := Label.new()
	wm.text = "PRE-ALPHA  ·  BUILD 2026"
	wm.add_theme_font_size_override("font_size", 13)
	wm.add_theme_color_override("font_color", Color(Style.GOLD.r, Style.GOLD.g, Style.GOLD.b, 0.30))
	wm.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	wm.offset_left = 28
	wm.offset_bottom = -18
	wm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_root.add_child(wm)
	Style.fade_in(wm, 1.2, 1.5)
