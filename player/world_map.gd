extends Control
## North-up field map; surveyed routes and sites come from SuryagarhLayout.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const Bridge = preload("res://world/suryagarh/timber_bridge.gd")
const FONT = preload("res://assets/ui/fonts/MFBOldstyle-Regular.otf")
const INK := Color(0.20,0.17,0.12)
const MAP_TEXTURE := "res://world/suryagarh/generated/field_map.res"
var icons: Dictionary = {}
var map_canvas: Control
var minimap: Control
var marker: Node3D
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
var sites: Dictionary = {}
var selected_site := ""

func refresh_sites() -> void:
	sites = Layout.SITES.duplicate()
	sites.erase("Trading settlement reserve")
	sites.erase("Old fort reserve")
	sites.erase("Company compound")
	sites.merge(preload("res://player/map_infrastructure.gd").collect(player.get_parent()),true)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	map_canvas = preload("res://player/map_canvas.gd").new()
	map_canvas.map = self
	map_canvas.clip_contents = true
	map_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map_canvas)
	resized.connect(func(): _update_map_area(); queue_redraw())
	_update_map_area.call_deferred()
	for kind in ["house", "port", "military", "trade", "nature", "water", "bridge", "parking", "clinic", "church", "stable", "jail", "civic", "treasury", "cemetery"]:
		icons[kind] = load("res://assets/ui/map_icons/%s.svg" % kind)
	marker = preload("res://player/world_waypoint.gd").new()
	marker.map = self
	player.get_parent().add_child.call_deferred(marker)
	refresh_sites()
	# Keep the field map usable while an optional minimap module is unavailable.
	if ResourceLoader.exists("res://player/minimap.gd"):
		var minimap_script: Script = load("res://player/minimap.gd")
		if minimap_script != null:
			minimap = minimap_script.new()
			minimap.map = self
			player.get_node("UI/HUDRoot").add_child.call_deferred(minimap)
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
	if visible and SaveManager.active_input_device == "controller" and event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A:
				select_point(map_rect.get_center())
				queue_redraw()
			JOY_BUTTON_B:
				player.get_parent().get_node("GameMenu").close()
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
	if visible and event.keycode == KEY_R:
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
				map_center = before-(event.position-map_rect.get_center())/map_rect.size*view_span()
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
				if not dragged and map_rect.has_point(event.position): select_point(event.position)
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
				map_center -= event.relative/map_rect.size*view_span()
				clamp_center()
		hovered_site = ""
		for site in sites:
			if project(sites[site]).distance_to(event.position)<12.0: hovered_site = site
		queue_redraw()

func set_open(open: bool) -> void:
	if visible == open: return
	visible = open
	player.set_meta("map_open",open)
	if open:
		refresh_sites()
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

func _travel_pressed() -> void:
	var boarding: Node = (player.get_meta("mounted_vehicle") if player.has_meta("mounted_vehicle") else null)
	if not is_instance_valid(boarding) or player.get_meta("cart_role", "") != "passenger": return
	if boarding.travel.payer != null:
		boarding.travel.cancel()
		player.get_parent().get_node("GameMenu").close()
	elif boarding.travel.request_goal(waypoint):
		player.get_parent().get_node("GameMenu").close()

func view_extent() -> float:
	return Layout.SIZE/zoom

func view_span() -> Vector2:
	return Vector2(view_extent(),view_extent()*map_rect.size.y/maxf(map_rect.size.x,1.0))

func clamp_center() -> void:
	var limit := Vector2.ONE*Layout.HALF-view_span()*0.5
	map_center.x = clampf(map_center.x,-limit.x,limit.x)
	map_center.y = clampf(map_center.y,-limit.y,limit.y)

func project(p: Vector2) -> Vector2:
	return map_rect.get_center()+(p-map_center)/view_span()*map_rect.size

func unproject(screen: Vector2) -> Vector2:
	return map_center+(screen-map_rect.get_center())/map_rect.size*view_span()

func on_map(p: Vector2) -> bool:
	return map_rect.has_point(project(p))

func caption(p: Vector2, value: String, font_size := 17, color := INK) -> void:
	map_canvas.draw_string(FONT,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func draw_route(points: Array, color: Color, width: float) -> void:
	for i in range(points.size()-1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i+1]
		var count := maxi(1,ceili(a.distance_to(b)/8.0))
		for step in count:
			var pa: Vector2 = a.lerp(b,float(step)/count)
			var pb: Vector2 = a.lerp(b,float(step+1)/count)
			if on_map(pa) and on_map(pb): map_canvas.draw_line(project(pa),project(pb),color,width,true)

func _draw() -> void:
	if not visible or terrain == null: return
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,0.035,0.025,0.98))
	_update_map_area()
	var paper := map_rect.grow(12)
	draw_rect(paper,Color(0.86,0.81,0.66))
	map_canvas.position = map_rect.position
	map_canvas.size = map_rect.size
	map_canvas.queue_redraw()
	var legend_index := 0
	for kind in icons:
		var at := Vector2(20,108+legend_index*minf(36,(size.y-132)/15.0))
		draw_texture_rect(icons[kind],Rect2(at,Vector2(22,22)),false)
		draw_string(FONT,at+Vector2(28,17),str(kind).capitalize(),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.92,0.87,0.72))
		legend_index += 1

