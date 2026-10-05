extends Node3D
## Rest-relative, model-space procedural animation for the MPFB game rig.
const Equipment = preload("res://player/arjun_equipment.gd")
const WeaponWheel = preload("res://player/weapon_wheel.gd")
const MotionTree = preload("res://player/arjun_motion_tree.gd")
var equipment: Node3D
var talwar_equipped: bool:
	get:
		return equipment != null and not equipment.stowed and equipment.selected == Equipment.Selection.TALWAR
var skeleton: Skeleton3D
var model: Node3D
var weapon: Node3D
var phase := 0.0
var breath := 0.0
var horse_riding_fold := 0.0
var motion := 0.0
var swim_blend := 0.0
var slash_phase := -1.0
var slash_target_world := Vector3.ZERO
var punch_phase := -1.0
var kick_phase := -1.0
var knife_phase := -1.0
var hit_phase := -1.0
var bones: Dictionary = {}
var base_rotations: Dictionary = {}
var axes: Dictionary = {}
var climb_ik: Dictionary = {}
var climb_targets: Dictionary = {}
var climb_foot_targets: Dictionary = {}
var detention_contacts = preload("res://player/detention_contacts.gd").new()
var motion_tree: AnimationTree
@onready var actor: CharacterBody3D = get_parent().get_parent()

func _ready() -> void:
	model = preload("res://characters/arjun/arjun.glb").instantiate()
	add_child(model)
	model.position.y = -0.9
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty():
		push_error("Arjun model has no skeleton")
		return
	# The exported atlas stays authoritative; a tiny procedural pore/skin response
	# adds surface detail at close range without another high-resolution texture.
	for mesh_node in model.find_children("*","MeshInstance3D",true,false):
		var surface: MeshInstance3D = mesh_node
		for surface_index in surface.mesh.get_surface_count():
			var original: Material=surface.mesh.surface_get_material(surface_index)
			if original is BaseMaterial3D and original.resource_name=="Arjun warm medium-brown skin":
				var skin := ShaderMaterial.new()
				skin.shader=preload("res://characters/arjun/skin_detail.gdshader")
				skin.set_shader_parameter("base_atlas",original.albedo_texture)
				skin.set_shader_parameter("source_skin",preload("res://characters/arjun/skin_source_makehuman.png"))
				surface.set_surface_override_material(surface_index,skin)
	skeleton = rigs[0]
	var clothing := preload("res://player/arjun_clothing.gd").new()
	clothing.name = "Clothing"
	add_child(clothing)
	clothing.setup(model, skeleton)
	for i in skeleton.get_bone_count():
		var bone := skeleton.get_bone_name(i)
		bones[bone] = i
		base_rotations[bone] = skeleton.get_bone_pose_rotation(i)
		axes[bone] = skeleton.get_bone_global_rest(i).basis.orthonormalized().inverse()
	motion_tree = MotionTree.new()
	motion_tree.name = "ArjunMotionTree"
	add_child(motion_tree)
	if not motion_tree.configure(model):
		motion_tree.queue_free()
		motion_tree = null
	for side in ["l","r"]:
		var target := Marker3D.new()
		target.name = "ClimbPalm_"+side
		model.add_child(target)
		var solver := SkeletonIK3D.new()
		solver.name = "PalmIK_"+side
		solver.root_bone = "upperarm_"+side
		solver.tip_bone = "hand_"+side
		skeleton.add_child(solver)
		solver.target_node = solver.get_path_to(target)
		solver.influence = 0.0
		solver.start()
		climb_ik[side]=solver
		climb_targets[side]=target
	equipment = Equipment.new()
	equipment.name = "Equipment"
	add_child(equipment)
	equipment.inventory = actor.get_node("InventoryComponent")
	equipment.setup(skeleton)
	weapon = equipment.talwar_hand
	var wheel := WeaponWheel.new()
	wheel.actor = actor
	wheel.equipment = equipment
	actor.get_node("UI").add_child.call_deferred(wheel)

func _unhandled_input(event: InputEvent) -> void:
	if actor.get_meta("detention_action","")!="": return
	if equipment == null or not actor.is_physics_processing(): return
	if actor.inventory_ui.is_open() or actor.get_meta("map_open", false) or actor.get_meta("weapon_wheel_open", false) or (actor.has_meta("mounted_vehicle") and actor.get_meta("mounted_vehicle") != null) or actor.get_meta("climbing",false): return
	if event.is_action_pressed("stow_weapon"):
		equipment.toggle_stowed()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("next_weapon"):
		for offset in range(1,7):
			var choice := (int(equipment.selected) + offset) % 6
			if equipment.owns(choice):
				equipment.select_weapon(choice)
				break
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if SaveManager.active_input_device == "controller": return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match key:
		KEY_G:
			equipment.toggle_stowed()
		KEY_1:
			equipment.select_weapon(Equipment.Selection.TALWAR)
		KEY_2:
			equipment.select_weapon(Equipment.Selection.ENFIELD)
		KEY_3:
			equipment.select_weapon(Equipment.Selection.BOW)
		KEY_4:
			equipment.select_weapon(Equipment.Selection.PISTOL)
		KEY_5:
			equipment.select_weapon(Equipment.Selection.KNIFE)
		KEY_6:
			equipment.select_weapon(Equipment.Selection.DOUBLE_GUN)
		_:
			return
	get_viewport().set_input_as_handled()

func pose(bone: String, angles: Vector3, weight: float) -> void:
	if not bones.has(bone): return
	var local_axes: Basis = axes[bone]
	var offset := Quaternion(local_axes * Vector3.RIGHT, angles.x) * Quaternion(local_axes * Vector3.UP, angles.y) * Quaternion(local_axes * Vector3.BACK, angles.z)
	var target: Quaternion = base_rotations[bone] * offset
	var index: int = bones[bone]
	skeleton.set_bone_pose_rotation(index, skeleton.get_bone_pose_rotation(index).slerp(target, weight))

