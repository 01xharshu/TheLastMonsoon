extends Control
## Cinematic title screen — AAA-quality entry point.
## Dark atmospheric background, drifting particles, staggered fade-in,
## gold accents, smooth hover animations.

const Style = preload("res://ui/menu_style.gd")
const SettingsPanel = preload("res://ui/settings_panel.gd")

var column: VBoxContainer
var content_root: Control          # holds all foreground content
var page := "main"

# ── Lifecycle ────────────────────────────────────────────────
func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.make_theme()

	# Cinematic background layers
	Style.cinematic_background(self)
	Style.add_particles(self)

	# Foreground container
	content_root = Control.new()
	content_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content_root)

	# Bottom-left branding watermark
	_add_watermark()

	# Centre column
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_root.add_child(centre)

	column = VBoxContainer.new()
	column.custom_minimum_size.x = 480
	column.add_theme_constant_override("separation", 10)
	centre.add_child(column)

	show_main()

# ── Pages ────────────────────────────────────────────────────
func clear_content() -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()

func show_main() -> void:
	page = "main"
	clear_content()

	# Title block
	column.add_child(Style.heading("The Last Monsoon", 56))
	column.add_child(Style.subtitle("India  ·  1857", 20))

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	column.add_child(spacer)

	# Buttons
	var play := Style.button("Play Game", func(): SaveManager.start_new_game())
	column.add_child(play)
	_focus_when_ready.call_deferred(play)

	var continuation := Style.button("Continue", func(): SaveManager.start_loaded_game(SaveManager.newest_slot()))
	continuation.disabled = SaveManager.newest_slot() == 0
	column.add_child(continuation)

	column.add_child(Style.button("Load Game", func(): show_slots()))
	column.add_child(Style.button("Settings", func(): show_settings()))

	# Extra spacer before quit
	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 6
	column.add_child(spacer2)

	column.add_child(Style.divider(320.0))

	var spacer3 := Control.new()
	spacer3.custom_minimum_size.y = 4
	column.add_child(spacer3)

	column.add_child(Style.button("Quit", func(): get_tree().quit()))

	# Staggered fade-in
	Style.stagger_children(column, 0.07)

func show_slots() -> void:
	page = "slots"
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
			func(): SaveManager.start_loaded_game(selected)
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
	if page != "main" and event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed:
		show_main()
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
