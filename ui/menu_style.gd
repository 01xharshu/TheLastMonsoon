extends RefCounted
const SERIF = preload("res://assets/ui/fonts/CormorantGaramond.ttf")
const IVORY := Color(0.92,0.88,0.76)
const BRASS := Color(0.61,0.47,0.27)

static func style(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = SERIF
	theme.default_font_size = 21
	theme.set_color("font_color","Label",IVORY)
	theme.set_color("font_color","Button",IVORY)
	theme.set_color("font_disabled_color","Button",Color(0.42,0.43,0.36))
	theme.set_stylebox("normal","Button",style(Color(0.07,0.08,0.065,0.96),BRASS))
	theme.set_stylebox("hover","Button",style(Color(0.14,0.15,0.11,0.98),IVORY))
	theme.set_stylebox("pressed","Button",style(Color(0.22,0.18,0.11,0.98),BRASS))
	theme.set_stylebox("disabled","Button",style(Color(0.05,0.06,0.05),Color(0.25,0.26,0.21)))
	theme.set_stylebox("focus","Button",style(Color.TRANSPARENT,IVORY))
	return theme

static func label(value: String, size: int = 21) -> Label:
	var node := Label.new()
	node.text = value
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size",size)
	return node

static func button(value: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = value
	node.custom_minimum_size = Vector2(390,47)
	node.pressed.connect(action)
	return node
