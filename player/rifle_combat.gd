extends Node
## Single-shot Enfield prototype. Camera selects the aim point; muzzle ray prevents cover bypass.
const SHOT = preload("res://audio/weapons/enfield_shot.wav")
const RELOAD = preload("res://audio/weapons/enfield_reload.wav")
const EMPTY = preload("res://audio/weapons/enfield_empty.wav")
const PISTOL_SHOT = preload("res://audio/weapons/adams_shot.wav")
const RELOAD_SECONDS := 5.0
@export var weapon_selection := 1
var rounds := 1
var pending_rounds := 0
const MUZZLE := Vector3(1.04,0.057,0)
var loaded := true
var reload_remaining := 0.0
var aiming := false
var recoil := 0.0
var shots_fired := 0
var impacts: Array[Node3D] = []
var mark_material: StandardMaterial3D
var sound: AudioStreamPlayer3D
func pistol() -> bool: return weapon_selection == 3
func double_gun() -> bool: return weapon_selection == 5
func capacity() -> int: return 5 if pistol() else (2 if double_gun() else 1)
func ammo_id() -> String: return "pistol_ball" if pistol() else ("shot_charge" if double_gun() else "paper_cartridges")
@onready var actor: CharacterBody3D = get_parent()
@onready var visual = actor.get_node("VisualRoot/CharacterVisual")
@onready var camera: Camera3D = actor.get_node("CameraPivot/SpringArm3D/Camera3D")

func _ready() -> void:
	if pistol(): rounds = 5
	if double_gun(): rounds = 0
	sound = AudioStreamPlayer3D.new()
	sound.max_distance = 180
	sound.volume_db = -8
	actor.add_child.call_deferred(sound)
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var distance := Vector2(x-31.5,y-31.5).length()/31.5
			var alpha := clampf((1.0-distance)*3.0,0,1)
			image.set_pixel(x,y,Color(0.075,0.055,0.035,alpha*.92))
	mark_material = StandardMaterial3D.new()
	mark_material.albedo_texture = ImageTexture.create_from_image(image)
	mark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mark_material.cull_mode = BaseMaterial3D.CULL_DISABLED

func available() -> bool:
	var equipment = visual.equipment
	return actor.is_physics_processing() and not actor.is_swimming and (not actor.has_meta("mounted_vehicle") or actor.get_meta("mounted_vehicle") == null) and not actor.get_meta("climbing",false) and not actor.inventory_ui.is_open() and not actor.get_meta("map_open",false) and not actor.get_meta("weapon_wheel_open",false) and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless") and not equipment.stowed and equipment.selected == weapon_selection

func _unhandled_input(event: InputEvent) -> void:
	if not available(): return
	if event.is_action_pressed("reload"):
		start_reload()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not available():
		aiming = false
	else:
		aiming = Input.is_action_pressed("aim") and reload_remaining<=0
		if reload_remaining>0:
			reload_remaining = maxf(0,reload_remaining-delta)
			if reload_remaining==0:
				rounds = mini(capacity(),rounds+pending_rounds)
				loaded = rounds>0
				pending_rounds = 0
	recoil = move_toward(recoil,0,delta*.32)
	if visual.equipment.selected == weapon_selection:
		visual.equipment.aiming = aiming
		visual.equipment.recoil = recoil
		visual.equipment.aim_direction = -camera.global_basis.z
	if aiming:
		var local_direction: Vector3 = actor.global_basis.inverse()*(-camera.global_basis.z)
		actor.get_node("VisualRoot").rotation.y = atan2(local_direction.x,local_direction.z)

func start_reload() -> void:
	if not available() or rounds>=capacity() or reload_remaining>0: return
	pending_rounds = mini(capacity()-rounds,actor.inventory.get_item_count(ammo_id()))
	if pending_rounds==0 or not actor.inventory.remove_item(ammo_id(),pending_rounds):
		actor.inventory.message_requested.emit("No ammunition · search a Company store")
		sound.stream = EMPTY
		sound.play()
		return
	reload_remaining = 3.5 if pistol() else (4.4 if double_gun() else RELOAD_SECONDS)
	sound.stream = RELOAD
	sound.play()

