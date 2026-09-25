extends Node3D
## Rest-relative, model-space procedural animation for the MPFB game rig.
const Equipment = preload("res://player/arjun_equipment.gd")
const WeaponWheel = preload("res://player/weapon_wheel.gd")
var equipment: Node3D
var talwar_equipped: bool:
	get:
		return equipment != null and not equipment.stowed and equipment.selected == Equipment.Selection.TALWAR
var skeleton: Skeleton3D
var model: Node3D
var weapon: Node3D
var phase := 0.0
var breath := 0.0
var motion := 0.0
var swim_blend := 0.0
var slash_phase := -1.0
var slash_target_world := Vector3.ZERO
var punch_phase := -1.0
var kick_phase := -1.0
var bones: Dictionary = {}
var base_rotations: Dictionary = {}
var axes: Dictionary = {}
var climb_ik: Dictionary = {}
var climb_targets: Dictionary = {}
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
	for i in skeleton.get_bone_count():
		var bone := skeleton.get_bone_name(i)
		bones[bone] = i
		base_rotations[bone] = skeleton.get_bone_pose_rotation(i)
		axes[bone] = skeleton.get_bone_global_rest(i).basis.orthonormalized().inverse()
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
		KEY_H:
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
	if actor.get_meta("river_action", "") != "":
		_pose_river_action(delta)
		return
	if actor.get_meta("climbing",false):
		_pose_climb(delta)
		return
	if actor.has_meta("mounted_vehicle"):
		var mount: Node = (actor.get_meta("mounted_vehicle") if actor.has_meta("mounted_vehicle") else null)
		if is_instance_valid(mount) and mount.is_in_group("horses"):
			for solver in climb_ik.values(): solver.influence = 0.0
			if actor.get_meta("horse_transition", "") != "":
				_pose_horse_transition(delta)
			else:
				_pose_horse_riding(delta)
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
	# Pivot near the chest when leaning into the water, keeping the face above it.
	model.rotation.x = lerpf(model.rotation.x, swimming * 1.05, blend)
	model.position = Vector3(0, -0.9 + swimming * 0.65 + absf(sin(phase)) * stride * 0.045, 0)
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
		# Wind up over the right shoulder, then sweep the blade across the rope.
		var sweep := smoothstep(0.18,0.72,slash_phase)
		var release := 1.0 - smoothstep(0.76,1.0,slash_phase)
		pose("spine_02",Vector3(-0.10,lerpf(-0.25,0.38,sweep),0.0),release)
		pose("upperarm_r",Vector3(lerpf(-1.15,0.35,sweep),lerpf(-0.65,0.65,sweep),lerpf(-0.60,0.10,sweep)),release)
		pose("lowerarm_r",Vector3(lerpf(-1.15,-0.40,sweep),0,0),release)
		equipment.apply_sword_strike(slash_phase,slash_target_world)
	if punch_phase >= 0.0:
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
	if kick_phase >= 0.0:
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
				duration = 5.0
			Equipment.Selection.PISTOL:
				reload_node = actor.get_node_or_null("PistolCombat")
				duration = 3.8
			Equipment.Selection.DOUBLE_GUN:
				reload_node = actor.get_node_or_null("DoubleGunCombat")
				duration = 4.4
		if reload_node != null and reload_node.reload_remaining > 0.0:
			equipment.reload_progress = clampf(1.0-reload_node.reload_remaining/duration,0.0,1.0)
	equipment.apply_rifle_grip(armed and slash_phase >= 0.0)

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
	pose("spine_01",Vector3(-.10,0,0),weight)
	pose("spine_02",Vector3(sin(breath)*.015,0,0),weight)
	pose("head",Vector3(.04,0,0),weight)

	if is_instance_valid(boat) and boat.has_method("paddle_grip_world") and boat.paddle_blend > .01:
		skeleton.force_update_all_bone_transforms()
		var rod_axis: Vector3 = (skeleton.global_basis.inverse()*boat.paddle_rod_world_axis()).normalized()
		var palm_normal := Vector3.DOWN
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

func _pose_cart_driver(delta: float) -> void:
	_pose_seated(delta)
	var weight := 1.0-exp(-10.0*delta)
	var steer := Input.get_axis("move_right", "move_left")
	pose("spine_01", Vector3(-.06, steer*.08, 0), weight)
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
		skeleton.force_update_all_bone_transforms()
		for pass_index in 4:
			for side in ["l", "r"]:
				var grip: Vector3 = skeleton.to_local(cart.rein_grip_world(side))
				var hand: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone("hand_"+side))
				equipment._solve_arm(side, grip-hand.basis*equipment.palm_offsets[side])
		for side in ["l", "r"]:
			equipment._grasp(side)
func _pose_horse_riding(delta: float) -> void:
	var weight := 1.0-exp(-9.0*delta)
	var mount: Node = (actor.get_meta("mounted_vehicle") if actor.has_meta("mounted_vehicle") else null)
	var lean: float = clampf(absf(mount.pace)/mount.GALLOP_SPEED,0.0,1.0)*.12
	if not mount.is_on_floor(): lean += .08
	model.rotation.x = lerpf(model.rotation.x,0.0,weight)
	model.position = model.position.lerp(Vector3(0,-.9,0),weight)
	breath += delta*1.8
	for side in ["l","r"]:
		var s := 1.0 if side=="l" else -1.0
		pose("thigh_"+side,Vector3(-.35,s*.22,s*.55),weight)
		pose("calf_"+side,Vector3(.9,0,0),weight)
		pose("foot_"+side,Vector3(.12,0,0),weight)
		pose("upperarm_"+side,Vector3(-.30,0,-s*.40),weight)
		pose("lowerarm_"+side,Vector3(-.50,0,0),weight)
	pose("pelvis",Vector3(0,0,0),weight)
	pose("spine_01",Vector3(-.04-lean,0,0),weight)
	pose("spine_02",Vector3(sin(breath)*.012,0,0),weight)
	pose("head",Vector3(.03,0,0),weight)