func site_kind(label: String) -> String:
	var name_lower := label.to_lower()
	for pair in [["hospital","clinic"],["church","church"],["cemetery","cemetery"],["stable","stable"],["jail","jail"],["treasury","treasury"],["court","civic"],["hall","civic"],["collectorate","civic"],["parking","parking"],["bridge","bridge"],["port","port"],["ship","port"],["landing","port"],["well","water"],["hospital","military"],["barrack","military"],["cantonment","military"],["police","military"],["armoury","military"],["fort","military"],["bazaar","trade"],["store","trade"],["warehouse","trade"],["shrine","nature"],["forest","nature"]]:
		if pair[0] in name_lower: return pair[1]
	return "house"

func select_point(screen: Vector2) -> void:
	selected_site = ""
	var nearest := 16.0
	for site in sites:
		var distance := project(sites[site]).distance_to(screen)
		if distance < nearest:
			nearest = distance
			selected_site = site
	waypoint = sites[selected_site] if selected_site != "" else unproject(screen)
	if selected_site != "" and zoom < 4.0:
		map_center = waypoint
		zoom = 4.0
		clamp_center()
	queue_redraw()

func draw_map_contents() -> void:
	map_canvas.draw_set_transform(-map_rect.position)
	var origin := map_center-view_span()*0.5
	var source := Rect2((origin+Vector2.ONE*Layout.HALF)/Layout.SIZE*terrain.get_size(),view_span()/Layout.SIZE*terrain.get_size())
	map_canvas.draw_texture_rect_region(terrain,map_rect,source)
	map_canvas.draw_rect(map_rect,INK,false,1)
	var road: Array[Vector2] = []
	for z in range(-864,865,8): road.append(Vector2(layout.road_x(z),z))
	draw_route(road,Color(0.48,0.31,0.17),maxf(2.0,zoom))
	var lane: Array[Vector2] = []
	for x in range(-280,90,4): lane.append(Vector2(x,160+12*sin(x*0.017)))
	draw_route(lane,Color(0.48,0.31,0.17),maxf(2.0,zoom))
	for route in Layout.ROUTES.values(): draw_route(route,Color(0.48,0.31,0.17),maxf(2.0,zoom))
	var drawn: Array[Vector2] = []
	var clusters: Dictionary = {}
	for site in sites:
		var p: Vector2 = sites[site]
		if not on_map(p): continue
		var screen := project(p)
		if zoom < 4.0 and hovered_site != site and selected_site != site:
			var overlaps := false
			for prior in drawn:
				if prior.distance_to(screen) < 20:
					clusters[prior] = int(clusters.get(prior,1))+1
					overlaps = true
					break
			if overlaps: continue
		drawn.append(screen)
		map_canvas.draw_texture_rect(icons[site_kind(site)], Rect2(project(p)-Vector2(10,10),Vector2(20,20)), false, Color(0.32,0.25,0.14))
		if hovered_site == site or selected_site == site:
			var label := project(p)+Vector2(7,-6)
			var width := FONT.get_string_size(site,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
			if label.x+width > map_rect.end.x-7: label.x = project(p).x-width-7
			if label.y < map_rect.position.y+17: label.y += 23
			caption(label,site,16)
	for cluster in clusters:
		map_canvas.draw_circle(cluster+Vector2(9,-9),8,Color(0.86,0.81,0.66))
		caption(cluster+Vector2(5,-5),str(clusters[cluster]),11)
	var bridge := Vector2(layout.river_x(Bridge.CROSSING_Z),Bridge.CROSSING_Z)
	if on_map(bridge):
		var left := project(bridge-Vector2(Bridge.HALF_SPAN+Bridge.RAMP,0))
		var right := project(bridge+Vector2(Bridge.HALF_SPAN+Bridge.RAMP,0))
		left.x = clampf(left.x,map_rect.position.x,map_rect.end.x)
		right.x = clampf(right.x,map_rect.position.x,map_rect.end.x)
		map_canvas.draw_line(left,right,Color(0.30,0.15,0.08),maxf(4.0,zoom*2.0))
	var actor := Vector2(player.global_position.x,player.global_position.z)
	if on_map(actor):
		map_canvas.draw_circle(project(actor),7,Color(0.97,0.9,0.65))
		map_canvas.draw_circle(project(actor),4,Color(0.65,0.19,0.10))
	if is_finite(waypoint.x):
		var pin := project(waypoint)
		pin.x = clampf(pin.x,map_rect.position.x+10,map_rect.end.x-10)
		pin.y = clampf(pin.y,map_rect.position.y+10,map_rect.end.y-10)
		map_canvas.draw_colored_polygon(PackedVector2Array([pin+Vector2(0,-8),pin+Vector2(8,0),pin+Vector2(0,8),pin+Vector2(-8,0)]),Color(1,.76,.12))
		map_canvas.draw_circle(pin,3,INK)
		caption(Vector2(minf(pin.x+10,map_rect.end.x-65),minf(pin.y+24,map_rect.end.y-5)),"%.0f m"%actor.distance_to(waypoint),16)
	caption(map_rect.position+Vector2(map_rect.size.x-23,23),"N ↑",19)
	var bar := map_rect.position+Vector2(15,map_rect.size.y-18)
	var scale_m := 500.0 if view_extent()>=1000.0 else (200.0 if view_extent()>=400.0 else 100.0)
	map_canvas.draw_line(bar,bar+Vector2(scale_m/view_extent()*map_rect.size.x,0),INK,2)
	caption(bar-Vector2(0,7),"%d m"%int(scale_m),15)

func _update_map_area() -> void:
	var sidebar := minf(240.0,size.x*0.24)
	map_rect = Rect2(Vector2(sidebar+28,100),Vector2(maxf(1,size.x-sidebar-56),maxf(1,size.y-128)))
	clamp_center()
	map_canvas.position = map_rect.position
	map_canvas.size = map_rect.size
