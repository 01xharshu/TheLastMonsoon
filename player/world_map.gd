extends Control
## North-up field map derived from the same terrain data as the world.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const Bridge = preload("res://world/suryagarh/timber_bridge.gd")
const FONT = preload("res://assets/ui/fonts/CormorantGaramond.ttf")
const INK := Color(0.20,0.17,0.12)
var terrain: ImageTexture
var map_rect := Rect2()
var previous_mouse_mode: int
@onready var player: CharacterBody3D = get_parent().get_parent()
var layout := Layout.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var image := Image.create(256,256,false,Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			var p := Vector2(x/255.0,y/255.0)*Layout.SIZE-Vector2.ONE*Layout.HALF
			var h := layout.height(p.x,p.y)
			var color := Color(0.77,0.72,0.55)
			if h < 0.0: color = Color(0.36,0.53,0.54)
			elif h > 18.0: color = Color(0.43,0.49,0.33).lerp(Color(0.68,0.61,0.46),clampf(h/140.0,0,1))
			elif layout.field_mask(p.x,p.y)>0.5: color = Color(0.65,0.65,0.43)
			image.set_pixel(x,y,color)
	terrain = ImageTexture.create_from_image(image)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_M or (visible and event.keycode == KEY_ESCAPE):
		if not visible and player.inventory_ui.is_open(): return
		set_open(not visible)
		get_viewport().set_input_as_handled()
	elif visible and event.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()

func set_open(open: bool) -> void:
	if visible == open: return
	visible = open
	player.set_meta("map_open",open)
	if open:
		previous_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = previous_mouse_mode
	queue_redraw()

func _process(_delta: float) -> void:
	if visible: queue_redraw()

func project(p: Vector2) -> Vector2:
	return map_rect.position + (p+Vector2.ONE*Layout.HALF)/Layout.SIZE*map_rect.size

func caption(p: Vector2, value: String, font_size := 17, color := INK) -> void:
	draw_string(FONT,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw() -> void:
	if not visible or terrain == null: return
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,0.035,0.025,0.98))
	var edge := minf(size.y-170.0,size.x-100.0)
	map_rect = Rect2((size-Vector2(edge,edge))*0.5,Vector2(edge,edge))
	var paper := map_rect.grow(28)
	draw_rect(paper,Color(0.86,0.81,0.66))
	draw_rect(paper,INK,false,2)
	draw_texture_rect(terrain,map_rect,false)
	caption(Vector2(paper.position.x, paper.position.y-17),"SURYAGARH  /  FIELD MAP · 1857",28,Color(0.92,0.87,0.72))
	var road := PackedVector2Array()
	for z in range(-864,865,12): road.append(project(Vector2(layout.road_x(z),z)))
	draw_polyline(road,Color(0.48,0.31,0.17),2,true)
	var lane := PackedVector2Array()
	for x in range(-280,90,4): lane.append(project(Vector2(x,160+12*sin(x*0.017))))
	draw_polyline(lane,Color(0.48,0.31,0.17),2,true)
	for label in Layout.SITES:
		var p := project(Layout.SITES[label])
		draw_circle(p,3,INK)
		var offset := Vector2(6,-5)
		if label == "Bhairavpur reserve": offset = Vector2(-65,23)
		if label == "River approach": offset = Vector2(6,-12)
		if label == "Wooded ridge": offset = Vector2(-90,-8)
		caption(p+offset,label,16)
	var bridge := Vector2(layout.river_x(Bridge.CROSSING_Z),Bridge.CROSSING_Z)
	draw_line(project(bridge-Vector2(88,0)),project(bridge+Vector2(88,0)),Color(0.30,0.15,0.08),5)
	caption(project(bridge)+Vector2(-30,24),"Timber crossing",16)
	var actor := project(Vector2(player.global_position.x,player.global_position.z))
	draw_circle(actor,7,Color(0.97,0.9,0.65))
	draw_circle(actor,4,Color(0.65,0.19,0.10))
	caption(map_rect.position+Vector2(map_rect.size.x-23,23),"N ↑",19)
	var bar := map_rect.position+Vector2(15,map_rect.size.y-18)
	draw_line(bar,bar+Vector2(500/Layout.SIZE*edge,0),INK,2)
	caption(bar-Vector2(0,7),"500 m",15)
	caption(Vector2(paper.position.x,paper.end.y+26),"M / ESC  Close     •     Red marker: Arjun     •     Reserves: future sites",18,Color(0.92,0.87,0.72))