func _pose_horse_transition(delta: float) -> void:
	var t: float = actor.get_meta("horse_transition_progress", 0.0)
	var dismounting: bool = actor.get_meta("horse_transition", "") == "dismount"
	var swing: float = sin(t * PI)
	var seated: float = (1.0 - t) if dismounting else t
	var weight := 1.0 - exp(-12.0 * delta)
	model.position = model.position.lerp(Vector3(0, -0.9 + swing * 0.08, 0), weight)
	model.rotation.x = lerpf(model.rotation.x, 0.0, weight)
	pose("pelvis", Vector3(-0.1 * swing, 0, 0.12 * swing), weight)
	pose("spine_01", Vector3(-0.3 * swing, 0, 0), weight)
	pose("spine_02", Vector3(-0.18 * swing, 0, 0), weight)
	for side in ["l", "r"]:
		var crossing: float = swing if side == "r" else 0.25 * swing
		pose("thigh_" + side, Vector3(-0.35 * seated + 1.15 * crossing, 0, (0.55 if side == "l" else -0.55) * seated + crossing * 0.38), weight)
		pose("calf_" + side, Vector3(0.90 * seated - 0.95 * crossing, 0, 0), weight)
		pose("foot_" + side, Vector3(0.12 * seated + 0.2 * crossing, 0, 0), weight)
		pose("upperarm_" + side, Vector3(-0.3 - 0.7 * swing, 0, (-0.4 if side == "l" else 0.4)), weight)
		pose("lowerarm_" + side, Vector3(-0.50 * seated - 0.55 * swing, 0, 0), weight)

func _pose_climb(delta: float) -> void:
	var component: Node = actor.get_node("ClimbComponent")
	var t: float = clampf(component.progress,0.0,1.0)
	var weight := 1.0-exp(-15.0*delta)
	model.rotation.x = lerpf(model.rotation.x,0.0,weight)
	model.position = model.position.lerp(Vector3(0,-.9,0),weight)
	# Four beats: reach, alternating handholds, a two-handed mantle, then recovery.
	var reach: float = smoothstep(0.0,.14,t)
	var mantle: float = smoothstep(.68,.88,t)
	var settle: float = smoothstep(.91,1.0,t)
	var ledge_y: float = component.landing.y-.94
	var base_y: float = ledge_y-4.8
	var contact_blend: float = smoothstep(.04,.16,t)*(1.0-smoothstep(.78,.96,t))
	var wall_tangent: Vector3 = Vector3.UP.cross(component.wall_normal).normalized()
	for side in ["l","r"]:
		var side_offset: float = -.42 if side=="l" else .42
		var hand_y: float = base_y+.42+roundf((actor.global_position.y+.80-base_y-.42)/.55)*.55
		hand_y -= .10 if side=="r" else 0.0
		hand_y = minf(ledge_y+.08,hand_y)
		var face: Vector3 = component.wall_point+component.wall_normal*.18
		face.y = hand_y
		face += wall_tangent*side_offset
		var top_target: Vector3=component.wall_point-component.wall_normal*.24
		top_target.y=ledge_y+.08
		top_target+=wall_tangent*side_offset
		climb_targets[side].global_position=climb_targets[side].global_position.lerp(face.lerp(top_target,smoothstep(.68,.82,t)),clampf(delta*13.0,0.0,1.0))
		climb_ik[side].influence=contact_blend
	var step_cycle: float = t*TAU*2.5
	pose("pelvis",Vector3(-.09*(1.0-mantle),sin(step_cycle)*.05*(1.0-mantle),0),weight)
	pose("spine_01",Vector3(-.22*(1.0-mantle)+.38*mantle*(1.0-settle),0,0),weight)
	pose("spine_02",Vector3(-.14*(1.0-mantle)+.25*mantle*(1.0-settle),0,0),weight)
	pose("head",Vector3(.13*(1.0-mantle)-.16*mantle*(1.0-settle),0,0),weight)
	for side in ["l","r"]:
		var offset: float=0.0 if side=="l" else PI
		var pull: float=maxf(0.0,sin(step_cycle+offset))*(1.0-mantle)
		var upper: Vector3=Vector3(-1.65+.6*pull,-.08,(-.22 if side=="l" else .22))
		upper=upper.lerp(Vector3(-.75,0,(-.13 if side=="l" else .13)),mantle)
		upper=upper.lerp(Vector3.ZERO,settle)
		pose("upperarm_"+side,upper*reach,weight)
		pose("lowerarm_"+side,Vector3(-.35-1.05*pull,0,0)*reach*(1.0-settle),weight)
		var knee: float=maxf(0.0,sin(step_cycle+offset+PI*.55))*(1.0-mantle)
		pose("thigh_"+side,Vector3(.4+.75*knee+.65*mantle,0,0)*reach*(1.0-settle),weight)
		pose("calf_"+side,Vector3(-.45-1.05*knee-.25*mantle,0,0)*reach*(1.0-settle),weight)
		pose("foot_"+side,Vector3(.15+.25*knee,0,0)*reach*(1.0-settle),weight)