func _process(delta: float) -> void:
	if skeleton == null: return
	if hit_phase>=0:
		hit_phase+=delta/.45
		if hit_phase>=1:hit_phase=-1
	if actor.get_meta("detention_action","")=="": detention_contacts.update(self)
	var mounted: bool = actor.has_meta("mounted_vehicle") and actor.get_meta("mounted_vehicle") != null
	var special_pose: bool = actor.get_meta("river_action", "") != "" or mounted or actor.get_meta("stealth_stance", "") != ""
	if motion_tree != null:
		motion_tree.active = not special_pose
		var combat := actor.get_node("CombatInput")
		var melee_phase := kick_phase if kick_phase >= 0 else punch_phase
		var action: int = (3 if combat.air_kick else 2) if kick_phase >= 0 else (1 if combat.left_punch else 0)
		if slash_phase >= 0:action=5;melee_phase=slash_phase
		elif knife_phase >= 0:action=6;melee_phase=knife_phase
		elif actor.has_meta("combat_dodge_phase"):action=9;melee_phase=actor.get_meta("combat_dodge_phase")
		elif hit_phase>=0:action=7;melee_phase=hit_phase
		elif combat.blocking:action=8;melee_phase=.5
		motion_tree.set_melee(action,melee_phase)
		if not actor.get_meta("climbing", false): motion_tree.release_climb(delta)
	if actor.get_meta("detention_action", "") != "":
		_pose_detention(delta)
		return
	if actor.get_meta("rest_action", "") != "":
		if motion_tree != null:
			var rest_progress: float = clampf(actor.get_meta("rest_progress", 0.0), 0.0, 1.0)
			var seated: float = smoothstep(0.0, 0.38, rest_progress) * (1.0 - smoothstep(0.38, 0.9, rest_progress))
			motion_tree.update_rest(delta, seated, rest_progress, actor.get_meta("rest_waking", false))
		_pose_rest(delta)
		return
	if motion_tree != null and motion_tree.rest_blend > 0.0:
		motion_tree.rest_blend = 0.0
	if actor.get_meta("river_action", "") != "":
		_pose_river_action(delta)
		return
	if actor.get_meta("climbing",false):
		_pose_climb(delta)
		return
	if mounted:
		var mount: Node = (actor.get_meta("mounted_vehicle") if actor.has_meta("mounted_vehicle") else null)
		if is_instance_valid(mount) and mount.is_in_group("horses"):
			for solver in climb_ik.values():
				solver.influence = 0.0
				if solver.is_running(): solver.stop()
			if actor.get_meta("horse_transition", "") != "":
				_pose_horse_transition(delta)
			# The horse applies the riding pose after its final physics/back update.
		elif actor.get_meta("cart_role", "") != "" and mount.transition != "":
			_pose_cart_transition(delta, mount)
		elif actor.get_meta("cart_role", "") == "driver":
			_pose_cart_driver(delta)
		else:
			_pose_seated(delta)
		return
	for solver in climb_ik.values(): solver.influence = 0.0
	equipment.set_swimming(actor.is_swimming)
	var blend := 1.0 - exp(-12.0 * delta)
	var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
	motion = lerpf(motion, clampf(speed / actor.walk_speed, 0.0, 1.0), blend)
	swim_blend = lerpf(swim_blend, 1.0 if actor.is_swimming else 0.0, blend)
	var sprint := clampf((speed - actor.walk_speed) / maxf(actor.sprint_speed - actor.walk_speed, 0.1), 0.0, 1.0)
	phase = fmod(phase + delta * lerpf(7.5, 11.5, sprint) * lerpf(0.3, 1.0, motion), TAU)
	breath += delta * 1.8
	var ground := 1.0 if actor.is_on_floor() else 0.0
	var stride := motion * ground * (1.0 - swim_blend)
	var stair := clampf(actor.step_lift / maxf(actor.max_walk_step_height, 0.01), 0.0, 1.0) * stride
	var swing := sin(phase) * lerpf(0.42, 0.8, sprint) * stride
	var swimming := swim_blend
	var armed := talwar_equipped and swimming < 0.5
	var tree_driven: bool = motion_tree != null and not special_pose
	if tree_driven:
		motion_tree.update_motion(delta, speed / maxf(actor.walk_speed, 0.01), speed / maxf(actor.swim_speed, 0.01), actor.is_swimming, actor.is_on_floor(), actor.velocity.y)
	# Pivot near the chest when leaning into the water, keeping the face above it.
	# The imported swim clips already pitch the skeleton forward. Keep the
	# previous model tilt only for the procedural fallback path.
	model.rotation.x = lerpf(model.rotation.x, 0.0 if tree_driven else swimming * 1.05, blend)
	model.rotation.y = lerpf(model.rotation.y, 0.0, blend)
	model.rotation.z = lerpf(model.rotation.z, 0.0, blend)
	model.position = Vector3(0, -0.9 + swimming * 0.65 + absf(sin(phase)) * stride * 0.045 - (motion_tree.foot_contact_offset if tree_driven else 0.0), 0)
	if tree_driven and swimming > 0.01:
		# Lift the gaze out of the water after the imported body pitch.
		pose("head", Vector3(-0.55, 0, 0), swimming)
	if not tree_driven:
		pose("pelvis", Vector3(0, swing * 0.12, sin(phase) * stride * 0.035), blend)
		pose("spine_01", Vector3(sprint * stride * 0.12, -swing * 0.18, 0), blend)
		pose("spine_02", Vector3(sin(breath) * 0.015, -swing * 0.12, 0), blend)
		pose("head", Vector3(-swimming * 0.55 - sprint * stride * 0.06, 0, 0), blend)
		for side in ["l", "r"]:
			var sign_side := 1.0 if side == "l" else -1.0
			var cycle := phase + (0.0 if side == "l" else PI)
			var leg := swing * sign_side
			var air := (1.0 - ground) * (1.0 - swimming)
			var lift := maxf(0.0, sin(cycle)) * stair
			pose("thigh_" + side, Vector3(leg - air * 0.22 + swimming * sin(cycle) * 0.24 + lift * 0.38, 0, 0), blend)
			pose("calf_" + side, Vector3(maxf(0, sin(cycle)) * stride * lerpf(0.65, 1.25, sprint) + air * 0.4 + swimming * (0.2 + maxf(0, sin(cycle)) * 0.35) + lift * 0.45, 0, 0), blend)
			pose("foot_" + side, Vector3(-leg * 0.25 + swimming * 0.25 - lift * 0.2, 0, 0), blend)
			var arm := Vector3(-leg * 0.65, 0, -sign_side * 0.45)
			var elbow := -0.15 - sprint * 0.65
			if armed and side == "r":
				arm = Vector3(-0.28 - leg * 0.12, -0.12, 0.32)
				elbow = -0.65
			arm = arm.lerp(Vector3(-0.65 + sin(cycle) * 0.85, 0, sign_side * (0.55 + cos(cycle) * 0.4)), swimming)
			elbow = lerpf(elbow, -0.5 - maxf(0, cos(cycle)) * 0.8, swimming)
			pose("upperarm_" + side, arm, blend)
			pose("lowerarm_" + side, Vector3(elbow, 0, 0), blend)
			for finger in ["index", "middle", "ring", "pinky", "thumb"]:
				for joint in ["01", "02", "03"]:
					# Fingers curl around their local hinge, unlike the model-space limbs.
					var name: String = finger + "_" + joint + "_" + side
					if bones.has(name):
						var curl := 0.85 if armed and side == "r" else 0.12
						var target: Quaternion = base_rotations[name] * Quaternion(Vector3.RIGHT, curl)
						skeleton.set_bone_pose_rotation(bones[name], skeleton.get_bone_pose_rotation(bones[name]).slerp(target, blend))
	if armed and slash_phase >= 0.0:
		if motion_tree == null:
			# Wind up over the right shoulder, then sweep the blade across the rope.
			var sweep := smoothstep(0.18,0.72,slash_phase)
			var release := 1.0 - smoothstep(0.76,1.0,slash_phase)
			pose("spine_02",Vector3(-0.10,lerpf(-0.25,0.38,sweep),0.0),release)
			pose("upperarm_r",Vector3(lerpf(-1.15,0.35,sweep),lerpf(-0.65,0.65,sweep),lerpf(-0.60,0.10,sweep)),release)
			pose("lowerarm_r",Vector3(lerpf(-1.15,-0.40,sweep),0,0),release)
		equipment.apply_sword_strike(slash_phase,slash_target_world)
	if punch_phase >= 0.0 and motion_tree == null:
		var windup := smoothstep(0.0,.22,punch_phase)
		var strike := smoothstep(.25,.43,punch_phase)
		var recover := 1.0-smoothstep(.58,1.0,punch_phase)
		var effort := windup*recover
		pose("pelvis",Vector3(-.08*effort,.16*strike*recover,0),blend)
		pose("spine_01",Vector3(-.10*effort,.18*strike*recover,0),blend)
		pose("spine_02",Vector3(-.16*effort,.28*strike*recover,0),blend)
		pose("upperarm_r",Vector3(lerpf(-.55,-1.35,strike)*effort,0,-.28*effort),blend)
		pose("lowerarm_r",Vector3(lerpf(-1.35,-.18,strike)*effort,0,0),blend)
		pose("upperarm_l",Vector3(-.48*effort,0,.42*effort),blend)
		pose("lowerarm_l",Vector3(-.9*effort,0,0),blend)
	if kick_phase >= 0.0 and motion_tree == null:
		var chamber := smoothstep(0.0,.27,kick_phase)
		var extension := smoothstep(.28,.46,kick_phase)
		var recover := 1.0-smoothstep(.56,1.0,kick_phase)
		var effort := chamber*recover
		pose("pelvis",Vector3(-.12*effort,-.10*effort,-.10*effort),blend)
		pose("spine_01",Vector3(.20*effort,0,.08*effort),blend)
		pose("spine_02",Vector3(.12*effort,0,0),blend)
		pose("thigh_r",Vector3(-1.2*effort,0,0),blend)
		pose("calf_r",Vector3(lerpf(-1.15,.12,extension)*effort,0,0),blend)
		pose("foot_r",Vector3(-.18*effort,0,0),blend)
		pose("thigh_l",Vector3(.14*effort,0,0),blend)
		pose("calf_l",Vector3(.14*effort,0,0),blend)
		pose("upperarm_l",Vector3(-.55*effort,0,.48*effort),blend)
		pose("upperarm_r",Vector3(-.42*effort,0,-.4*effort),blend)
	equipment.reload_progress = -1.0
	if not equipment.stowed:
		var reload_node: Node = null
		var duration := 0.0
		match equipment.selected:
			Equipment.Selection.ENFIELD:
				reload_node = actor.get_node_or_null("RifleCombat")
				duration = preload("res://player/enfield_loading_sequence.gd").RELOAD_SECONDS
			Equipment.Selection.PISTOL:
				reload_node = actor.get_node_or_null("PistolCombat")
				duration = 3.8
			Equipment.Selection.DOUBLE_GUN:
				reload_node = actor.get_node_or_null("DoubleGunCombat")
				duration = 4.4
		if reload_node != null and reload_node.reload_remaining > 0.0:
			equipment.reload_progress = clampf(1.0-reload_node.reload_remaining/duration,0.0,1.0)
	if motion_tree != null:
		var pistol_equipped: bool = not equipment.stowed and equipment.selected == Equipment.Selection.PISTOL
		motion_tree.update_pistol_motion(delta, pistol_equipped, equipment.aiming, equipment.reload_progress, equipment.recoil)
		if pistol_equipped:
			pose("spine_02", Vector3(-0.035 * motion_tree.pistol_aim_blend + 0.045 * motion_tree.pistol_recoil_blend, -0.035 * motion_tree.pistol_aim_blend, 0.0), 0.35)
		var longgun_equipped: bool = not equipment.stowed and equipment.selected in [Equipment.Selection.ENFIELD, Equipment.Selection.DOUBLE_GUN]
		motion_tree.update_longgun_motion(delta, longgun_equipped, equipment.aiming, equipment.reload_progress, equipment.recoil)
		if longgun_equipped:
			pose("spine_02", Vector3(-0.025 * motion_tree.longgun_aim_blend + 0.035 * motion_tree.longgun_recoil_blend - 0.025 * motion_tree.longgun_reload_blend, -0.025 * motion_tree.longgun_aim_blend, 0.0), 0.4)
	equipment.apply_rifle_grip((armed and slash_phase >= 0.0) or knife_phase >= 0.0)
	var interaction: Node = actor.get_node_or_null("InteractionPoseComponent")
	var reaching: bool = actor.get_meta("interaction_reach", false) or (interaction != null and (interaction.amount > 0.0 or interaction.ground_pickup))
	var door_action = actor.get_node_or_null("DoorLatchAction")
	if door_action != null and door_action.phase != "":
		door_action.apply_pose()
		reaching=true
	if equipment.stowed and punch_phase < 0 and kick_phase < 0 and hit_phase < 0 and not actor.has_meta("combat_dodge") and not actor.get_meta("combat_blocking",false) and not actor.get_meta("paired_combat",false) and not reaching and not actor.is_swimming and not special_pose:
		equipment.keep_relaxed_hands_clear()


