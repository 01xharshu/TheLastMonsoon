extends Control
## Circular heading-up radar: shared raster and waypoint, no extra world camera.
var map: Control
var elapsed := 0.0
var heading := 0.0
var radar_material: ShaderMaterial
const RANGE := 120.0 # 60 m around the player; local street navigation.
const GOLD := Color(1.0,0.76,0.12)
const CENTRE := Vector2(90,90)
const RADIUS := 84.0
func _ready() -> void:
	name = "Minimap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -200
	offset_top = -200
	offset_right = -20
	offset_bottom = -20
	map.refresh_sites.call_deferred()
	var terrain_view := ColorRect.new()
	terrain_view.position = Vector2(6,6)
	terrain_view.size = Vector2(168,168)
	terrain_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	terrain_view.show_behind_parent = true
	radar_material = ShaderMaterial.new()
	radar_material.shader = preload("res://player/minimap.gdshader")
	radar_material.set_shader_parameter("terrain",map.terrain)
	terrain_view.material = radar_material
	add_child(terrain_view)
	_refresh()
func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 0.1: return
	elapsed = 0
	_refresh()
func _refresh() -> void:
	if not is_instance_valid(map): return
	var camera := get_viewport().get_camera_3d()
	heading = camera.global_rotation.y if camera != null else map.player.rotation.y
	var actor := Vector2(map.player.global_position.x,map.player.global_position.z)
	radar_material.set_shader_parameter("world_center",(actor+Vector2.ONE*map.Layout.HALF)/map.Layout.SIZE)
	radar_material.set_shader_parameter("world_span",RANGE/map.Layout.SIZE)
	radar_material.set_shader_parameter("heading",heading)
	queue_redraw()
func point(world: Vector2, actor: Vector2) -> Vector2:
	return CENTRE+((world-actor)/RANGE*RADIUS*2.0).rotated(heading)
func _draw() -> void:
	if not is_instance_valid(map) or map.terrain == null: return
	var actor := Vector2(map.player.global_position.x,map.player.global_position.z)
	# Draw authored roads with true circular clipping, using the same heading as terrain.
	for route in map.Layout.ROUTES.values():
		for index in range(route.size()-1): _road_line(point(route[index],actor),point(route[index+1],actor))
	for route in map.density_routes:
		for index in range(route.size()-1):_road_line(point(route[index],actor),point(route[index+1],actor))
	for site in map.density_homes:
		var at:=point(site.p,actor)
		if at.distance_to(CENTRE)<RADIUS-5:draw_rect(Rect2(at-Vector2(2,2),Vector2(4,4)),Color(.37,.25,.16))
	for z in range(int(actor.y-RANGE),int(actor.y+RANGE),8):
		_road_line(point(Vector2(map.layout.road_x(z),z),actor),point(Vector2(map.layout.road_x(z+8),z+8),actor))
	for site in map.sites:
		var at := point(map.sites[site],actor)
		if at.distance_to(CENTRE)<RADIUS-10: draw_texture_rect(map.icons[map.site_kind(site)],Rect2(at-Vector2(6,6),Vector2(12,12)),false,Color(.3,.2,.1))
	draw_colored_polygon(PackedVector2Array([CENTRE+Vector2(0,-8),CENTRE+Vector2(5,5),CENTRE+Vector2(0,2),CENTRE+Vector2(-5,5)]),Color(.97,.94,.83))
	if map.waypoint.is_finite():
		var at := point(map.waypoint,actor)
		var offset := at-CENTRE
		if offset.length() > RADIUS-10:
			var direction := offset.normalized()
			var side := direction.orthogonal()
			at = CENTRE+direction*(RADIUS-10)
			draw_colored_polygon(PackedVector2Array([at+direction*6,at-direction*5+side*5,at-direction*2,at-direction*5-side*5]),GOLD)
		else:
			draw_colored_polygon(PackedVector2Array([at+Vector2(0,-6),at+Vector2(6,0),at+Vector2(0,6),at+Vector2(-6,0)]),GOLD)
			draw_circle(at,2,Color(.15,.12,.05))
	draw_arc(CENTRE,RADIUS+2,0,TAU,96,Color(.04,.05,.04,.9),4,true)
	draw_arc(CENTRE,RADIUS+3,0,TAU,96,Color(.82,.66,.38),1,true)
	var north := CENTRE+Vector2(0,-RADIUS+13).rotated(heading)
	draw_string(map.FONT,north+Vector2(-5,5),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(.95,.9,.75))

func _road_line(start: Vector2, end: Vector2) -> void:
	var p := start-CENTRE
	var delta := end-start
	var a := delta.length_squared()
	if a < .001: return
	var b := 2.0*p.dot(delta)
	var c := p.length_squared()-RADIUS*RADIUS
	var discriminant := b*b-4.0*a*c
	if discriminant < 0: return
	var low := maxf(0.0,(-b-sqrt(discriminant))/(2.0*a))
	var high := minf(1.0,(-b+sqrt(discriminant))/(2.0*a))
	if low <= high: draw_line(start+delta*low,start+delta*high,Color(.42,.29,.14),2,true)
