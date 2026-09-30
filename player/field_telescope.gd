extends Node
## Separate optical camera prevents weapon FOV updates from fighting telescope zoom.
var active := false
var magnification := 3.0
var camera: Camera3D
var previous_camera: Camera3D
var overlay: Control
var actor: Node3D

class LensOverlay extends Control:
	func _draw() -> void:
		var centre := size * .5
		var radius := minf(size.x, size.y) * .43
		var outer := size.length()
		var points := PackedVector2Array()
		for i in 97:
			var angle := TAU * i / 96.0
			points.append(centre + Vector2.from_angle(angle) * radius)
			points.append(centre + Vector2.from_angle(angle) * outer)
		for i in 96:
			draw_colored_polygon(PackedVector2Array([points[i*2], points[i*2+1], points[i*2+3], points[i*2+2]]), Color(.015,.012,.008))
		draw_arc(centre,radius,0,TAU,96,Color(.25,.18,.08),3,true)
		draw_string(ThemeDB.fallback_font, Vector2(24,size.y-28), "T: lower telescope   Wheel: zoom", HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(.8,.75,.63))

func _ready() -> void:
	actor = get_parent()
	camera = Camera3D.new()
	camera.name = "TelescopeCamera"
	camera.near = .08
	actor.get_node("CameraPivot").add_child(camera)
	camera.position = Vector3(0,0,-.12)
	var layer := CanvasLayer.new()
	layer.layer = 24
	add_child(layer)
	overlay = LensOverlay.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	overlay.hide()

func available() -> bool:
	if not actor.is_physics_processing(): return false
	for key in ["map_open","scroll_open","weapon_wheel_open","climbing","document_busy"]:
		if actor.get_meta(key,false): return false
	for key in ["detention_action","river_action","rest_action"]:
		if actor.get_meta(key,"") != "": return false
	var inventory_ui := actor.get_node_or_null("UI/HUDRoot/InventoryPanel")
	if inventory_ui != null and inventory_ui.has_method("is_open") and inventory_ui.is_open(): return false
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"

func set_active(enabled: bool) -> void:
	if enabled == active: return
	active = enabled
	actor.set_meta("telescope_open",active)
	overlay.visible = active
	if active:
		previous_camera = get_viewport().get_camera_3d()
		camera.fov = optical_fov(magnification)
		camera.make_current()
	else:
		if is_instance_valid(previous_camera): previous_camera.make_current()
		else: camera.clear_current()

func optical_fov(zoom: float) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(75.0)*.5)/zoom))

func zoom_by(step: float) -> void:
	magnification = clampf(magnification+step,2.0,12.0)
	camera.fov = optical_fov(magnification)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_T:
		if active or available():
			set_active(not active)
			get_viewport().set_input_as_handled()
	elif active and event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_by(.5 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -.5)
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if active:
		if not available(): set_active(false)
		else: overlay.queue_redraw()
