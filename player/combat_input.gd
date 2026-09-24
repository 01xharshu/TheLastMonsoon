extends Node
## One attack dispatcher: mouse double click kicks; a single click uses the held weapon.
const DOUBLE_CLICK_SECONDS := 0.26
var pending_single := false
var click_age := 0.0
var kick_time := -1.0
var punch_time := -1.0
var kick_cooldown := 0.0
@onready var actor: CharacterBody3D = get_parent()
@onready var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
@onready var camera: Camera3D = actor.get_node("CameraPivot/SpringArm3D/Camera3D")

func available() -> bool:
	return actor.is_physics_processing() and not actor.is_swimming and (not actor.has_meta("mounted_vehicle") or actor.get_meta("mounted_vehicle") == null) and not actor.get_meta("climbing",false) and not actor.inventory_ui.is_open() and not actor.get_meta("map_open",false) and not actor.get_meta("scroll_open",false) and not actor.get_meta("weapon_wheel_open",false) and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless")

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("attack") or not available(): return
	if event is InputEventMouseButton:
		if pending_single and click_age <= DOUBLE_CLICK_SECONDS:
			pending_single = false
			kick()
		else:
			pending_single = true
			click_age = 0.0
	else:
		# Controller trigger presses remain immediate; there is no mouse double-click delay.
		single_attack()
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	kick_cooldown = maxf(0.0,kick_cooldown-delta)
	if pending_single:
		click_age += delta
		if click_age > DOUBLE_CLICK_SECONDS:
			pending_single = false
			if available(): single_attack()
	if kick_time >= 0.0:
		kick_time += delta
		visual.kick_phase = minf(kick_time/.52,1.0)
		if kick_time >= .52:
			kick_time = -1.0
			visual.kick_phase = -1.0
	if punch_time >= 0.0:
		punch_time += delta
		visual.punch_phase = minf(punch_time/.42,1.0)
		if punch_time >= .42:
			punch_time = -1.0
			visual.punch_phase = -1.0

func single_attack() -> void:
	var gear: Node3D = visual.equipment
	if gear == null: return
	if gear.stowed or not gear.owns(gear.selected):
		punch()
		return
	match gear.selected:
		0: actor.get_node("TalwarSlash").strike()
		1: actor.get_node("RifleCombat").fire()
		2: actor.get_node("BowCombat").fire()
		3: actor.get_node("PistolCombat").fire()
		4: actor.get_node("KnifeStrike").strike()
		5: actor.get_node("DoubleGunCombat").fire()

func punch() -> void:
	if punch_time >= 0.0: return
	punch_time = 0.0
	ControllerFeedback.pulse("melee")
	_melee_hit(1.35,12.0)

func kick() -> void:
	if kick_cooldown > 0.0 or not available(): return
	kick_cooldown = .65
	kick_time = 0.0
	ControllerFeedback.pulse("melee")
	_melee_hit(1.65,20.0)

func _melee_hit(reach: float, damage: float) -> void:
	var direction := -camera.global_basis.z
	var origin := actor.global_position+Vector3.UP*1.05
	var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*reach)
	query.exclude = [actor.get_rid()]
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_method("take_damage"):
		hit.collider.take_damage(damage)