func _pose_river_action(delta: float) -> void:
	for solver in climb_ik.values(): solver.influence = 0.0
	var weight := 1.0-exp(-10.0*delta)
	var progress: float = actor.get_meta("river_action_progress", 0.0)
	var reach := smoothstep(0.04,0.38,progress) * (1.0-smoothstep(0.72,0.98,progress))
	var drink: bool = actor.get_meta("river_action", "") == "drink"
	model.rotation.x = lerpf(model.rotation.x,0.18,weight)
	model.position = model.position.lerp(Vector3(0,-1.12,0),weight)
	pose("pelvis",Vector3(0,0,0),weight)
	pose("spine_01",Vector3(0.28,0,0),weight)
	pose("spine_02",Vector3(0.16,0,0),weight)
	pose("head",Vector3(-0.10,0,0),weight)
	for side in ["l","r"]:
		pose("thigh_"+side,Vector3(0.86,0,0),weight)
		pose("calf_"+side,Vector3(-1.32,0,0),weight)
		pose("foot_"+side,Vector3(0.34,0,0),weight)
		var hand_raise := 0.55 if drink and side == "r" and progress > 0.42 else 0.0
		pose("upperarm_"+side,Vector3(-1.0+hand_raise*reach,0,(-0.75 if side == "l" else 0.75)),weight)
		pose("lowerarm_"+side,Vector3(-0.92-hand_raise*reach,0,0),weight)

