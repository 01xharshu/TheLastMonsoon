extends Node
## Ambient actions never own save state, teleport the actor or change collision.
@export var look_after := 45.0
@export var scratch_after := 58.0
@export var clothes_after := 70.0
@export var stretch_after := 95.0
@export var sit_after := 120.0
@export var sit_seconds := 3.6
@export var rise_seconds := 3.2
@export var ui_fade_seconds := 1.25
var idle_ui: Node
const Permissions = preload("res://systems/action_permissions.gd")
const BODY_ACTIONS := ["attack","aim","interact","secondary_interact","jump","combat_dodge","toggle_prone","take_cover","stow_weapon","next_weapon"]
var permissions: Node
var lease := -1
var seat_origin := Vector3.ZERO
var foot_start: Dictionary = {}
var entry_pose: Dictionary = {}
var stand_hip_height := .98
var facing := Basis.IDENTITY
var elapsed := 0.0
var action := ""
var clock := 0.0
var seat := 0.0
var rising := false
var recovery_time := 0.0
var support_clock := 0.0
var observer_clock := 2.0
var observers: Array[Node] = []
var floor_world := Vector3.ZERO
@onready var actor: CharacterBody3D = get_parent()

func _ready() -> void:
	process_priority = -5
	var recovery := preload("res://player/idle_pose_recovery.gd").new()
	recovery.name = "IdlePoseRecovery"
	add_child(recovery)
	idle_ui = preload("res://player/idle_ui.gd").new()
	idle_ui.name = "IdleUI"
	add_child(idle_ui)

func _process(delta: float) -> void:
	if seat > 0.0 and hard_interruption(): cancel(true)
	# The visible pose owns completion. A stalled render must not skip an
	# entire weight transfer while physics catches up in several ticks.
	var step := minf(delta,1.0/30.0)
	recovery_time = maxf(0.0,recovery_time-step)
	if rising:
		seat = move_toward(seat,0.0,step/rise_seconds)
		if seat <= 0.0:
			recovery_time = .25
			cancel(true)
	elif action == "sit":
		seat = move_toward(seat,1.0,step/sit_seconds)

func camera_drop() -> float:
	return (stand_hip_height-.16)*preload("res://player/ground_idle_motion.gd").hip_fraction(seat)

static func is_activity(event: InputEvent) -> bool:
	return (event is InputEventMouseMotion and event.relative.length_squared() > 0.0) or (event is InputEventScreenDrag and event.relative.length_squared() > 0.0) or (event is InputEventJoypadMotion and absf(event.axis_value) > .2) or event.is_pressed()

func _input(event: InputEvent) -> void:
	if is_activity(event):
		cancel()
	if seat > 0.0 and event.is_pressed():
		# Combat permissions already block mouse attacks; let restored UI receive clicks.
		if event is InputEventMouseButton: return
		for input_action in BODY_ACTIONS:
			if InputMap.has_action(input_action) and event.is_action_pressed(input_action):
				get_viewport().set_input_as_handled()
				return
		if event is InputEventKey:
			var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if key in [KEY_H,KEY_Q,KEY_G,KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6]: get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	_release_lease()

func _release_lease() -> void:
	if lease >= 0 and is_instance_valid(permissions): permissions.release(lease)
	lease = -1

func hard_interruption() -> bool:
	if actor.health <= 0.0 or actor.is_swimming or not actor.is_on_floor(): return true
	if actor.global_position.distance_squared_to(seat_origin) > .01: return true
	if actor.has_meta("mounted_vehicle") and actor.get_meta("mounted_vehicle") != null: return true
	for flag in ["opening_active","story_cinematic","climbing","paired_combat","door_latch_active"]:
		if actor.get_meta(flag,false): return true
	for flag in ["rest_action","river_action","detention_action"]:
		if actor.get_meta(flag,"") != "": return true
	var visual: Node = actor.get_node("VisualRoot/CharacterVisual")
	return visual.hit_phase >= 0.0

func cancel(immediate := false) -> void:
	if is_instance_valid(idle_ui): idle_ui.restore()
	elapsed = 0.0
	if seat > 0.0 and not immediate:
		rising = true
	else:
		_release_lease()
		action = ""
		clock = 0.0
		seat = 0.0
		rising = false

