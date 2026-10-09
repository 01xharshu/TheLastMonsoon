extends Label
## Readable black-screen cards, with a blank breath between each fade.
const CARDS := [
	["INDIA\n1857", 5.5],
	["Under British colonial rule,\ntwo brothers made a home together.\nTheir names were Arjun and Dev.", 8.0],
	["They had lost their parents as children.\nSince then, they had only each other.", 7.0],
	["Dev served as a sepoy,\nbut his heart belonged to his country.\nArjun remained at home.", 8.0],
	["Three months had passed\nwithout a letter or any news from Dev.", 7.0],
	["Something had happened. Arjun did not know what.\nEach night, he waited for his brother to return.\nStill, there was no news from Dev.", 8.0],
	["HeyaHarshu Creative Studio Presents", 5.5],
	["", 7.0]]
const DURATION := 56.0
const CHALK := preload("res://assets/ui/fonts/FrederickatheGreat-Regular.ttf")
const TITLE_FONT := preload("res://assets/ui/fonts/MFBOldstyle-Bold.otf")
var card_index := -1
var title_top: Label
var title_main: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anchor_left = .12
	anchor_right = .88
	anchor_top = .20
	anchor_bottom = .80
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_override("font", CHALK)
	add_theme_color_override("font_color", Color(.89,.88,.83))
	add_theme_constant_override("line_spacing", 14)
	title_top = _title_line("THE LAST", .25, .45)
	title_main = _title_line("MONSOON", .43, .72)
	resized.connect(_layout)
	_layout()
	modulate.a = 0.0

func _layout() -> void:
	var viewport := get_viewport_rect().size
	var scale_factor := minf(viewport.x/1280.0, viewport.y/720.0)
	add_theme_font_size_override("font_size", maxi(18,roundi((52 if card_index == 0 else 32)*scale_factor)))
	if title_top != null:
		title_top.add_theme_font_size_override("font_size", maxi(20,roundi(38*scale_factor)))
		title_main.add_theme_font_size_override("font_size", maxi(32,roundi(88*scale_factor)))

func _title_line(value: String, top: float, bottom: float) -> Label:
	var line := Label.new()
	line.text = value
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.anchor_top = top
	line.anchor_bottom = bottom
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_override("font", TITLE_FONT)
	line.add_theme_color_override("font_color", Color(.89,.88,.83))
	add_child(line)
	line.hide()
	return line

func update(t: float) -> void:
	var start := 0.0
	for i in CARDS.size():
		var duration: float = CARDS[i][1]
		if t < start+duration:
			if card_index != i:
				card_index = i
				text = CARDS[i][0]
				add_theme_font_override("font", TITLE_FONT if i == CARDS.size()-2 else CHALK)
				title_top.visible = i == CARDS.size()-1
				title_main.visible = title_top.visible
				_layout()
			var age := maxf(0,t-start)
			modulate.a = smoothstep(.35,1.6,age)*(1.0-smoothstep(duration-1.6,duration-.35,age))
			return
		start += duration
	modulate.a = 0.0

func next_morning(t: float) -> void:
	card_index = -1
	title_top.hide()
	title_main.hide()
	add_theme_font_override("font", CHALK)
	text = "The next morning"
	_layout()
	modulate.a = smoothstep(.2,1.2,t)*(1.0-smoothstep(2.8,3.8,t))
