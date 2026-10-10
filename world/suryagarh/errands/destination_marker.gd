extends Control
## Camera-projected destination guidance; never moves or steers the player.
const FONT = preload("res://assets/ui/fonts/MFBOldstyle-Regular.otf")
const GOLD := Color(.86,.77,.32)
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
	var rebellion: Node=actor.get_parent().get_node_or_null("RebellionStory")
	if rebellion!=null and rebellion.stage!="dormant":destination=rebellion.destination()
	var tutorial: Node=actor.get_node_or_null("UI/HUDRoot/MorningTutorial")
	var teaching: bool=actor.get_meta("morning_tutorial_active",false)
	var horse_lesson: bool=teaching and tutorial!=null and tutorial.step==10
	if horse_lesson and is_instance_valid(tutorial.horse):
		destination={"position":tutorial.horse.global_position+Vector3.UP*1.2,"label":"Arjun’s horse","endpoint":""}
	visible = (not teaching or horse_lesson) and not actor.get_meta("opening_active",false) and not actor.get_meta("story_cinematic",false) and not destination.is_empty() and not get_tree().paused and actor.health > 0
	visible = visible and not actor.get_meta("map_open",false) and not actor.get_meta("scroll_open",false) and not actor.get_meta("weapon_wheel_open",false) and not actor.inventory_ui.is_open()
	if not visible: return
	var camera := get_viewport().get_camera_3d()
	if camera == null: hide(); return
	var goal: Vector3 = destination.position
	distance_m = Vector2(actor.global_position.x,actor.global_position.z).distance_to(Vector2(goal.x,goal.z))
	caption = destination.label
	objective_text = manager.tracked_objective() if not manager.active.is_empty() else "Go to the marked destination"
	var inquiry: Node=actor.get_parent().get_node_or_null("DevInquiry")
	if manager.active.is_empty() and inquiry!=null and inquiry.configured and inquiry.stage!="dormant":
		objective_text=inquiry.objective.text
		var story: Node=actor.get_parent().get_node_or_null("DevStory")
		if story!=null and story.state in ["farm","complete"]:objective_text=story.objective.text
	if rebellion!=null and rebellion.stage!="dormant":objective_text=rebellion.objective()
	if teaching:objective_text=""
	arrived = false
	if destination.get("endpoint","") != "": arrived = manager._near(destination.endpoint)
	else: arrived = distance_m <= 3.0
	distance_text = "%dm" % roundi(distance_m)
	var logical_point := get_global_transform_with_canvas().affine_inverse() * camera.unproject_position(goal)
	var center := size*.5
	var behind := camera.is_position_behind(goal)
	var offset := logical_point-center
	if behind:
		offset = -offset
		if offset.length_squared() < 1.0: offset = Vector2(-1,0)
	if not offset.is_finite(): offset = Vector2(-1,0)
	var safe := Rect2(Vector2(44,150),size-Vector2(88,290))
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
	var p:=marker_position
	_symbol(p)
	if at_edge:
		var axis:=direction.normalized();var side:=axis.orthogonal()
		var center:=p+axis*25
		draw_polyline(PackedVector2Array([center-axis*4+side*6,center+axis*3,center-axis*4-side*6]),GOLD,2.0,true)
	_text(p+Vector2(0,-25),distance_text,18,GOLD)
	if objective_text.is_empty():return
	_symbol(Vector2(48,48),.8)
	var words:=objective_text.split(" ")
	var lines: Array[String]=[""]
	for word in words:
		var candidate:=lines[-1]+(" " if not lines[-1].is_empty() else "")+word
		if FONT.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x>430 and not lines[-1].is_empty():lines.append(word)
		else:lines[-1]=candidate
	for i in lines.size():
		var at:=Vector2(70,54+i*24)
		draw_string(FONT,at+Vector2(1,1),lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color(.03,.03,.02,.8))
		draw_string(FONT,at,lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,19,GOLD)
func _symbol(at: Vector2,scale_factor: float=1.0) -> void:
	var shape:=PackedVector2Array([Vector2(0,-13),Vector2(4,-7),Vector2(4,-4),Vector2(7,-4),Vector2(13,0),Vector2(7,4),Vector2(4,4),Vector2(4,7),Vector2(0,13),Vector2(-4,7),Vector2(-4,4),Vector2(-7,4),Vector2(-13,0),Vector2(-7,-4),Vector2(-4,-4),Vector2(-4,-7),Vector2(0,-13)])
	for i in shape.size():shape[i]=at+shape[i]*scale_factor
	draw_polyline(shape,Color(.035,.03,.015,.65),4*scale_factor,true)
	draw_polyline(shape,GOLD,2*scale_factor,true)

func _text(at: Vector2, text: String, font_size: int, color: Color) -> void:
	var width := FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var origin := at-Vector2(width*.5,0)
	draw_string(FONT,origin+Vector2(2,2),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color.BLACK)
	draw_string(FONT,origin,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