func _pose_rest(delta: float) -> void:
	for solver in climb_ik.values(): solver.influence = 0.0
	if equipment != null: equipment.set_swimming(false)
	var progress: float = clampf(actor.get_meta("rest_progress", 0.0), 0.0, 1.0)
	var lie := smoothstep(0.38, 0.9, progress)
	var weight := 1.0 - exp(-12.0 * delta)
	# Turn the body's width across the cot, keeping both legs at the same
	# height. A roll around Z instead stacks left/right limbs vertically.
	var lie_basis := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
	var target_rotation := Quaternion.IDENTITY.slerp(lie_basis.get_rotation_quaternion(), lie)
	model.quaternion = model.quaternion.slerp(target_rotation, weight)
	model.position = model.position.lerp(Vector3(-0.65 * lie, lerpf(-1.1, -0.1, lie), 0.42 * (1.0 - lie)), weight)
	if motion_tree == null:
		pose("pelvis", Vector3.ZERO, weight)
		pose("spine_01", Vector3(-0.12 * (1.0 - lie), 0, 0), weight)
		pose("spine_02", Vector3(0.04 * lie, 0, 0), weight)
		pose("head", Vector3(0.05 * lie, 0, 0), weight)
		for side in ["l", "r"]:
			var spread := 1.0 if side == "l" else -1.0
			pose("thigh_" + side, Vector3(0.0, 0.0, 0.0), weight * lie)
			pose("calf_" + side, Vector3(0.0, 0, 0), weight * lie)
			pose("foot_" + side, Vector3.ZERO, weight * lie)
			pose("upperarm_" + side, Vector3(-0.35, 0, spread * 0.35), weight * lie)
			pose("lowerarm_" + side, Vector3(-0.25, 0, 0), weight * lie)
	# Keep the hips close to the woven surface while the body turns. The
	# imported sit and idle clips place their pelvis at different rig heights.
	skeleton.force_update_all_bone_transforms()
	var hip_index := skeleton.find_bone("pelvis")
	var hip_y := skeleton.to_global(skeleton.get_bone_global_pose(hip_index).origin).y
	var desired_hip_y := actor.global_position.y - 0.17 + 0.07 * lie
	model.position.y += clampf(desired_hip_y - hip_y, -0.25, 0.25)
	for side in ["l", "r"]:
		if progress < 0.98:
			_rest_seated_foot_contact(side, smoothstep(0.12, 0.32, progress) * (1.0 - smoothstep(0.88, 0.98, progress)), smoothstep(0.44, 0.62, progress))

func _rest_seated_foot_contact(side: String, influence: float, cot_lift: float) -> void:
	if influence <= 0.0: return
	skeleton.force_update_all_bone_transforms()
	var foot_index := skeleton.find_bone("foot_" + side)
	var ankle := skeleton.to_global(skeleton.get_bone_global_pose(foot_index).origin)
	var query := PhysicsRayQueryParameters3D.create(ankle + Vector3.UP * 0.5, ankle - Vector3.UP * 1.0)
	query.exclude = [actor.get_rid()]
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return
	var sign_side := 1.0 if side == "l" else -1.0
	var cot_target := actor.to_global(Vector3(-0.55, -0.18, sign_side * 0.18))
	var target: Vector3 = (hit.position + Vector3.UP * 0.02).lerp(cot_target, cot_lift)
	_horse_foot_contact(side, target, influence)

func _pose_seated(delta: float) -> void:
	var boat: Node = actor.get_meta("mounted_vehicle")
	for solver in climb_ik.values(): solver.influence = 0.0
	var weight := 1.0-exp(-9.0*delta)
	model.rotation.x = lerpf(model.rotation.x,0.0,weight)
	model.position = model.position.lerp(Vector3(0,-.9,0),weight)
	breath += delta*1.8
	for side in ["l","r"]:
		var spread := 1.0 if side=="l" else -1.0
		pose("thigh_"+side,Vector3(-1.22,spread*.12,spread*.08),weight)
		pose("calf_"+side,Vector3(1.48,0,0),weight)
		pose("foot_"+side,Vector3(-.27,0,0),weight)
		pose("upperarm_"+side,Vector3(.28,0,spread*.22),weight)
		pose("lowerarm_"+side,Vector3(-.72,0,0),weight)
	pose("pelvis",Vector3(0,0,0),weight)
	var rowing_lean: float = sin(boat.row_phase)*boat.row_effort*.10 if is_instance_valid(boat) and boat.has_method("paddle_grip_world") else 0.0
	pose("spine_01",Vector3(-.10+rowing_lean,0,0),weight)
	pose("spine_02",Vector3(sin(breath)*.015,0,0),weight)
	pose("head",Vector3(.04,0,0),weight)
	if is_instance_valid(boat) and actor.get_meta("cart_role", "") == "passenger":
		pose("spine_01", Vector3(-.10 + boat.rider_acceleration*.02, 0, -boat.rider_turn*.04), weight)
		pose("spine_02", Vector3(sin(breath)*.01, 0, boat.rider_turn*.025), weight)
		if boat.has_method("foot_support_world"):
			boat._sync_rider()
			for side in ["l", "r"]:
				_horse_foot_contact(side, boat.foot_support_world(side), 1.0)
		if boat.has_method("passenger_hand_world"):
			for pass_index in 4:
				for side in ["l", "r"]:
					var target: Vector3 = skeleton.to_local(boat.passenger_hand_world(side))
					var hand: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone("hand_" + side))
					equipment._solve_arm(side, target - hand.basis * equipment.palm_offsets[side])

	if is_instance_valid(boat) and boat.has_method("paddle_grip_world") and boat.paddle_blend > .01:
		skeleton.force_update_all_bone_transforms()
		var rod_axis: Vector3 = (skeleton.global_basis.inverse()*boat.paddle_rod_world_axis()).normalized()
		var palm_normal := (Vector3.DOWN-rod_axis*Vector3.DOWN.dot(rod_axis)).normalized()
		var finger_axis := palm_normal.cross(rod_axis).normalized()
		var palm_basis := Basis(rod_axis,finger_axis,palm_normal)
		for pass_index in 4:
			for side in ["l","r"]:
				var grip: Vector3 = skeleton.to_local(boat.paddle_grip_world(side))
				var hand_basis: Basis = palm_basis*(equipment.palm_axes[side] as Basis).inverse()
				var target: Vector3 = grip-hand_basis*equipment.palm_offsets[side]
				equipment._solve_arm(side,target)
				var hand_index: int = skeleton.find_bone("hand_"+side)
				var parent_index: int = skeleton.get_bone_parent(hand_index)
				var local_basis := skeleton.get_bone_global_pose(parent_index).basis.inverse()*hand_basis
				skeleton.set_bone_pose_rotation(hand_index,local_basis.orthonormalized().get_rotation_quaternion())
				skeleton.force_update_all_bone_transforms()
		for side in ["l","r"]: equipment._grasp(side)

