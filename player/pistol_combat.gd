extends Node
## Adams sidearm: RMB aligns the muzzle, LMB fires, R loads carried balls.
const CAPACITY := 5
const RELOAD_SECONDS := 3.8
const MUZZLE := Vector3(.175,.064,0)
var rounds := CAPACITY
var reload_remaining := 0.0
var aiming := false
var shots_fired := 0
@onready var actor: CharacterBody3D = get_parent()
@onready var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
@onready var camera: Camera3D = actor.get_node("CameraPivot/SpringArm3D/Camera3D")

func available() -> bool:
	var equipment: Node3D = visual.equipment
	return equipment != null and actor.is_physics_processing() and not actor.is_swimming and not actor.has_meta("mounted_vehicle") and not actor.get_meta("climbing",false) and not actor.inventory_ui.is_open() and not actor.get_meta("map_open",false) and not actor.get_meta("scroll_open",false) and not actor.get_meta("weapon_wheel_open",false) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not equipment.stowed and equipment.selected == 3

func _unhandled_input(event: InputEvent) -> void:
	if not available(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if aiming: fire()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		start_reload()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if reload_remaining > 0.0:
		reload_remaining = maxf(0.0,reload_remaining-delta)
		if reload_remaining == 0.0: _finish_reload()
	aiming = available() and reload_remaining == 0.0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if not available(): return
	var hand: Node3D = visual.equipment.pistol_hand
	if aiming:
		var barrel := (-camera.global_basis.z).normalized()
		var side := barrel.cross(Vector3.UP).normalized()
		if side.length_squared() < 0.1: side = Vector3.LEFT
		hand.global_basis = Basis(barrel,side.cross(barrel),side)
		var local_direction: Vector3 = actor.global_basis.inverse()*barrel
		actor.get_node("VisualRoot").rotation.y = atan2(local_direction.x,local_direction.z)

func fire() -> bool:
	if not available() or not aiming or reload_remaining > 0.0: return false
	if rounds <= 0:
		actor.inventory.message_requested.emit("Pistol empty · press R to reload")
		return false
	rounds -= 1
	shots_fired += 1
	var origin: Vector3 = visual.equipment.pistol_hand.to_global(MUZZLE)
	var target := camera.global_position-camera.global_basis.z*90.0
	var camera_query := PhysicsRayQueryParameters3D.create(camera.global_position,target)
	camera_query.exclude = [actor.get_rid()]
	var camera_hit := actor.get_world_3d().direct_space_state.intersect_ray(camera_query)
	if not camera_hit.is_empty(): target = camera_hit.position
	var shot_query := PhysicsRayQueryParameters3D.create(origin,target+(target-origin).normalized()*.05)
	shot_query.exclude = [actor.get_rid()]
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(shot_query)
	if not hit.is_empty() and hit.collider.has_method("take_damage"):
		hit.collider.take_damage(38.0)
	return true

func start_reload() -> bool:
	if not available() or reload_remaining > 0.0 or rounds >= CAPACITY or actor.inventory.get_item_count("pistol_ball") <= 0: return false
	reload_remaining = RELOAD_SECONDS
	return true

func _finish_reload() -> void:
	var amount := mini(CAPACITY-rounds,actor.inventory.get_item_count("pistol_ball"))
	if amount > 0 and actor.inventory.remove_item("pistol_ball",amount): rounds += amount

func get_hud_text() -> String:
	if not available(): return visual.equipment.held_name()
	if reload_remaining > 0: return "ADAMS · RELOADING %.1fs" % reload_remaining
	return "ADAMS · %d / %d" % [rounds,actor.inventory.get_item_count("pistol_ball")]
