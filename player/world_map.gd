extends Control
## North-up field map; surveyed routes and sites come from SuryagarhLayout.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const Bridge = preload("res://world/suryagarh/timber_bridge.gd")
const FONT = preload("res://assets/ui/fonts/CormorantGaramond.ttf")
const INK := Color(0.20,0.17,0.12)
const MAP_TEXTURE := "res://world/suryagarh/generated/field_map.res"
var terrain: Texture2D
var map_rect := Rect2()
var previous_mouse_mode: int
var previous_hud_visible := true
var zoom := 1.0
var map_center := Vector2.ZERO
var waypoint := Vector2(INF,INF)
var dragging := false
var dragged := false
var drag_start := Vector2.ZERO
var hovered_site := ""
@onready var player: CharacterBody3D = get_parent().get_parent()
var layout := Layout.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if ResourceLoader.exists(MAP_TEXTURE):
		terrain = load(MAP_TEXTURE)
	else:
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
	if player.get_meta("weapon_wheel_open", false): return
	if event.is_action_pressed("open_map") and not event.is_echo():
		if not visible and player.inventory_ui.is_open(): return
		set_open(not visible)
		get_viewport().set_input_as_handled()
		return
	if visible and SaveManager.active_input_device == "controller" and event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A:
				waypoint = map_center
				queue_redraw()
			JOY_BUTTON_B:
				set_open(false)
			JOY_BUTTON_Y:
				zoom = 1.0
				map_center = Vector2.ZERO
				queue_redraw()
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if SaveManager.active_input_device == "controller": return
	if event.keycode == KEY_M or (visible and event.keycode == KEY_ESCAPE):
		if not visible and player.inventory_ui.is_open(): return
		set_open(not visible)
		get_viewport().set_input_as_handled()
	elif visible and event.keycode == KEY_R:
		zoom = 1.0
		map_center = Vector2.ZERO
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif visible and event.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if not visible: return
	if SaveManager.active_input_device == "controller": return
	if event is InputEventMouseButton:
		if event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if map_rect.has_point(event.position):
				var before := unproject(event.position)
				zoom = clampf(zoom*(1.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8),1.0,8.0)
				map_center = before-(event.position-map_rect.get_center())/map_rect.size*view_extent()
				clamp_center()
				queue_redraw()
				accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and map_rect.has_point(event.position):
				dragging = true
				dragged = false
				drag_start = event.position
			elif not event.pressed and dragging:
				dragging = false
				if not dragged and map_rect.has_point(event.position): waypoint = unproject(event.position)
				queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and map_rect.has_point(event.position):
			waypoint = Vector2(INF,INF)
			queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion:
		if dragging:
			if event.position.distance_to(drag_start)>4.0: dragged = true
			if dragged:
				map_center -= event.relative/map_rect.size*view_extent()
				clamp_center()
		hovered_site = ""
		for site in Layout.SITES:
			if project(Layout.SITES[site]).distance_to(event.position)<12.0: hovered_site = site
		queue_redraw()

func set_open(open: bool) -> void:
	if visible == open: return
	visible = open
	player.set_meta("map_open",open)
	if open:
		previous_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		previous_hud_visible = player.get_node("UI/HUDRoot").visible
		player.get_node("UI/HUDRoot").visible = false
	else:
		Input.mouse_mode = previous_mouse_mode
		player.get_node("UI/HUDRoot").visible = previous_hud_visible
	queue_redraw()

func _process(_delta: float) -> void:
	if not visible: return
	if SaveManager.active_input_device == "controller":
		var pan := Input.get_vector("move_left","move_right","move_forward","move_backward")
		if pan.length_squared() > 0.01:
			map_center += pan * view_extent() * _delta * 0.6
			clamp_center()
		var scale := Input.get_axis("look_down","look_up")
		if absf(scale) > 0.1: zoom = clampf(zoom + scale * _delta * 2.0,1.0,8.0)
	queue_redraw()

func view_extent() -> float:
	return Layout.SIZE/zoom

func clamp_center() -> void:
	var limit := Layout.HALF-view_extent()*0.5
	map_center.x = clampf(map_center.x,-limit,limit)
	map_center.y = clampf(map_center.y,-limit,limit)

func project(p: Vector2) -> Vector2:
	return map_rect.get_center()+(p-map_center)/view_extent()*map_rect.size

func unproject(screen: Vector2) -> Vector2:
	return map_center+(screen-map_rect.get_center())/map_rect.size*view_extent()

