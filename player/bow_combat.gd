extends Node
## Hold RMB to draw, left-click to loose one carried arrow.
const PROJECTILE = preload("res://environment/weapons/period_arrow/arrow_projectile.gd")
const DRAW_SECONDS := 0.8
var aiming := false
var draw_fraction := 0.0
var arrows_fired := 0
@onready var actor: CharacterBody3D = get_parent()
@onready var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
@onready var camera: Camera3D = actor.get_node("CameraPivot/SpringArm3D/Camera3D")

func available() -> bool:
	var equipment: Node3D = visual.equipment
	return equipment != null and actor.is_physics_processing() and not actor.is_swimming and not actor.has_meta("mounted_vehicle") and not actor.get_meta("climbing",false) and not actor.inventory_ui.is_open() and not actor.get_meta("map_open",false) and not actor.get_meta("scroll_open",false) and not actor.get_meta("weapon_wheel_open",false) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not equipment.stowed and equipment.selected == 2

func _unhandled_input(event: InputEvent) -> void:
	if not available(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if aiming and draw_fraction >= 0.95: fire()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not available():
		aiming = false
		draw_fraction = 0.0
	else:
		aiming = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		draw_fraction = move_toward(draw_fraction,1.0 if aiming else 0.0,delta/DRAW_SECONDS)
		if aiming:
			var local_direction: Vector3 = actor.global_basis.inverse()*(-camera.global_basis.z)
			actor.get_node("VisualRoot").rotation.y = atan2(local_direction.x,local_direction.z)
	var bow: Node3D = visual.equipment.bow_hand
	if bow and bow.has_method("set_draw_fraction"): bow.set_draw_fraction(draw_fraction)

func fire() -> bool:
	if not available() or not aiming or draw_fraction < 0.95: return false
	if not actor.inventory.remove_item("arrow",1):
		actor.inventory.message_requested.emit("No arrows in the quiver")
		return false
	var origin: Vector3 = visual.equipment.bow_hand.to_global(Vector3(-.12,0,0))
	var target := camera.global_position - camera.global_basis.z * 180.0
	var aim_query := PhysicsRayQueryParameters3D.create(camera.global_position,target)
	aim_query.exclude = [actor.get_rid()]
	var camera_hit := actor.get_world_3d().direct_space_state.intersect_ray(aim_query)
	if not camera_hit.is_empty(): target = camera_hit.position
	var arrow: Node3D = PROJECTILE.new()
	actor.get_parent().add_child(arrow)
	arrow.launch(origin,(target-origin).normalized(),actor)
	arrows_fired += 1
	draw_fraction = 0.0
	visual.equipment.bow_hand.set_draw_fraction(0.0)
	return true