func fire() -> void:
	if not available() or not aiming or reload_remaining>0: return
	if rounds <= 0:
		sound.stream = EMPTY
		sound.play()
		return
	rounds -= 1
	loaded = rounds>0
	shots_fired += 1
	ControllerFeedback.pulse("shot")
	visual.equipment.apply_rifle_grip()
	var origin: Vector3 = visual.equipment.pistol_hand.to_global(Vector3(.17,0,.064)) if pistol() else (visual.equipment.double_hand.to_global(Vector3(1.0,0,.035)) if double_gun() else visual.equipment.enfield_hand.to_global(MUZZLE))
	var direction: Vector3 = -camera.global_basis.z
	var target := camera.global_position+direction*350.0
	var space := actor.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,target)
	query.exclude = [actor.get_rid()]
	var camera_hit := space.intersect_ray(query)
	if not camera_hit.is_empty(): target = camera_hit.position
	query.from = origin
	if double_gun():
		var aim: Vector3 = (target-origin).normalized()
		var right: Vector3 = aim.cross(Vector3.UP).normalized()
		if right.length_squared() < .1: right = Vector3.RIGHT
		var up: Vector3 = right.cross(aim).normalized()
		for i in 8:
			var angle := TAU*float(i)/8.0
			var spread := .012 if i == 0 else .032
			query.to = origin + (aim + right*cos(angle)*spread + up*sin(angle)*spread).normalized()*55.0
			var pellet_hit := space.intersect_ray(query)
			if not pellet_hit.is_empty():
				if i < 3: add_impact(pellet_hit)
				if pellet_hit.collider.has_method("take_damage"): pellet_hit.collider.take_damage(11.0)
	else:
		query.to = target+(target-origin).normalized()*0.05
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			add_impact(hit)
			if hit.collider.has_method("take_damage"): hit.collider.take_damage(35.0 if pistol() else 60.0)
	recoil = 0.065
	sound.global_position = origin
	sound.stream = PISTOL_SHOT if pistol() else SHOT
	sound.volume_db = -15 if pistol() else -8
	sound.play()
	muzzle_effect(origin)

func add_impact(hit: Dictionary) -> void:
	var mark := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.13,0.13)
	mark.mesh = mesh
	mark.material_override = mark_material
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var parent: Node = hit.collider if hit.collider is Node3D else actor.get_parent()
	parent.add_child(mark)
	var normal: Vector3 = hit.normal.normalized()
	var tangent := normal.cross(Vector3.UP if absf(normal.y)<0.95 else Vector3.RIGHT).normalized()
	mark.global_transform = Transform3D(Basis(tangent,normal.cross(tangent),normal),hit.position+normal*.012)
	impacts.append(mark)
	while impacts.size()>48:
		var old = impacts.pop_front()
		if is_instance_valid(old): old.queue_free()

func muzzle_effect(origin: Vector3) -> void:
	var flash := OmniLight3D.new()
	actor.get_parent().add_child(flash)
	flash.global_position = origin
	flash.light_color = Color(1,.65,.2)
	flash.light_energy = 3.5
	flash.omni_range = 4
	get_tree().create_timer(.065).timeout.connect(flash.queue_free)
	var smoke := CPUParticles3D.new()
	smoke.emitting = false
	smoke.one_shot = true
	smoke.amount = 18
	smoke.lifetime = .8
	smoke.explosiveness = .95
	smoke.direction = -camera.global_basis.z
	smoke.spread = 24
	smoke.initial_velocity_min = .8
	smoke.initial_velocity_max = 2.2
	smoke.gravity = Vector3(0,.4,0)
	smoke.scale_amount_min = .07
	smoke.scale_amount_max = .18
	var puff := SphereMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.65,.62,.55,.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material = material
	smoke.mesh = puff
	actor.get_parent().add_child(smoke)
	smoke.global_position = origin
	smoke.emitting = true
	get_tree().create_timer(1.0).timeout.connect(smoke.queue_free)

func get_hud_text() -> String:
	if visual.equipment.stowed or visual.equipment.selected != weapon_selection: return visual.equipment.held_name()
	var title := "ADAMS 1851" if pistol() else ("DOUBLE GUN" if double_gun() else "ENFIELD")
	if reload_remaining>0: return "%s · RELOADING %.1fs" % [title,reload_remaining]
	return "%s · %d/%d · %d SPARE" % [title,rounds,capacity(),actor.inventory.get_item_count(ammo_id())]