func _pose_cart_transition(delta: float, vehicle: Node) -> void:
	for solver in climb_ik.values():
		solver.influence = 0.0
		if solver.is_running(): solver.stop()
	var u: float = vehicle.transition_progress if vehicle.transition == "boarding" else 1.0 - vehicle.transition_progress
	var cabin_transfer: bool = vehicle.role == "passenger" and vehicle.cart.has_method("show_coachman_blockout")
	var sit: float = smoothstep(.72 if cabin_transfer else .55, 1.0, u)
	var step: float = sin(PI * clampf(u / .55, 0.0, 1.0)) * (1.0 - sit)
	model.rotation.x = 0.0
	model.position = Vector3(0, -.9, 0)
	pose("pelvis", Vector3.ZERO, 1.0)
	pose("spine_01", Vector3(-.16 * step - .10 * sit, 0, 0), 1.0)
	pose("spine_02", Vector3(-.06 * step, 0, 0), 1.0)
	pose("head", Vector3(.08 * step, 0, 0), 1.0)
	for side in ["l", "r"]:
		var leading: bool = (side == "l") == (vehicle.transition_side < 0.0)
		var lift: float = step * (1.0 if leading else .3)
		var spread := 1.0 if side == "l" else -1.0
		pose("thigh_" + side, Vector3(-.90 * lift - 1.22 * sit, spread * .08 * sit, 0), 1.0)
		pose("calf_" + side, Vector3(1.35 * lift + 1.48 * sit, 0, 0), 1.0)
		pose("foot_" + side, Vector3(-.20 * lift - .27 * sit, 0, 0), 1.0)
		pose("upperarm_" + side, Vector3(-.45 * step, 0, spread * .12), 1.0)
		pose("lowerarm_" + side, Vector3(-.55 * step - .35 * sit, 0, 0), 1.0)
	vehicle._sync_rider()
	var contact: float = smoothstep(.20, .36 if cabin_transfer else .45, u) * (1.0 - smoothstep(.50 if cabin_transfer else .65, .64 if cabin_transfer else .90, u))
	var leading_side := "l" if vehicle.transition_side < 0.0 else "r"
	if cabin_transfer:
		for side in ["l", "r"]:
			var leading: bool = side == leading_side
			var foot_contact := smoothstep(.20 if leading else .48, .36 if leading else .66, u)
			_horse_foot_contact(side, vehicle.cabin_transfer_foot_world(side, u), foot_contact)
	else:
		_horse_foot_contact(leading_side, vehicle.transition_step_world(), contact)
	if cabin_transfer:
		var hip: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("pelvis")).origin)
		for side in ["l", "r"]:
			var relaxed: Vector3 = hip + actor.visual_root.global_basis * Vector3(-.28 if side == "l" else .28, .05, .08)
			var target: Vector3 = skeleton.to_local(relaxed.lerp(vehicle.passenger_hand_world(side), sit))
			for iteration in 4:
				var hand: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone("hand_" + side))
				equipment._solve_arm(side, target - hand.basis * equipment.palm_offsets[side])
	if contact > 0.0:
		if vehicle.role == "passenger" and vehicle.cart.has_method("show_coachman_blockout"):
			preload("res://player/arjun_cart_grip.gd").apply(self, vehicle, leading_side, contact)
		else:
			var target: Vector3 = skeleton.to_local(vehicle.transition_hand_world())
			for iteration in 4:
				var hand: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone("hand_" + leading_side))
				var palm: Vector3 = hand * equipment.palm_offsets[leading_side]
				equipment._solve_arm(leading_side, palm.lerp(target, contact) - hand.basis * equipment.palm_offsets[leading_side])

func _pose_cart_driver(delta: float) -> void:
	_pose_seated(delta)
	var weight := 1.0-exp(-10.0*delta)
	var vehicle: Node = actor.get_meta("mounted_vehicle")
	var steer: float = vehicle.rider_turn
	var acceleration: float = clampf(vehicle.rider_acceleration / 2.0, -1.0, 1.0)
	pose("spine_01", Vector3(-.06 + acceleration * .05, steer*.06, -steer*.04), weight)
	pose("spine_02", Vector3(-acceleration*.025, 0, steer*.025), weight)
	pose("head", Vector3(.04-acceleration*.025, -steer*.025, 0), weight)
	for side in ["l", "r"]:
		var spread := 1.0 if side == "l" else -1.0
		pose("upperarm_"+side, Vector3(-.50, spread*.10, spread*.25), weight)
		pose("lowerarm_"+side, Vector3(-.84, 0, 0), weight)
		for finger in ["index", "middle", "ring", "pinky", "thumb"]:
			for joint in ["01", "02", "03"]:
				var name: String = finger+"_"+joint+"_"+side
				if bones.has(name):
					var target: Quaternion = base_rotations[name] * Quaternion(Vector3.RIGHT, .65)
					skeleton.set_bone_pose_rotation(bones[name], skeleton.get_bone_pose_rotation(bones[name]).slerp(target, weight))
	var cart: Node = actor.get_meta("mounted_vehicle")
	if is_instance_valid(cart) and cart.has_method("rein_grip_world"):
		cart._sync_rider()
		preload("res://player/arjun_rein_grip.gd").apply(self,cart.cart.global_basis,{"l":cart.rein_grip_world("l"),"r":cart.rein_grip_world("r")})
	if is_instance_valid(cart) and cart.has_method("foot_support_world"):
		cart._sync_rider()
		for side in ["l", "r"]:
			_horse_foot_contact(side, cart.foot_support_world(side), 1.0)
func _pose_horse_riding(delta: float) -> void:
	var weight := 1.0-exp(-9.0*delta)
	var mount: Node = (actor.get_meta("mounted_vehicle") if actor.has_meta("mounted_vehicle") else null)
	var stride: float = clampf(absf(mount.pace)/mount.GALLOP_SPEED,0.0,1.0)
	var gallop: float = smoothstep(.45, .85, stride)
	var cycle: float = mount.gait
	if mount.rigged_anim != null and mount.rigged_anim.has_animation(mount.rigged_anim.current_animation):
		var clip: Animation = mount.rigged_anim.get_animation(mount.rigged_anim.current_animation)
		if clip != null and clip.length > 0.0:
			cycle = TAU * mount.rigged_anim.current_animation_position / clip.length
	var airborne: bool = not mount._walk_supported()
	var desired_fold: float = lerpf(.65,1.0,clampf(mount.velocity.y/5.7,0.0,1.0)) if airborne else 0.0
	horse_riding_fold = lerpf(horse_riding_fold,desired_fold,1.0-exp(-12.0*delta))
	var jump_fold: float = horse_riding_fold
	var landing: float = mount.rider_landing
	var lean: float = stride*.08 + gallop*.22 + jump_fold*.38 + landing*.16
	var follow: float = sin(cycle)*stride*(.025 + gallop*.035) if not airborne else 0.0
	model.rotation.x = lerpf(model.rotation.x,0.0,weight)
	model.position = model.position.lerp(Vector3(0,-.9,0),weight)
	breath += delta*1.8
	for side in ["l","r"]:
		var s := 1.0 if side=="l" else -1.0
		pose("thigh_"+side,Vector3(-.35,s*.22,s*.55),weight)
		pose("calf_"+side,Vector3(.9+gallop*.10+jump_fold*.12,0,0),weight)
		pose("foot_"+side,Vector3(.12,0,0),weight)
		pose("upperarm_"+side,Vector3(-.30,0,-s*.40),weight)
		pose("lowerarm_"+side,Vector3(-.50,0,0),weight)
	pose("pelvis",Vector3(lean*.12,0,0),weight)
	pose("spine_01",Vector3(.06+lean*.55-follow,0,0),weight)
	pose("spine_02",Vector3(lean*.30-follow*.55+sin(breath)*.008,0,0),weight)
	pose("head",Vector3(.03-lean*.55+follow*.3,0,0),weight)
	# Seat alignment must use this frame's pelvis pose before solving limbs.
	skeleton.force_update_all_bone_transforms()
	mount._sync_rider()
	preload("res://player/arjun_rein_grip.gd").apply(self,mount.global_basis,{"l":mount.riding_rein_world("l"),"r":mount.riding_rein_world("r")})
	for side in ["l", "r"]:
		_horse_foot_contact(side, mount.stirrup_world(side), 1.0)

