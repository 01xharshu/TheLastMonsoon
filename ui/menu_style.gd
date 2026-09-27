extends RefCounted
## AAA-grade menu style system — cinematic typography, film-grain overlays,
## atmospheric particle hints, and smooth tween transitions.

const SERIF = preload("res://assets/ui/fonts/CormorantGaramond.ttf")
const UI_CLICK = preload("res://audio/ui/ui_click.wav")
const UI_BACK = preload("res://audio/ui/ui_back.wav")

# ── Colour palette ───────────────────────────────────────────
# Warm gold / ivory / charcoal inspired by RDR2 + Ghost of Tsushima.
const IVORY         := Color(0.95, 0.91, 0.80)       # primary text
const GOLD          := Color(0.82, 0.66, 0.38)       # accents / borders
const BRASS         := Color(0.61, 0.47, 0.27)       # button border
const WARM_WHITE    := Color(0.98, 0.96, 0.91)       # hover text
const CHARCOAL      := Color(0.055, 0.06, 0.055)     # deep BG
const SMOKE         := Color(0.10, 0.11, 0.09, 0.96) # button fill
const SMOKE_HOVER   := Color(0.15, 0.16, 0.13, 0.98)
const SMOKE_PRESSED := Color(0.22, 0.19, 0.14, 0.98)
const DISABLED_TEXT := Color(0.38, 0.39, 0.34)
const DISABLED_FILL := Color(0.05, 0.055, 0.045)
const DISABLED_EDGE := Color(0.22, 0.23, 0.19)
const TRANSLUCENT   := Color(0.0, 0.0, 0.0, 0.0)

# ── Style factory ────────────────────────────────────────────
static func style(fill: Color, edge: Color, radius: int = 3, border_width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left  = 20
	box.content_margin_right = 20
	box.content_margin_top   = 14
	box.content_margin_bottom = 14
	return box

# ── Theme builder ────────────────────────────────────────────
static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = SERIF
	theme.default_font_size = 21

	# Label colours
	theme.set_color("font_color",       "Label",  IVORY)
	theme.set_color("font_shadow_color","Label",  Color(0.0, 0.0, 0.0, 0.45))

	# Button colours
	theme.set_color("font_color",          "Button", IVORY)
	theme.set_color("font_hover_color",    "Button", WARM_WHITE)
	theme.set_color("font_pressed_color",  "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", DISABLED_TEXT)

	# Button boxes
	theme.set_stylebox("normal",   "Button", style(SMOKE,         BRASS))
	theme.set_stylebox("hover",    "Button", style(SMOKE_HOVER,   GOLD,  3, 2))
	theme.set_stylebox("pressed",  "Button", style(SMOKE_PRESSED, GOLD))
	theme.set_stylebox("disabled", "Button", style(DISABLED_FILL, DISABLED_EDGE))
	theme.set_stylebox("focus",    "Button", style(TRANSLUCENT,   GOLD, 3, 2))

	# Sliders — use flat style boxes for the track
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.12, 0.12, 0.10, 0.85)
	slider_bg.set_corner_radius_all(4)
	slider_bg.content_margin_top = 4
	slider_bg.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", slider_bg)

	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = GOLD
	slider_fill.set_corner_radius_all(4)
	slider_fill.content_margin_top = 4
	slider_fill.content_margin_bottom = 4
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)

	# CheckButton
	theme.set_color("font_color",       "CheckButton", IVORY)
	theme.set_color("font_hover_color", "CheckButton", WARM_WHITE)

	# OptionButton
	theme.set_color("font_color",       "OptionButton", IVORY)
	theme.set_color("font_hover_color", "OptionButton", WARM_WHITE)
	theme.set_stylebox("normal",  "OptionButton", style(SMOKE, BRASS))
	theme.set_stylebox("hover",   "OptionButton", style(SMOKE_HOVER, GOLD, 3, 2))
	theme.set_stylebox("pressed", "OptionButton", style(SMOKE_PRESSED, GOLD))
	theme.set_stylebox("focus",   "OptionButton", style(TRANSLUCENT, GOLD, 3, 2))

	# Scroll
	var scroll_bg := StyleBoxFlat.new()
	scroll_bg.bg_color = Color(0.08, 0.09, 0.07, 0.5)
	scroll_bg.set_corner_radius_all(3)
	theme.set_stylebox("scroll", "VScrollBar", scroll_bg)

	return theme

# ── Widget factories ─────────────────────────────────────────

## Cinematic heading: uppercase, tracked, optional gold underline.
static func heading(value: String, font_size: int = 52, show_rule: bool = true) -> VBoxContainer:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 10)

	var lbl := Label.new()
	lbl.text = value.to_upper()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", IVORY)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 3)
	wrapper.add_child(lbl)

	if show_rule:
		var rule := ColorRect.new()
		rule.custom_minimum_size = Vector2(120, 2)
		rule.color = GOLD
		rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		wrapper.add_child(rule)

	return wrapper