func eligible() -> bool:
	if preload("res://systems/world_startup.gd").current != null: return false
	if actor.health <= 0.0: return false
	for observer in observers:
		if is_instance_valid(observer) and observer.has_method("has_pending_police_case") and observer.has_pending_police_case(actor): return false
	if not actor.is_physics_processing() or not actor.is_on_floor() or actor.is_swimming or actor.velocity.length() > .08: return false
	if actor.has_meta("mounted_vehicle") and actor.get_meta("mounted_vehicle") != null: return false
	for flag in ["opening_active","story_cinematic","tutorial_reading","climbing","paired_combat","door_latch_active","interaction_reach","document_busy","map_open","scroll_open","weapon_wheel_open","telescope_open","provision_shop_open","rifle_lesson"]:
		if actor.get_meta(flag,false): return false
	for flag in ["rest_action","river_action","detention_action"]:
		if actor.get_meta(flag,"") != "": return false
	if not preload("res://systems/action_permissions.gd").allowed(actor,&"move"): return false
	if actor.inventory_ui.is_open() or actor.get_node("StealthStance").is_low(): return false
	var visual := actor.get_node("VisualRoot/CharacterVisual")
	if visual.equipment == null or not visual.equipment.stowed or visual.hit_phase >= 0.0: return false
	var combat := actor.get_node("CombatInput")
	if combat.blocking or combat.kick_time >= 0.0 or combat.punch_time >= 0.0 or combat.dodge_time >= 0.0: return false
	return true

func tick(delta: float) -> bool:
	if permissions == null: permissions = Permissions.install(actor)
	# Cache world-scoped crime owners; avoid scene searches in the frame loop.
	observer_clock += delta
	if observer_clock >= 2.0:
		observer_clock = 0.0
		observers.assign(get_tree().get_nodes_in_group("police_crime_observers"))
	# Held keyboard/controller/touch actions count even without new events.
	for input_action in ["move_forward","move_backward","move_left","move_right","jump","sprint","aim","attack","interact","secondary_interact","look_left","look_right","look_up","look_down"]:
		if InputMap.has_action(input_action) and Input.is_action_pressed(input_action): cancel()
	if seat > 0.0 and hard_interruption():
		cancel(true)
		return false
	if rising:
		return seat > 0.0
	if not eligible():
		cancel(seat <= 0.0)
		return seat > 0.0
	elapsed += delta
	if action == "sit":
		support_clock += delta
		if support_clock >= .5:
			support_clock = 0.0
			if not safe_ground():
				cancel(true)
				return false
		return true
	if action != "":
		clock += delta
		if clock >= 5.0:
			action = ""
			clock = 0.0
		return false
	if elapsed >= sit_after:
		if safe_ground():
			var domains: Array[StringName] = [&"attack",&"board",&"stance",&"equip",&"interact"]
			lease = permissions.acquire(self,domains)
			if lease < 0:
				elapsed = stretch_after+6.0
				return false
			prepare_seat()
			action = "sit"
		else: elapsed = stretch_after + 6.0 # retry after a short quiet interval
	elif elapsed >= stretch_after and elapsed-delta < stretch_after: action = "stretch"
	elif elapsed >= clothes_after and elapsed-delta < clothes_after: action = "clothes"
	elif elapsed >= scratch_after and elapsed-delta < scratch_after: action = "scratch"
	elif elapsed >= look_after and elapsed-delta < look_after: action = "look"
	return false

func safe_ground() -> bool:
	var space := actor.get_world_3d().direct_space_state
	var base := actor.global_position-Vector3.UP*.9
	var facing: Basis = actor.get_node("VisualRoot").global_basis.orthonormalized()
	for offset in [Vector3.ZERO,Vector3(.48,0,0),Vector3(-.48,0,0),Vector3(0,0,.48),Vector3(0,0,-.48),facing*Vector3(.28,0,.78),facing*Vector3(-.28,0,.78)]:
		var ray := PhysicsRayQueryParameters3D.create(base+offset+Vector3.UP*.3,base+offset-Vector3.UP*.25,actor.collision_mask,[actor.get_rid()])
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y < .96 or absf(hit.position.y-base.y) > .10: return false
		if offset == Vector3.ZERO: floor_world = hit.position
	var shape := SphereShape3D.new()
	shape.radius = .55
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = floor_world+Vector3.UP*.60
	query.exclude = [actor.get_rid()]
	query.collision_mask = actor.collision_mask
	return space.intersect_shape(query,1).is_empty()

func prepare_seat() -> void:
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	var rig: Skeleton3D = visual.skeleton
	seat_origin = actor.global_position
	facing = actor.get_node("VisualRoot").global_basis.orthonormalized()
	entry_pose.clear()
	for bone in ["upperarm_l","upperarm_r","lowerarm_l","lowerarm_r","hand_l","hand_r","thigh_l","thigh_r","calf_l","calf_r","foot_l","foot_r"]:
		entry_pose[bone] = rig.get_bone_pose_rotation(visual.bones[bone])
	stand_hip_height = rig.to_global(rig.get_bone_global_pose(visual.bones["pelvis"]).origin).y-floor_world.y
	for side in ["l","r"]:
		var index: int = visual.bones["foot_"+side]
		var rest: Transform3D = rig.get_bone_global_rest(index)
		var sole := rig.to_global(rig.get_bone_global_pose(index)*(rest.basis.inverse()*Vector3(0,-.085,.06)))
		sole.y = floor_world.y+.015
		foot_start[side] = sole