func _pose_horse_transition(delta: float) -> void:
	var t: float = actor.get_meta("horse_transition_progress", 0.0)
	var dismounting: bool = actor.get_meta("horse_transition", "") == "dismount"
	var u: float = 1.0 - t if dismounting else t
	var mount: Node3D = actor.get_meta("mounted_vehicle")
	var entry_side: float = actor.get_meta("horse_transition_side", -1.0)
	var crossing_side := "r" if entry_side < 0.0 else "l"
	var swing := sin(smoothstep(0.25, 0.90, u) * PI)
	var seated := smoothstep(0.55, 1.0, u)
	var weight := 1.0 - exp(-24.0 * delta)
	model.position = model.position.lerp(Vector3(0, -0.9, 0), weight)
	model.rotation.x = lerpf(model.rotation.x, 0.0, weight)
	pose("pelvis", Vector3(-0.08 * swing, 0, -entry_side * 0.10 * swing), weight)
	pose("spine_01", Vector3(-0.24 * swing, 0, 0), weight)
	pose("spine_02", Vector3(-0.12 * swing, 0, 0), weight)
	for side in ["l", "r"]:
		var sign_side := 1.0 if side == "l" else -1.0
		var crossing: float = swing if side == crossing_side else 0.0
		var supporting: float = sin(u * PI) if side != crossing_side else 0.0
		pose("thigh_" + side, Vector3(-0.35 * seated - 1.45 * crossing - 0.55 * supporting, 0, sign_side * (0.55 * seated + 0.85 * crossing)), weight)
		pose("calf_" + side, Vector3(0.90 * seated + 1.15 * crossing + 0.65 * supporting, 0, 0), weight)
		pose("foot_" + side, Vector3(0.12 * seated - 0.15 * crossing, 0, 0), weight)
		pose("upperarm_" + side, Vector3(-0.4, 0, -sign_side * 0.35), weight)
		pose("lowerarm_" + side, Vector3(-0.7, 0, 0), weight)
	# Hold the top of the pommel/cantle with the palm facing down.
	skeleton.force_update_all_bone_transforms()
	var contact := smoothstep(0.0, 0.18, u)
	var world_palm := Basis(-mount.global_basis.x, -mount.global_basis.z, -mount.global_basis.y)
	for side in ["l", "r"]:
		var hand_index := skeleton.find_bone("hand_" + side)
		var hand_basis: Basis = skeleton.global_basis.inverse() * world_palm * (equipment.palm_axes[side] as Basis).inverse()
		var target := skeleton.to_local(mount.saddle_grip_world(side))
		for pass_index in 4:
			var hand := skeleton.get_bone_global_pose(hand_index)
			var palm: Vector3 = hand * equipment.palm_offsets[side]
			equipment._solve_arm(side, palm.lerp(target, contact) - hand_basis * equipment.palm_offsets[side])
			var parent := skeleton.get_bone_parent(hand_index)
			var rotation := (skeleton.get_bone_global_pose(parent).basis.inverse() * hand_basis).orthonormalized().get_rotation_quaternion()
			skeleton.set_bone_pose_rotation(hand_index, skeleton.get_bone_pose_rotation(hand_index).slerp(rotation, contact))
			skeleton.force_update_all_bone_transforms()
		equipment._grasp(side, contact * 0.65)
		var foot_contact := smoothstep(0.1, 0.3, u) if side != crossing_side else seated
		_horse_foot_contact(side, mount.stirrup_world(side), foot_contact)

func _horse_foot_contact(side: String, world_target: Vector3, weight: float, knee_pole: Vector3 = Vector3(0, 0, 1), sole_normal: Vector3 = Vector3.UP) -> void:
	if weight <= 0.0: return
	var thigh := "thigh_" + side
	var calf := "calf_" + side
	var foot := "foot_" + side
	var foot_index := skeleton.find_bone(foot)
	var rest := skeleton.get_bone_global_rest(foot_index)
	var surface_up: Vector3 = (skeleton.global_basis.inverse()*sole_normal).normalized()
	var sole_basis: Basis = Basis(Quaternion(Vector3.UP,surface_up))*rest.basis
	var sole_offset: Vector3 = rest.basis.inverse() * Vector3(0, -0.085, 0.06)
	var target: Vector3 = skeleton.to_local(world_target) - sole_basis * sole_offset
	var current := skeleton.get_bone_global_pose(foot_index)
	target = current.origin.lerp(target, weight)
	var origin := skeleton.get_bone_global_pose(skeleton.find_bone(thigh)).origin
	var a := skeleton.get_bone_global_rest(skeleton.find_bone(thigh)).origin.distance_to(skeleton.get_bone_global_rest(skeleton.find_bone(calf)).origin)
	var b := skeleton.get_bone_global_rest(skeleton.find_bone(calf)).origin.distance_to(rest.origin)
	var direction := (target-origin).normalized()
	var distance := clampf(origin.distance_to(target), 0.001, a+b-0.001)
	var pole := knee_pole
	pole = (pole-direction*pole.dot(direction)).normalized()
	var along := (a*a-b*b+distance*distance)/(2.0*distance)
	for pass_index in 4:
		equipment._aim_bone(thigh, origin+direction*along+pole*sqrt(maxf(0.0,a*a-along*along)), calf)
		equipment._aim_bone(calf, origin+direction*distance, foot)
	var parent := skeleton.get_bone_parent(foot_index)
	var foot_basis := skeleton.get_bone_global_pose(parent).basis.inverse() * sole_basis
	skeleton.set_bone_pose_rotation(foot_index, foot_basis.orthonormalized().get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()

func keep_climb_body_outside(normal: Vector3, face: Vector3, top: float, lip_depth: float = .075) -> void:
	skeleton.force_update_all_bone_transforms()
	var outward_shift := 0.0
	for sample in [{"bone":"pelvis","radius":.16},{"bone":"spine_02","radius":.18},{"bone":"head","radius":.13},{"bone":"upperarm_l","radius":.10},{"bone":"upperarm_r","radius":.10}]:
		var point: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone(sample.bone)).origin)
		if point.y >= top+.18: continue
		var surface: float = lip_depth if point.y > top-.12 else 0.0
		var clearance: float = (point-face).dot(normal)
		outward_shift = maxf(outward_shift,float(sample.radius)+surface+.02-clearance)
	if outward_shift > 0.0:
		model.global_position += normal*outward_shift
		skeleton.force_update_all_bone_transforms()