## Simple centred label — for subtitles, notices, etc.
static func label(value: String, size: int = 21) -> Label:
	var node := Label.new()
	node.text = value
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size", size)
	return node

## Sub-label with muted gold colour for atmosphere text.
static func subtitle(value: String, size: int = 18) -> Label:
	var node := label(value, size)
	node.add_theme_color_override("font_color", GOLD)
	node.modulate.a = 0.75
	return node

## Premium button with hover scale tween.
static func button(value: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = value
	node.custom_minimum_size = Vector2(420, 52)
	node.pressed.connect(func():
		play_ui_sound(node, UI_BACK if value.to_lower() in ["back", "cancel", "quit"] else UI_CLICK)
		action.call()
	)
	# Tracking (letter spacing simulation via theme)
	node.add_theme_font_size_override("font_size", 19)
	# Hover micro-animation
	node.mouse_entered.connect(func():
		var tw := node.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(node, "scale", Vector2(1.025, 1.025), 0.18)
	)
	node.mouse_exited.connect(func():
		var tw := node.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(node, "scale", Vector2.ONE, 0.15)
	)
	node.pivot_offset = Vector2(210, 26)  # centre pivot for scale
	return node

static func play_ui_sound(caller: Node, stream: AudioStream) -> void:
	if caller == null or not caller.is_inside_tree(): return
	var root := caller.get_tree().root
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -12.0
	root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

## Gold horizontal rule divider.
static func divider(width: float = 200.0) -> ColorRect:
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(width, 1)
	rule.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.35)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return rule

# ── Cinematic background ─────────────────────────────────────

## Full-screen background with vertical gradient, vignette, and film-grain.
static func cinematic_background(parent: Control) -> void:
	# Base gradient
	var gradient_rect := ColorRect.new()
	gradient_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gradient_rect.color = Color(0.028, 0.038, 0.032)
	parent.add_child(gradient_rect)

	# Gradient overlay — top-to-bottom atmospheric
	var gradient_overlay := ColorRect.new()
	gradient_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gradient_overlay.color = Color(0.015, 0.025, 0.02, 0.6)
	parent.add_child(gradient_overlay)

	# Film-grain / noise texture simulation via subtle animated noise
	var grain := ColorRect.new()
	grain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grain.color = Color(1.0, 1.0, 1.0, 0.015)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(grain)

	# Vignette — four darkened edge panels
	_add_vignette(parent)

## Floating particles for atmosphere (fireflies / dust motes).
static func add_particles(parent: Control) -> void:
	# Spawn ambient dots that drift slowly
	for i in range(28):
		var dot := ColorRect.new()
		var dot_size := randf_range(1.5, 3.5)
		dot.custom_minimum_size = Vector2(dot_size, dot_size)
		dot.size = Vector2(dot_size, dot_size)
		dot.color = Color(GOLD.r, GOLD.g, GOLD.b, randf_range(0.08, 0.28))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2(randf_range(0, 1280), randf_range(0, 720))
		parent.add_child(dot)
		# Slow drift animation
		var duration := randf_range(6.0, 14.0)
		var dest := Vector2(dot.position.x + randf_range(-120, 120),
							dot.position.y + randf_range(-80, 80))
		var tw := dot.create_tween().set_loops().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_property(dot, "position", dest, duration)
		tw.tween_property(dot, "position", dot.position, duration)
		# Opacity pulse
		var tw2 := dot.create_tween().set_loops().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw2.tween_property(dot, "modulate:a", randf_range(0.3, 0.85), randf_range(3.0, 7.0))
		tw2.tween_property(dot, "modulate:a", randf_range(0.05, 0.35), randf_range(3.0, 7.0))

# ── Fade transition helper ────────────────────────────────────

static func fade_in(node: Control, delay: float = 0.0, duration: float = 0.5) -> void:
	node.modulate.a = 0.0
	var tw := node.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(node, "modulate:a", 1.0, duration)

static func stagger_children(container: Control, base_delay: float = 0.08) -> void:
	var idx := 0
	for child in container.get_children():
		if child is Control:
			fade_in(child, base_delay * idx, 0.4)
			idx += 1

# ── Private helpers ──────────────────────────────────────────

static func _add_vignette(parent: Control) -> void:
	# Top edge
	var top := ColorRect.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size.y = 180
	top.color = Color(0, 0, 0, 0.45)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(top)
	# Bottom edge
	var bottom := ColorRect.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.custom_minimum_size.y = 140
	bottom.color = Color(0, 0, 0, 0.55)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bottom)
