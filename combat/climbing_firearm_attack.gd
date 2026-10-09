extends Node3D
## Enfield-equipped pursuer: finite cartridges, aim delay, muzzle clearance and reload.
const Trace = preload("res://combat/ballistic_trace.gd")
const SCALE = preload("res://player/arjun_equipment.gd").ENFIELD_SCALE
const Loading = preload("res://player/enfield_loading_sequence.gd")
const RELOAD = Loading.RELOAD_SECONDS
var target: CharacterBody3D
var hostile := false
var cartridges := 4
var cooldown := 0.0
var aim_age := 0.0
var shots := 0
var recoil := 0.0
var gun: Node3D
var sound: AudioStreamPlayer3D
var cartridge: Node3D
var loading_left := Vector3(.20,-.032,0)
@onready var owner_actor: Node3D = get_parent()

func _ready() -> void:
	process_priority = 60
	gun = preload("res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb").instantiate()
	gun.name = "EnfieldHeld"
	add_child(gun)
	cartridge = preload("res://player/enfield_cartridge_visual.gd").new()
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
	if owner_actor.get_meta("dead",false) or owner_actor.get_meta("knocked_out",false) or owner_actor.get_meta("grappled",false) or owner_actor.get_meta("combat_action","") == "hit":
		aim_age = 0.0
		cartridge.hide()
		return
	var aiming: bool = can_engage()
	if aiming:
		var toward := target.global_position-owner_actor.global_position
		owner_actor.global_rotation.y = atan2(toward.x,toward.z)
	var grip := owner_actor.to_global(Vector3(-.16,1.35,.13))
	var forward: Vector3 = (target.global_position-grip).normalized() if aiming else owner_actor.global_basis.z
	var loading_progress := 1.0-cooldown/RELOAD
	var loading_pose: Dictionary = Loading.state(loading_progress)
	loading_left = Vector3(.20,-.032,0)
	if cooldown > 0.0:
		var lift := Loading.phase_ease(loading_progress,0.0,.1)*(1.0-Loading.phase_ease(loading_progress,.8,1.0))
		grip = grip.lerp(owner_actor.to_global(Vector3(-.14,.85,.24)),lift)
		forward = forward.lerp((Vector3.UP+owner_actor.global_basis.x*.65).normalized(),lift).normalized()
		var loading_contact: Vector3 = loading_pose.contact.lerp(loading_left,Loading.phase_ease(loading_progress,.65,.8))
		loading_left = loading_left.lerp(loading_contact,lift)
	var side := forward.cross(Vector3.UP).normalized()
	if side.length_squared() < .1: side = owner_actor.global_basis.x
	var basis := Basis(forward,side.cross(forward).normalized(),side)
	gun.global_transform = Transform3D(basis.scaled(Vector3.ONE*SCALE),grip-forward*recoil-basis*(Vector3(-.09,-.045,0)*SCALE))
	if owner_actor.has_method("solve_hand_contact"):
		owner_actor.solve_hand_contact("r",gun.to_global(Vector3(-.09,-.045,0)))
		owner_actor.solve_hand_contact("l",gun.to_global(loading_left))
		owner_actor.set_grip("r",.35)
		owner_actor.set_grip("l",float(loading_pose.curl) if cooldown > 0.0 else .35)
	cartridge.update_loading(1,cooldown<=0.0,loading_progress,gun)
	if not aiming or cartridges <= 0 or cooldown > 0.0:
		aim_age = 0.0
		return
	var excluded: Array[RID] = [owner_actor.body_collider.get_rid()]
	var muzzle := gun.to_global(Vector3(1.04,.057,0))
	var space := get_world_3d().direct_space_state
	if not Trace.sight(space,get_tree(),grip,muzzle,excluded).is_empty():
		aim_age = 0.0
		return
	var sight := Trace.sight(space,get_tree(),muzzle,target.global_position,excluded)
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
		Trace.shoot(space,get_tree(),muzzle,target.global_position+forward*.5,18,excluded,owner_actor)

func can_engage() -> bool:
	if not hostile or not is_instance_valid(target): return false
	if owner_actor.global_position.distance_to(target.global_position) > 45.0: return false
	return bool(target.get_meta("climbing",false)) or not target.is_on_floor() or target.global_position.y-owner_actor.global_position.y>2.5