func _pose_climb(delta: float) -> void:
	for solver in climb_ik.values():
		# The AnimationTree is advanced manually; solve contact after that pose.
		solver.influence = 0.0
		if solver.is_running(): solver.stop()
	var component: Node = actor.get_node("ClimbComponent")
	if component.releasing:
		if motion_tree != null: motion_tree.release_climb(delta)
		return
	if component.window.active:
		component.window.pose(self,delta)
		return
	var t: float = clampf(component.progress,0.0,1.0)
	if motion_tree != null: motion_tree.update_climb(delta, component.tree_pose_progress())
	var weight := 1.0-exp(-15.0*delta)
	# The climb tree already bends the pelvis and spine for the mantle.
	model.rotation.x = lerpf(model.rotation.x,0.0,weight)
	model.position = model.position.lerp(Vector3(0,-.9,0),weight)
	# Four beats: reach, alternating handholds, a two-handed mantle, then recovery.
	var ledge_y: float = component.landing.y-.94
	# Keep the animated torso and head outside the solid face until they clear
	# the coping. The bent rig can reach beyond its collision capsule.
	keep_climb_body_outside(component.wall_normal,component.wall_point,ledge_y)
	var base_y: float = component.hold_base_y if component.has_holds else ledge_y-4.8+.42
	var contact_blend: float = smoothstep(.04,.14,t)*(1.0-smoothstep(.87,.95,t))
	if component.leap_active and component.leap.phase != "mantle": contact_blend = component.leap.weight()
	var wall_tangent: Vector3 = Vector3.UP.cross(component.wall_normal).normalized()
	for side in ["l","r"]:
		var side_offset: float = (-.24 if side=="l" else .24) if component.has_holds else (-.42 if side=="l" else .42)
		var row: int = clampi(roundi((actor.global_position.y+.75-base_y)/.55),0,7)
		var hand_y: float = base_y+row*.55+.07
		hand_y = minf(ledge_y+.08,hand_y)
		var face: Vector3 = component.wall_point+component.wall_normal*.18
		face.y = hand_y
		face += wall_tangent*(side_offset+(.08 if component.has_holds and row%2==1 else 0.0))
		var top_target: Vector3=component.wall_point+component.wall_normal*.14
		top_target.y=ledge_y+.08
		top_target+=wall_tangent*side_offset
		var hold: Vector3 = face.lerp(top_target,smoothstep(.68,.82,t))
		if component.has_holds and t < .78:
			hold = component.step_contact(side,false)
		elif component.has_holds:
			hold = component.step_contact(side,false).lerp(top_target,smoothstep(.78,.81,t))
		climb_targets[side].global_position = hold if t >= .14 else climb_targets[side].global_position.lerp(hold,clampf(delta*13.0,0.0,1.0))
	# Solve from the final blended rig pose. SkeletonIK's separate update order
	# left the wrists more than a hand width away on this tall wall.
	skeleton.force_update_all_bone_transforms()
	for side in ["l", "r"]:
		var hand_index: int = skeleton.find_bone("hand_" + side)
		var hand_pose: Transform3D = skeleton.get_bone_global_pose(hand_index)
		var palm: Vector3 = hand_pose * equipment.palm_offsets[side]
		var target_local: Vector3 = skeleton.to_local(climb_targets[side].global_position)
		var desired_palm: Vector3 = palm.lerp(target_local, contact_blend)
		# Use the rig's measured palm frame, not the hand bone's arbitrary axes.
		# Fingers point up the stone and the palm faces into the wall.
		var normal: Vector3 = skeleton.global_basis.inverse()*-component.wall_normal
		var fingers: Vector3 = skeleton.global_basis.inverse()*Vector3.UP
		if t >= .78:
			normal = normal.lerp(skeleton.global_basis.inverse()*Vector3.DOWN,smoothstep(.78,.84,t)).normalized()
			fingers = (skeleton.global_basis.inverse()*-component.wall_normal).lerp(fingers,1.0-smoothstep(.78,.84,t))
		fingers = (fingers-normal*fingers.dot(normal)).normalized()
		var palm_basis := Basis(fingers.cross(normal).normalized(),fingers,normal).orthonormalized()
		var desired_hand: Basis = palm_basis*(equipment.palm_axes[side] as Basis).inverse()
		var hand_basis: Basis = hand_pose.basis.slerp(desired_hand,contact_blend).orthonormalized()
		for pass_index in 6:
			var hand: Transform3D = skeleton.get_bone_global_pose(hand_index)
			equipment._solve_arm(side, desired_palm - hand_basis * equipment.palm_offsets[side],Vector3(.15 if side == "l" else -.15,-1.0,-.1))
			var parent := skeleton.get_bone_parent(hand_index)
			# Pronation belongs in the forearm. Rotating only the wrist pinches
			# the skinned wrist into a narrow twist even with correct palm contact.
			var forearm: Transform3D = skeleton.get_bone_global_pose(parent)
			var rest_forearm: Transform3D = skeleton.get_bone_global_rest(parent)
			var rest_hand: Transform3D = skeleton.get_bone_global_rest(hand_index)
			var wanted_forearm: Basis = hand_basis*(rest_forearm.basis.inverse()*rest_hand.basis).inverse()
			var axis: Vector3 = (skeleton.get_bone_global_pose(hand_index).origin-forearm.origin).normalized()
			var reference: Vector3 = forearm.basis.x
			if absf(reference.normalized().dot(axis)) > .9: reference = forearm.basis.z
			var desired_reference: Vector3 = wanted_forearm*(forearm.basis.inverse()*reference)
			reference = (reference-axis*reference.dot(axis)).normalized()
			desired_reference = (desired_reference-axis*desired_reference.dot(axis)).normalized()
			var roll: float = atan2(axis.dot(reference.cross(desired_reference)),reference.dot(desired_reference))
			var rolled: Basis = Basis(Quaternion(axis,roll))*forearm.basis
			var forearm_parent := skeleton.get_bone_parent(parent)
			var local_forearm: Basis = skeleton.get_bone_global_pose(forearm_parent).basis.inverse()*rolled
			skeleton.set_bone_pose_rotation(parent,local_forearm.orthonormalized().get_rotation_quaternion())
			skeleton.force_update_all_bone_transforms()
			var local_hand: Basis = skeleton.get_bone_global_pose(parent).basis.inverse()*hand_basis
			var wrist_rotation: Quaternion = local_hand.orthonormalized().get_rotation_quaternion()
			var neutral: Quaternion = skeleton.get_bone_rest(hand_index).basis.orthonormalized().get_rotation_quaternion()
			var wrist_angle: float = neutral.angle_to(wrist_rotation)
			var wrist_limit: float = lerpf(.70,1.20,smoothstep(.78,.84,t))
			if wrist_angle > wrist_limit:
				wrist_rotation = neutral.slerp(wrist_rotation,wrist_limit/wrist_angle)
				hand_basis = skeleton.get_bone_global_pose(parent).basis*Basis(wrist_rotation)
			skeleton.set_bone_pose_rotation(hand_index,wrist_rotation)
			skeleton.force_update_all_bone_transforms()
		# Keep the first phalanx above the lip; curl the outer joints over it.
		var hook_weight: float = contact_blend*(1.0-smoothstep(.79,.85,t))
		equipment._grasp(side, hook_weight * .15)
		var curl_axis: Vector3 = (hand_basis*(equipment.palm_axes[side] as Basis)).x
		for finger in ["index","middle","ring","pinky"]:
			equipment._rotate_digit(finger+"_02_"+side,curl_axis,.60*hook_weight)
			equipment._rotate_digit(finger+"_03_"+side,curl_axis,.40*hook_weight)
	# A boot presses into the next stone while its opposite leg rises. The
	# targets follow wall space, so this also works on rotated masonry.
	var foot_contact: float = smoothstep(.12, .22, t) * (1.0 - smoothstep(.69, .86, t))
	for side in ["l", "r"]:
		var step_offset: float = 0.0 if side == "l" else .5
		var cycle: float = fposmod((t - .14) * 3.0 + step_offset, 1.0)
		var rise: float = smoothstep(.22, .62, cycle) * .32
		var foot_target: Vector3 = component.wall_point + component.wall_normal * .13
		var foot_row: int = clampi(roundi((actor.global_position.y-.68+rise-base_y)/.55),0,7)
		foot_target += wall_tangent * ((-.24 if side == "l" else .24)+(.08 if component.has_holds and foot_row%2==1 else 0.0))
		foot_target.y = base_y + foot_row*.55 + .08 if component.has_holds else actor.global_position.y - .68 + rise
		climb_foot_targets[side] = foot_target
		var wall_knee_pole: Vector3 = skeleton.global_basis.inverse() * -component.wall_normal
		var support: float = foot_contact * (1.0 - smoothstep(.18, .55, cycle))
		if component.has_holds and t >= .14 and t < .78:
			foot_target = component.step_contact(side,true)
			support = component.leap.weight(true) if component.leap_active else 1.0
			climb_foot_targets[side] = foot_target
		elif t >= .78:
			var lead: bool = side == "l"
			var lift: float = smoothstep(.78,.88,t) if lead else smoothstep(.84,.91,t)
			foot_target = component.wall_point+component.wall_normal*.32+wall_tangent*(-.22 if lead else .22)
			foot_target.y = lerpf(ledge_y-(.60 if lead else .90),ledge_y+.10,lift)
			foot_target.y = minf(foot_target.y,actor.global_position.y-.55)
			foot_target -= component.wall_normal*(.55*smoothstep(.90,.97,t))
			support = 1.0-smoothstep(.97,1.0,t)
			climb_foot_targets[side] = foot_target
		_horse_foot_contact(side, foot_target, support, wall_knee_pole)

