extends Control
## Fixed overhead camera with a single sheet turning around the binding.
const Catalog = preload("res://interaction/item_catalog.gd")
const Icons = preload("res://interaction/collection_icon_assets.gd")
const FONT = preload("res://assets/ui/fonts/MFBOldstyle-Regular.otf")
const INK := Color("#39261c")
const FADED := Color("#705442")
const STOCK := [
	{"id": "roti", "price": 2, "note": "Flatbread for the road"},
	{"id": "mango", "price": 3, "note": "Fresh fruit"},
	{"id": "bandage", "price": 6, "note": "Clean cloth for dressing wounds"},
	{"id": "water_bag", "price": 12, "note": "Leather bag for carrying water"},
	{"id": "stable_fodder", "price": 4, "note": "A sack of feed for stable care", "icon": preload("res://assets/ui/collection_icons/fodder.svg")},
	{"id": "arrow", "price": 8, "note": "Six shafts for a hunting bow", "quantity": 6, "label": "Arrows ×6"},
	{"id": "utility_knife", "price": 15, "note": "A small working blade", "unique": true, "icon": preload("res://assets/ui/collection_icons/knife.svg")},
	{"id": "bow", "price": 24, "note": "A bow for hunting and defence", "unique": true}
]
const ROWS := 4
const SPINE := 550.0
const TURN_SECONDS := .48
var selected := 0
var balance := 0
var receipt := ""
var turning := false
var turn_progress := 0.0
var incoming := 0

func browse(step: int) -> void:
	_select(posmod(selected+step,STOCK.size()))

func turn_page(step: int) -> void:
	var page := _page(selected)+step
	if page >= 0 and page*ROWS < STOCK.size():
		_select(page*ROWS)

func _page(index: int) -> int:
	return floori(float(index)/ROWS)

func _select(index: int) -> void:
	if turning:
		return
	receipt = ""
	if _page(index) == _page(selected):
		selected = index
		queue_redraw()
		return
	incoming = index
	turn_progress = 0.0
	turning = true
	var turn := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	turn.tween_method(_update_turn,0.0,1.0,TURN_SECONDS)
	turn.finished.connect(func():
		selected = incoming
		turning = false
		queue_redraw()
	)

func _update_turn(progress: float) -> void:
	turn_progress = progress
	queue_redraw()

func _draw() -> void:
	var factor := minf(size.x / 1100.0, size.y / 650.0)
	var origin := (size - Vector2(1100,650)*factor)*.5
	draw_rect(Rect2(Vector2.ZERO,size),Color("#30221a"))
	draw_set_transform(origin,0,Vector2.ONE*factor)
	# Table boards run behind the fixed overhead view.
	for i in range(-2, 9):
		var y := i*106.0
		draw_rect(Rect2(-4000,y,9200,104),Color("#483226").lightened(.012*(i+2)))
		draw_line(Vector2(-4000,y+103),Vector2(5200,y+103),Color("#30211b"),3)
		for grain in 5:
			var at := Vector2((i*31+grain*157)%420, y+13+grain*15)
			draw_line(at-Vector2(480,0),at+Vector2(1400,0),Color("#96664322"),1)
	draw_style_box(_paper(Color("#221812"),22),Rect2(134,61,836,514))
	draw_style_box(_paper(Color("#68412b"),17),Rect2(137,56,826,508))
	draw_style_box(_paper(Color("#b9a07a"),12),Rect2(151,59,798,495))
	draw_style_box(_paper(Color("#e3c89a"),11),Rect2(152,56,796,492))
	draw_style_box(_paper(Color("#f0dcb1"),13),Rect2(154,51,792,488))
	for i in 12:
		draw_line(Vector2(544+i,56),Vector2(544+i,533),Color(.38,.24,.13,.018+.012*(6-absi(6-i))),1)
	var base := Transform2D(0,Vector2.ONE*factor,0,origin)
	if turning:
		_draw_turn(base)
	else:
		_draw_page(true,selected,receipt)
		_draw_page(false,selected,receipt)
	draw_texture_rect(Icons.TEXTURES.coin,Rect2(67,581,34,34),false,Color("#f5d18e"))
	_text(Vector2(113,606),"%d rupees" % balance,23,Color("#f4e0b7"))
	_text(Vector2(565,595),"↑ / ↓ Browse    ← / → Turn page",20,Color("#f4e0b7"))
	_text(Vector2(565,622),"Enter Buy    Esc Back",20,Color("#f4e0b7"))

