extends Node3D
## Fort garrison firearm, using the authoritative Enfield mesh and loading contacts.
const Trace = preload("res://combat/ballistic_trace.gd")
const SCALE = preload("res://player/arjun_equipment.gd").ENFIELD_SCALE
const RELOAD = preload("res://player/enfield_loading_sequence.gd").RELOAD_SECONDS
var target: CharacterBody3D
var moving := false
var hostile := false
var cartridges := 4
var cooldown := 0.0
var aim_age := 0.0
var shots := 0
var recoil := 0.0
var dropped := false
var cartridge: Node3D
var gun: Node3D
var sound: AudioStreamPlayer3D
@onready var owner_actor: Node3D = get_parent()

func _ready() -> void:
	process_priority = 60
	gun = preload("res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb").instantiate()
	gun.name = "EnfieldHeld"
	add_child(gun)
	cartridge = preload("res://player/enfield_cartridge_visual.gd").new()
	cartridge.name = "LoadingCartridge"
	add_child(cartridge)
	cartridge.setup(Vector3.ZERO,Basis.IDENTITY)
	sound = AudioStreamPlayer3D.new()
	sound.stream = preload("res://audio/weapons/enfield_shot.wav")
	sound.max_distance = 180
	sound.volume_db = -8
	add_child(sound)

func _process(delta: float) -> void:
	cooldown = maxf(0.0,cooldown-delta)
	recoil = move_toward(recoil,0.0,delta*.4)
	cartridge.visible = false
	if owner_actor.get_meta("dead",false) or owner_actor.get_meta("knocked_out",false):
		if not dropped:
			dropped = true
			gun.global_transform = Transform3D(Basis(Vector3.UP,owner_actor.global_rotation.y).scaled(Vector3.ONE*SCALE),owner_actor.global_position+Vector3(.4,.12,.2))
		aim_age = 0
		return
	if owner_actor.get_meta("grappled",false) or owner_actor.get_meta("combat_action","") == "hit":
		aim_age = 0
		return
	var aiming: bool = can_engage()
	if aiming:
		var toward := target.global_position-owner_actor.global_position
		owner_actor.global_rotation.y = rotate_toward(owner_actor.global_rotation.y,atan2(toward.x,toward.z),delta*4)
	var grip := owner_actor.to_global(Vector3(-.16,1.35,.13))
	var aim_target: Vector3 = target.get_node("StealthStance").sight_target() if aiming and target.has_node("StealthStance") else (target.global_position if aiming else grip+owner_actor.global_basis.z)
	var forward: Vector3 = (aim_target-grip).normalized() if aiming else owner_actor.global_basis.z
	var side := forward.cross(Vector3.UP).normalized()
	if side.length_squared() < .1: side = owner_actor.global_basis.x
	var basis := Basis(forward,side.cross(forward).normalized(),side)
	gun.global_transform = Transform3D(basis.scaled(Vector3.ONE*SCALE),grip-forward*recoil-basis*(Vector3(-.09,-.045,0)*SCALE))
	if owner_actor.has_method("solve_hand_contact"):
		owner_actor.solve_hand_contact("r",gun.to_global(Vector3(-.09,-.045,0)))
		owner_actor.solve_hand_contact("l",gun.to_global(Vector3(.20,-.032,0)))
		owner_actor.set_grip("r",.35)
		owner_actor.set_grip("l",.35)
	if cooldown > 0 and owner_actor.has_method("solve_hand_contact"):
		var phase: float = clampf(1.0-cooldown/RELOAD,0,1)
		var loading: Dictionary = preload("res://player/enfield_loading_sequence.gd").state(phase)
		var reload_forward: Vector3 = (owner_actor.global_basis.z*.32+Vector3.UP*.947).normalized()
		var reload_side := reload_forward.cross(Vector3.UP).normalized()
		var reload_basis := Basis(reload_forward,reload_side.cross(reload_forward).normalized(),reload_side)
		var loading_grip := owner_actor.to_global(Vector3(-.12,.86,.08))
		var pose := Transform3D(reload_basis.scaled(Vector3.ONE*SCALE),loading_grip-reload_basis*(Vector3(-.09,-.045,0)*SCALE))
		var loading_blend: float = preload("res://player/enfield_loading_sequence.gd").phase_ease(phase,0,.12)*(1-preload("res://player/enfield_loading_sequence.gd").phase_ease(phase,.82,1))
		gun.global_transform = gun.global_transform.interpolate_with(pose,loading_blend)
		owner_actor.solve_hand_contact("l",gun.to_global(Vector3(.20,-.032,0).lerp(Vector3(.42,-.032,0),loading_blend)))
		owner_actor.solve_hand_contact("r",gun.to_global(Vector3(-.09,-.045,0).lerp(loading.contact,loading_blend)))
		owner_actor.set_grip("r",loading.curl)
		cartridge.update_loading(1,false,phase,gun)
	if not aiming or cartridges <= 0 or cooldown > 0.0:
		aim_age = 0.0
		return
	var excluded: Array[RID] = [owner_actor.body_collider.get_rid(),owner_actor.get_node("Vitality").hit_body.get_rid()]
	var muzzle := gun.to_global(Vector3(1.04,.057,0))
	var space := get_world_3d().direct_space_state
	if not Trace.sight(space,get_tree(),grip,muzzle,excluded).is_empty():
		aim_age = 0.0
		return
	var sight := Trace.sight(space,get_tree(),muzzle,aim_target,excluded)
	if sight.is_empty() or sight.collider != target:
		aim_age = 0.0
		return
	aim_age += delta
	if aim_age >= .65:
		cartridges -= 1
		shots += 1
		recoil = .055
		cooldown = RELOAD
		aim_age = 0.0
		sound.play()
		Trace.shoot(space,get_tree(),muzzle,aim_target+forward*.5,18,excluded,owner_actor)

func can_engage() -> bool:
	if not hostile or moving or not is_instance_valid(target): return false
	var stance := target.get_node_or_null("StealthStance")
	var limit: float = stance.visible_range(owner_actor.global_position+Vector3.UP*1.4,36.0) if stance != null else 36.0
	return owner_actor.global_position.distance_to(target.global_position) <= limit