func _pose_detention(delta: float) -> void:
	if motion_tree == null: return
	motion_tree.active = true
	var amount: float = actor.get_meta("detention_blend", 0.0)
	var arrested: bool = actor.get_meta("detention_action", "") == "arrest"
	if actor.get_meta("detention_action", "")=="seated":
		_pose_cell_seated(delta)
		detention_contacts.update(self)
		return
	motion_tree.update_detention(delta, amount, arrested or actor.get_meta("detention_action","")=="escort",float(actor.get_meta("detention_speed",0.0)))
	model.position = Vector3(0, -0.9, 0)
	model.quaternion = Quaternion.IDENTITY
	for solver in climb_ik.values(): solver.influence = 0.0
	var restraint: float = motion_tree.get("parameters/detention_pose/blend_amount") * amount
	if restraint <= 0.001: return
	skeleton.force_update_all_bone_transforms()
	var hip := skeleton.get_bone_global_pose(bones["pelvis"]).origin
	for side in ["l", "r"]:
		var rotations: Dictionary = {}
		for bone in ["upperarm_"+side,"lowerarm_"+side]: rotations[bone] = skeleton.get_bone_pose_rotation(bones[bone])
		var target := hip + Vector3(0.065 if side=="l" else -0.065, -0.03, -0.28)
		equipment._solve_arm(side, target)
		for bone in rotations:
			var idx: int = bones[bone]
			skeleton.set_bone_pose_rotation(idx, rotations[bone].slerp(skeleton.get_bone_pose_rotation(idx), restraint))
		pose("hand_"+side, Vector3(0,0,0), restraint)
		equipment._grasp(side, restraint*0.28)
		skeleton.force_update_all_bone_transforms()
	detention_contacts.update(self)

func _pose_cell_seated(delta: float) -> void:
	var component: Node = actor.get_node("DetentionComponent")
	var seated: float = actor.get_meta("detention_seat_blend",0.0)
	motion_tree.set("parameters/detention/blend_amount",0.0)
	motion_tree.update_rest(delta,seated,seated*.38,component.seat_rising)
	model.position=Vector3(0,-.9,0)
	model.quaternion=Quaternion.IDENTITY
	skeleton.force_update_all_bone_transforms()
	var hip_index: int = bones["pelvis"]
	var hip := skeleton.to_global(skeleton.get_bone_global_pose(hip_index).origin)
	var desired: Vector3 = hip.lerp(component.seat_world,seated)
	model.global_position += desired-hip
	skeleton.force_update_all_bone_transforms()
	for side in ["l","r"]:
		var sign_side := 1.0 if side=="l" else -1.0
		var foot: Vector3 = component.floor_world+actor.global_basis*Vector3(sign_side*.20,.025,0)
		_horse_foot_contact(side,foot,seated)
		var knee := skeleton.get_bone_global_pose(bones["calf_"+side]).origin
		var target := knee+Vector3(0,.095,-.06)
		var hand_index: int=bones["hand_"+side]
		var arm_before: Dictionary={}
		for bone in ["upperarm_"+side,"lowerarm_"+side,"hand_"+side]: arm_before[bone]=skeleton.get_bone_pose_rotation(bones[bone])
		for pass_index in 3:
			var desired_hand: Basis=Basis(Vector3.RIGHT,Vector3.BACK,Vector3.DOWN)*(equipment.palm_axes[side] as Basis).inverse()
			var parent_index: int=skeleton.get_bone_parent(hand_index)
			skeleton.set_bone_pose_rotation(hand_index,(skeleton.get_bone_global_pose(parent_index).basis.inverse()*desired_hand).get_rotation_quaternion())
			skeleton.force_update_all_bone_transforms()
			var hand_pose:=skeleton.get_bone_global_pose(hand_index)
			var wrist: Vector3 = target-hand_pose.basis*equipment.palm_offsets[side]
			equipment._solve_arm(side,wrist)
			skeleton.force_update_all_bone_transforms()
		for bone in arm_before:
			var index: int=bones[bone]
			skeleton.set_bone_pose_rotation(index,arm_before[bone].slerp(skeleton.get_bone_pose_rotation(index),seated))
		equipment._grasp(side,.13*seated)
	pose("head",Vector3(.08,0,0),seated)
