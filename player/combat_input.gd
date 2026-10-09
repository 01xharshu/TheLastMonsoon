extends Node
## One attack dispatcher: mouse double click kicks; a single click uses the held weapon.
const DOUBLE_CLICK_SECONDS := 0.26
var pending_single := false
var click_age := 0.0
var kick_time := -1.0
var punch_time := -1.0
var kick_cooldown := 0.0
var kick_landed := false
var punch_landed := false
var punch_damage_done:=false
var kick_damage_done:=false
var last_melee_contact:=Vector3.ZERO
var left_punch := false
var air_kick := false
var blocking := false
var dodge_time := -1.0
var dodge_cooldown := 0.0
@onready var actor: CharacterBody3D = get_parent()
@onready var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
@onready var camera: Camera3D = actor.get_node("CameraPivot/SpringArm3D/Camera3D")

func _ready() -> void:
	if not InputMap.has_action("combat_dodge"):
		InputMap.add_action("combat_dodge")
		var key:=InputEventKey.new();key.physical_keycode=KEY_X;InputMap.action_add_event("combat_dodge",key)
	var grapple := preload("res://player/rear_grapple.gd").new()
	grapple.name="RearGrapple"
	actor.call_deferred("add_child",grapple)

func available() -> bool:
	if actor.get_meta("tutorial_reading",false): return false
	if actor.get_meta("paired_combat",false): return false
	if actor.get_meta("telescope_open", false): return false
	if actor.get_meta("detention_action", "") != "": return false
	return actor.is_physics_processing() and not actor.is_swimming and (not actor.has_meta("mounted_vehicle") or actor.get_meta("mounted_vehicle") == null) and not actor.get_meta("climbing",false) and not actor.inventory_ui.is_open() and not actor.get_meta("map_open",false) and not actor.get_meta("scroll_open",false) and not actor.get_meta("weapon_wheel_open",false) and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("combat_dodge") and available():
		dodge();get_viewport().set_input_as_handled();return
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
	dodge_cooldown=maxf(0,dodge_cooldown-delta)
	blocking=available() and visual.equipment.stowed and Input.is_action_pressed("aim") and punch_time<0 and kick_time<0 and dodge_time<0
	actor.set_meta("combat_blocking",blocking)
	if dodge_time>=0:
		dodge_time+=delta
		actor.set_meta("combat_dodge_phase",minf(dodge_time/.42,1))
		if dodge_time>=.42 or not available():
			dodge_time=-1;actor.remove_meta("combat_dodge");actor.remove_meta("combat_dodge_phase")
	if actor.get_meta("detention_action", "") != "":
		pending_single = false
		kick_time = -1.0
		punch_time = -1.0
		visual.kick_phase = -1.0
		visual.punch_phase = -1.0
		return
	kick_cooldown = maxf(0.0,kick_cooldown-delta)
	if pending_single:
		click_age += delta
		if click_age > DOUBLE_CLICK_SECONDS:
			pending_single = false
			if available(): single_attack()
	if kick_time >= 0.0:
		kick_time += delta
		visual.kick_phase = minf(kick_time/.52,1.0)
		if visual.kick_phase >= .43 and visual.kick_phase <= .62:
			kick_landed = true
			if not kick_damage_done:kick_damage_done=_melee_hit(1.65,20.0)
		if kick_time >= .52:
			kick_time = -1.0
			visual.kick_phase = -1.0
	if punch_time >= 0.0:
		punch_time += delta
		visual.punch_phase = minf(punch_time/.42,1.0)
		if visual.punch_phase >= .40 and visual.punch_phase <= .62:
			punch_landed = true
			if not punch_damage_done:punch_damage_done=_melee_hit(1.35,12.0)
		if punch_time >= .42:
			punch_time = -1.0
			visual.punch_phase = -1.0

func single_attack() -> void:
	if not available() or punch_time >= 0 or kick_time >= 0 or dodge_time >= 0:return
	var kit: Node = actor.get_node_or_null("ChachaKit")
	if kit != null and kit.active:
		kit.strike()
		return
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
	if punch_time >= 0.0 or kick_time >= 0.0 or not available(): return
	WorldAudio.play_at("cloth",actor.global_position)
	punch_time = 0.0
	left_punch = not left_punch
	punch_landed = false
	punch_damage_done=false
	_face_attack()
	ControllerFeedback.pulse("melee")

func kick() -> void:
	if kick_cooldown > 0.0 or punch_time >= 0.0 or not available(): return
	kick_cooldown = .65
	WorldAudio.play_at("cloth",actor.global_position)
	kick_time = 0.0
	air_kick = not actor.is_on_floor()
	kick_landed = false
	kick_damage_done=false
	_face_attack()
	ControllerFeedback.pulse("melee")

func _face_attack() -> void:
	var direction: Vector3=-camera.global_basis.z
	actor.get_node("VisualRoot").global_rotation.y=atan2(direction.x,direction.z)

func _melee_hit(_reach: float, damage: float) -> bool:
	var kick_active:=kick_time>=0
	var bone: String="foot_r" if kick_active else "hand_l" if left_punch else "hand_r"
	visual.skeleton.force_update_all_bone_transforms()
	var point: Vector3=visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.bones[bone]).origin)
	if kick_active:point+=actor.get_node("VisualRoot").global_basis.z*.10
	last_melee_contact=point
	var query:=PhysicsShapeQueryParameters3D.new()
	var sphere:=SphereShape3D.new();sphere.radius=.15 if kick_active else .12
	query.shape=sphere;query.transform.origin=point
	query.exclude=[actor.get_rid()];query.collision_mask=9
	var policy=preload("res://combat/damage_policy.gd")
	for contact in actor.get_world_3d().direct_space_state.intersect_shape(query,8):
		var body: Object=contact.collider
		if not body.has_method("take_damage"):continue
		var sight:=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*.3,point)
		sight.exclude=[actor.get_rid()]
		var hit:=actor.get_world_3d().direct_space_state.intersect_ray(sight)
		if not hit.is_empty() and policy.receiver(hit.collider)!=policy.receiver(body):continue
		if policy.apply(body,damage,actor,"kick" if kick_active else "punch"):
			WorldAudio.play_at("impact",point,-13.0)
			return true
	return false

func dodge() -> bool:
	if dodge_cooldown>0 or not actor.is_on_floor() or punch_time>=0 or kick_time>=0 or actor.survival.stamina<20:return false
	var direction:=Input.get_vector("move_left","move_right","move_forward","move_backward")
	var local:=Vector3(direction.x,0,direction.y)
	if local.length_squared()<.1:local=Vector3.LEFT
	actor.set_meta("combat_dodge",(actor.global_basis*local).normalized())
	actor.survival.stamina-=20
	dodge_time=0;dodge_cooldown=.85
	return true

func interrupt() -> void:
	pending_single=false;punch_time=-1;kick_time=-1;dodge_time=-1
	visual.punch_phase=-1;visual.kick_phase=-1
	actor.remove_meta("combat_dodge");actor.remove_meta("combat_dodge_phase")
	var blade:=actor.get_node("TalwarSlash");blade.elapsed=blade.DURATION
	visual.slash_phase=-1
	actor.get_node("KnifeStrike").elapsed=-1;visual.knife_phase=-1
