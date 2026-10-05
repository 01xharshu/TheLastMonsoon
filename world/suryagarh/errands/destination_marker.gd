extends Control
## Camera-projected destination guidance; never moves or steers the player.
const FONT = preload("res://assets/ui/fonts/MFBOldstyle-Regular.otf")
const GOLD := Color(.96,.77,.37)
var manager: Node
var marker_position := Vector2.ZERO
var direction := Vector2.UP
var distance_m := 0.0
var caption := ""
var objective_text := ""
var distance_text := ""
var at_edge := false
var arrived := false
var destination: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	var actor: CharacterBody3D = manager.player
	destination = manager.destination()
	visible = not destination.is_empty() and not get_tree().paused and actor.health > 0
	visible = visible and not actor.get_meta("map_open",false) and not actor.get_meta("scroll_open",false) and not actor.get_meta("weapon_wheel_open",false) and not actor.inventory_ui.is_open()
	if not visible: return
	var camera := get_viewport().get_camera_3d()
	if camera == null: hide(); return
	var goal: Vector3 = destination.position
	distance_m = Vector2(actor.global_position.x,actor.global_position.z).distance_to(Vector2(goal.x,goal.z))
	caption = destination.label
	objective_text = manager.tracked_objective() if not manager.active.is_empty() else "Go to the marked destination"
	arrived = false
	if destination.get("endpoint","") != "": arrived = manager._near(destination.endpoint)
	else: arrived = distance_m <= 3.0
	distance_text = "%d m" % roundi(distance_m)
	var logical_point := get_global_transform_with_canvas().affine_inverse() * camera.unproject_position(goal)
	var center := size*.5
	var behind := camera.is_position_behind(goal)
	var offset := logical_point-center
	if behind:
		offset = -offset
		if offset.length_squared() < 1.0: offset = Vector2(-1,0)
	if not offset.is_finite(): offset = Vector2(-1,0)
	var safe := Rect2(Vector2(132,180),size-Vector2(264,350))
	at_edge = behind or not safe.has_point(logical_point)
	if at_edge:
		direction = offset.normalized()
		var extent := safe.size*.5
		var edge_scale := minf(extent.x/maxf(absf(direction.x),.001),extent.y/maxf(absf(direction.y),.001))
		marker_position = safe.get_center()+direction*edge_scale
	else:
		marker_position = logical_point
		direction = Vector2.UP
	queue_redraw()

func _draw() -> void:
	# Map pins use the grounded depth-tested world marker; retain edge navigation.
	if destination.get("endpoint","") == "" and not at_edge: return
	var p := marker_position
	if at_edge:
		var side := direction.orthogonal()
		draw_circle(p,15,Color(.025,.020,.015,.85))
		draw_colored_polygon(PackedVector2Array([p+direction*11,p-direction*7+side*7,p-direction*3,p-direction*7-side*7]),GOLD)
	else:
		_symbol(p)
	_text(p+Vector2(0,-25),distance_text,22,GOLD)
	if destination.get("endpoint","") == "": return
	# Matching sub-marker explains the active goal without covering the destination.
	draw_line(Vector2(36,86),Vector2(36,119),Color(.6,.6,.52,.75),2)
	_symbol(Vector2(62,102),.78)
	var words := objective_text.split(" ")
	var lines: Array[String] = [""]
	for word in words:
		var candidate := lines[-1] + (" " if not lines[-1].is_empty() else "") + word
		if FONT.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x > 430 and not lines[-1].is_empty(): lines.append(word)
		else: lines[-1] = candidate
	for index in lines.size():
		var at := Vector2(85,109+index*24)
		draw_string(FONT,at+Vector2(2,2),lines[index],HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color.BLACK)
		draw_string(FONT,at,lines[index],HORIZONTAL_ALIGNMENT_LEFT,-1,19,GOLD)

func _symbol(at: Vector2, scale_factor: float = 1.0) -> void:
	var diamond := PackedVector2Array([Vector2(0,-14),Vector2(14,0),Vector2(0,14),Vector2(-14,0)])
	var shadow := PackedVector2Array()
	for point in diamond: shadow.append(at+point*scale_factor*1.2)
	draw_colored_polygon(shadow,Color(0,0,0,.78))
	for index in diamond.size(): diamond[index] = at+diamond[index]*scale_factor
	draw_colored_polygon(diamond,GOLD)
	var cross := PackedVector2Array([Vector2(-3,-9),Vector2(3,-9),Vector2(3,-3),Vector2(9,-3),Vector2(9,3),Vector2(3,3),Vector2(3,9),Vector2(-3,9),Vector2(-3,3),Vector2(-9,3),Vector2(-9,-3),Vector2(-3,-3)])
	for index in cross.size(): cross[index] = at+cross[index]*scale_factor
	draw_colored_polygon(cross,Color(.025,.023,.016,.96))

func _text(at: Vector2, text: String, font_size: int, color: Color) -> void:
	var width := FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var origin := at-Vector2(width*.5,0)
	draw_string(FONT,origin+Vector2(2,2),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color.BLACK)
	draw_string(FONT,origin,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