func _draw_turn(base: Transform2D) -> void:
	var forward := incoming > selected
	_draw_page(true,selected if forward else incoming)
	_draw_page(false,incoming if forward else selected)
	var first_face := turn_progress < .5
	var left := forward != first_face
	var width := maxf(.006,absf(cos(turn_progress*PI)))
	var lift := sin(turn_progress*PI)
	var shear := lift*.073*(-1.0 if not left else 1.0)
	var sheet := Transform2D(Vector2(width,shear),Vector2.DOWN,Vector2(SPINE*(1.0-width),-SPINE*shear))
	var shadow_width := 16.0+lift*92.0
	var shadow_x := SPINE-shadow_width if left else SPINE
	draw_rect(Rect2(shadow_x,56,shadow_width,477),Color(.25,.13,.07,.14*lift))
	draw_set_transform_matrix(base*sheet)
	var edge := 154.0 if left else SPINE
	draw_style_box(_paper(Color("#f4e0b5"),10),Rect2(edge,51,396,488))
	_draw_page(left,selected if first_face else incoming)
	for line in 18:
		var x := edge+line if left else edge+395-line
		draw_line(Vector2(x,55),Vector2(x,535),Color(.41,.25,.11,(1.0-line/18.0)*.10*lift),1)
	draw_set_transform_matrix(base)

func _draw_page(left: bool, selection: int, message := "") -> void:
	var page := _page(selection)
	var x := 174 if left else 565
	draw_rect(Rect2(x,72,360,445),Color("#8f704d"),false,1)
	draw_line(Vector2(x,171),Vector2(x+360,171),Color("#936c43"),1)
	if left:
		_text(Vector2(194,106),"SURYAGARH   ·   1857",15,FADED)
		_text(Vector2(194,148),"Daily Provisions" if page == 0 else "Trail Supplies",36)
		var first := page*ROWS
		for index in range(first,mini(first+ROWS,STOCK.size())):
			var item: Dictionary = STOCK[index]
			var y := 188.0+(index-first)*73
			if index == selection:
				draw_style_box(_paper(Color("#d9b775"),4),Rect2(181,y,346,65))
				draw_colored_polygon(PackedVector2Array([Vector2(192,y+23),Vector2(204,y+32),Vector2(192,y+41)]),INK)
			var icon: Texture2D = item.get("icon",Icons.TEXTURES[Catalog.icon(item.id)])
			draw_texture_rect(icon,Rect2(214,y+16,28,28),false,INK)
			_text(Vector2(256,y+36),item.get("label",Catalog.display_name(item.id)),23)
			_text(Vector2(454,y+36),"%d Rs." % item.price,20)
			draw_line(Vector2(191,y+68),Vector2(516,y+68),Color("#9d7d5266"),1)
	else:
		var item: Dictionary = STOCK[selection]
		_text(Vector2(587,109),"COUNTER ACCOUNT",16,FADED)
		_text(Vector2(587,147),"Order details",34)
		_text(Vector2(588,226),item.get("label",Catalog.display_name(item.id)),29)
		_text(Vector2(588,266),item.note,20,FADED)
		_text(Vector2(588,308),"Price per purchase",19,FADED)
		_text(Vector2(818,308),"%d Rs." % item.price,22)
		draw_line(Vector2(588,329),Vector2(896,329),Color("#936c43"),1)
		_text(Vector2(588,380),message if message != "" else "Select an entry to buy.",20,FADED)
	var page_number := page*2+(1 if left else 2)
	_text(Vector2(x+153,505),"%d / %d" % [page_number,ceili(float(STOCK.size())/ROWS)*2],14,FADED)

func _paper(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style

func _text(at: Vector2, value: String, points: int, color := INK) -> void:
	draw_string(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,points,color)