func on_map(p: Vector2) -> bool:
	return map_rect.has_point(project(p))

func caption(p: Vector2, value: String, font_size := 17, color := INK) -> void:
	draw_string(FONT,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func draw_route(points: Array, color: Color, width: float) -> void:
	for i in range(points.size()-1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i+1]
		var count := maxi(1,ceili(a.distance_to(b)/8.0))
		for step in count:
			var pa: Vector2 = a.lerp(b,float(step)/count)
			var pb: Vector2 = a.lerp(b,float(step+1)/count)
			if on_map(pa) and on_map(pb): draw_line(project(pa),project(pb),color,width,true)

func _draw() -> void:
	if not visible or terrain == null: return
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,0.035,0.025,0.98))
	var edge := minf(size.y-170.0,size.x-100.0)
	map_rect = Rect2((size-Vector2(edge,edge))*0.5,Vector2(edge,edge))
	var paper := map_rect.grow(28)
	draw_rect(paper,Color(0.86,0.81,0.66))
	var origin := map_center-Vector2.ONE*view_extent()*0.5
	var source := Rect2((origin+Vector2.ONE*Layout.HALF)/Layout.SIZE*terrain.get_size(),Vector2.ONE*view_extent()/Layout.SIZE*terrain.get_size())
	draw_texture_rect_region(terrain,map_rect,source)
	draw_rect(map_rect,INK,false,1)
	draw_rect(paper,INK,false,2)
	caption(Vector2(paper.position.x,paper.position.y-17),"SURYAGARH  /  FIELD MAP · 1857",28,Color(0.92,0.87,0.72))
	var road: Array[Vector2] = []
	for z in range(-864,865,8): road.append(Vector2(layout.road_x(z),z))
	draw_route(road,Color(0.48,0.31,0.17),maxf(2.0,zoom))
	var lane: Array[Vector2] = []
	for x in range(-280,90,4): lane.append(Vector2(x,160+12*sin(x*0.017)))
	draw_route(lane,Color(0.48,0.31,0.17),maxf(2.0,zoom))
	for route in Layout.ROUTES.values(): draw_route(route,Color(0.48,0.31,0.17),maxf(2.0,zoom))
	for site in Layout.SITES:
		var p: Vector2 = Layout.SITES[site]
		if not on_map(p): continue
		draw_circle(project(p),4,INK)
		if zoom >= 1.7 or hovered_site == site:
			var label := project(p)+Vector2(7,-6)
			var width := FONT.get_string_size(site,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
			if label.x+width > map_rect.end.x-7: label.x = project(p).x-width-7
			if label.y < map_rect.position.y+17: label.y += 23
			caption(label,site,16)
	var bridge := Vector2(layout.river_x(Bridge.CROSSING_Z),Bridge.CROSSING_Z)
	if on_map(bridge):
		var left := project(bridge-Vector2(Bridge.HALF_SPAN+Bridge.RAMP,0))
		var right := project(bridge+Vector2(Bridge.HALF_SPAN+Bridge.RAMP,0))
		left.x = clampf(left.x,map_rect.position.x,map_rect.end.x)
		right.x = clampf(right.x,map_rect.position.x,map_rect.end.x)
		draw_line(left,right,Color(0.30,0.15,0.08),maxf(4.0,zoom*2.0))
	var actor := Vector2(player.global_position.x,player.global_position.z)
	if on_map(actor):
		draw_circle(project(actor),7,Color(0.97,0.9,0.65))
		draw_circle(project(actor),4,Color(0.65,0.19,0.10))
	if is_finite(waypoint.x) and on_map(waypoint):
		var pin := project(waypoint)
		draw_circle(pin,7,Color(0.87,0.56,0.18))
		draw_circle(pin,3,INK)
		caption(pin+Vector2(10,-8),"%.0f m"%actor.distance_to(waypoint),16)
	caption(map_rect.position+Vector2(map_rect.size.x-23,23),"N ↑",19)
	var bar := map_rect.position+Vector2(15,map_rect.size.y-18)
	var scale_m := 500.0 if view_extent()>=1000.0 else (200.0 if view_extent()>=400.0 else 100.0)
	draw_line(bar,bar+Vector2(scale_m/view_extent()*edge,0),INK,2)
	caption(bar-Vector2(0,7),"%d m"%int(scale_m),15)
	caption(Vector2(paper.position.x,paper.end.y+26),"Wheel zoom  ·  Drag pan  ·  Click mark  ·  Right click clear  ·  R reset  ·  M close",17,Color(0.92,0.87,0.72))
