extends Node
## Applies a brief rest-relative low reach after ordinary locomotion poses.
@onready var actor: CharacterBody3D = get_parent()
@onready var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
var amount := 0.0
var pose_kind := "none"
var release_linger := 0.0
var ground_pickup := false
var pickup_target := Vector3.ZERO
var pickup_target_local := Vector3.ZERO
var pickup_start_palm := Vector3.ZERO
var pickup_start_basis := Basis.IDENTITY
var foot_anchors: Dictionary = {}
var foot_bases: Dictionary = {}
var previous_stowed := true
var pickup_weapon := -1
var carried_root: Node3D
var carried_mango: MeshInstance3D
var whole_mango_mesh: Mesh
var bitten_mango_mesh: Mesh
var whole_mango_material: StandardMaterial3D
var bitten_mango_material: StandardMaterial3D
var carried_action := ""
var carried_elapsed := 0.0
var carried_start := Vector3.ZERO
var carried_start_local := Vector3.ZERO
var pickup_anchor_transform := Transform3D.IDENTITY

func _ready() -> void:
	process_priority = 10
	actor.get_node("ConsumableComponent").mango_eaten.connect(complete_mango.bind(true))
	carried_mango = MeshInstance3D.new()
	carried_mango.name = "CarriedMango"
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.13
	whole_mango_mesh = mesh
	bitten_mango_mesh = _make_bitten_mango(mesh)
	carried_mango.mesh = whole_mango_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.93,0.53,0.07)
	material.roughness = 0.75
	whole_mango_material = material
	bitten_mango_material = material.duplicate()
	bitten_mango_material.vertex_color_use_as_albedo = true
	bitten_mango_material.albedo_color = Color(0.92, 0.78, 0.55)
	carried_mango.material_override = whole_mango_material
	carried_root = Node3D.new()
	add_child(carried_root)
	carried_root.add_child(carried_mango)
	carried_mango.hide()

func _process(delta: float) -> void:
	carried_root.visible = not actor.first_person
	if visual.skeleton == null: return
	if actor.get_meta("detention_action", "") != "" or actor.get_meta("climbing",false) or actor.has_meta("mounted_vehicle") or actor.get_meta("river_action","") != "" or actor.get_meta("stealth_stance","") != "" or actor.get_meta("rest_action", "") != "":
		if ground_pickup: _finish_ground_pickup()
		amount = 0.0
		release_linger = 0.0
		return
	if ground_pickup and (visual.equipment.selected != pickup_weapon or not visual.equipment.stowed):
		_finish_ground_pickup()
		amount = 0.0
		return
	var active: bool = actor.get_meta("interaction_reach",false)
	if active and is_instance_valid(actor.hold_target) and actor.hold_target.interaction_icon == "mango":
		if not ground_pickup or not carried_action.is_empty():
			if ground_pickup: _finish_ground_pickup()
			_begin_ground_pickup()
		pickup_target = actor.hold_target.pickup_point()
		pickup_target_local = visual.to_local(pickup_target)
	if ground_pickup:
		_process_ground_pickup(delta, active)
		return
	if active:
		pose_kind = str(actor.get_meta("interaction_pose_kind","low_reach"))
		release_linger = .3
	else:
		release_linger = maxf(0.0,release_linger-delta)
	amount = move_toward(amount,1.0 if active or release_linger > 0.0 else 0.0,delta*3.5)
	if amount <= .001: return
	var weight := clampf(amount*.72,0.0,.72)
	var deep := pose_kind == "kneel"
	var drop := .40 if deep else .25
	visual.model.position.y = lerpf(visual.model.position.y,-.9-drop,amount)
	visual.model.rotation.x = lerpf(visual.model.rotation.x,.11 if deep else .07,amount)
	visual.pose("pelvis",Vector3(.08,0,0),weight)
	visual.pose("spine_01",Vector3(.46 if deep else .34,0,0),weight)
	visual.pose("spine_02",Vector3(.22 if deep else .13,0,0),weight)
	visual.pose("head",Vector3(-.18,0,0),weight)
	visual.pose("thigh_l",Vector3(1.08 if deep else .88,0,-.12),weight)
	visual.pose("calf_l",Vector3(-1.58 if deep else -1.15,0,0),weight)
	visual.pose("thigh_r",Vector3(.76 if deep else .88,0,.10),weight)
	visual.pose("calf_r",Vector3(-1.15,0,0),weight)
	visual.pose("foot_l",Vector3(.32,0,0),weight)
	visual.pose("foot_r",Vector3(.20,0,0),weight)
	visual.pose("upperarm_r",Vector3(-1.12,0,.22),weight)
	visual.pose("lowerarm_r",Vector3(-.65,0,0),weight)
	visual.pose("upperarm_l",Vector3(-.73,0,-.20),weight)
	visual.pose("lowerarm_l",Vector3(-.78,0,0),weight)

func complete_mango(eat: bool) -> void:
	# Cosmetic only: successful inventory/nutrition transactions remain immediate.
	if visual.skeleton == null or visual.equipment.swimming or actor.has_meta("mounted_vehicle") or actor.get_meta("rest_action", "") != "" or actor.get_meta("climbing", false) or actor.get_meta("river_action", "") != "" or actor.get_meta("stealth_stance", "") != "": return
	if not ground_pickup: _begin_ground_pickup()
	carried_action = "eat" if eat else "store"
	carried_elapsed = 0.0
	var hand: Transform3D = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_r"))
	carried_start = visual.skeleton.to_global(hand * visual.equipment.palm_offsets["r"])
	carried_start_local = visual.to_local(carried_start)
	carried_mango.mesh = whole_mango_mesh
	carried_mango.material_override = whole_mango_material
	carried_mango.show()

func _begin_ground_pickup() -> void:
	ground_pickup = true
	amount = 0.0
	release_linger = 0.0
	previous_stowed = visual.equipment.stowed
	pickup_weapon = visual.equipment.selected
	pickup_anchor_transform = visual.global_transform
	var start_hand: Transform3D = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_r"))
	pickup_start_palm = visual.skeleton.to_global(start_hand * visual.equipment.palm_offsets["r"])
	pickup_start_basis = visual.skeleton.global_basis * start_hand.basis
	visual.equipment.stowed = true
	visual.equipment._refresh()
	for side in ["l", "r"]:
		var foot: Transform3D = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("foot_" + side))
		var ankle: Vector3 = visual.skeleton.to_global(foot.origin)
		var basis: Basis = visual.skeleton.global_basis * foot.basis
		var query := PhysicsRayQueryParameters3D.create(ankle + Vector3.UP * 0.35, ankle + Vector3.DOWN * 0.45)
		query.exclude = [actor.get_rid()]
		var ground := actor.get_world_3d().direct_space_state.intersect_ray(query)
		if not ground.is_empty() and ground.normal.y > 0.70 and absf((ankle.y - ground.position.y) - 0.07) < 0.20:
			basis = Basis(Quaternion(Vector3.UP, ground.normal)) * basis
			var sole_depth := 0.07
			var contacts := visual.get_node_or_null("LocomotionFootContact")
			if contacts != null and not contacts.sole_points[side].is_empty():
				var lowest := INF
				for sole_point in contacts.sole_points[side]:
					lowest = minf(lowest, (basis * sole_point).dot(ground.normal))
				sole_depth = -lowest + 0.005
			ankle = ground.position + ground.normal * sole_depth
		foot_anchors[side] = ankle
		foot_bases[side] = basis

func _process_ground_pickup(delta: float, active: bool) -> void:
	# Settle before the short hold completes, then leave the hand at the fruit
	# briefly during recovery without keeping a reference to a freed pickup.
	if not carried_action.is_empty():
		carried_elapsed += delta
		if carried_action == "eat" and carried_elapsed >= 0.88:
			carried_mango.mesh = bitten_mango_mesh
			carried_mango.material_override = bitten_mango_material
		active = false
	if active:
		release_linger = 0.08
	else:
		release_linger = maxf(0.0, release_linger - delta)
	amount = move_toward(amount, 1.0 if active or release_linger > 0.0 else 0.0, delta * (5.0 if active else 3.5))
	if amount <= 0.001 and (carried_action.is_empty() or carried_elapsed >= (1.6 if carried_action == "eat" else 0.65)):
		_finish_ground_pickup()
		return
	var weight := smoothstep(0.0, 1.0, amount)
	# Sample the locomotion feet before lowering the model for the crouch.
	var locomotion_feet: Dictionary = {}
	if not active:
		for side in ["l", "r"]:
			var foot: Transform3D = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("foot_" + side))
			locomotion_feet[side] = visual.skeleton.global_transform * foot
	visual.model.position.y -= 0.60 * weight
	var local_target := visual.to_local(pickup_target) if active else pickup_target_local
	visual.model.position.x += clampf(local_target.x * 0.8, -0.15, 0.15) * weight
	visual.model.position.z += clampf(local_target.z * 0.3, 0.0, 0.2) * weight
	visual.pose("pelvis", Vector3(0.10, 0, 0), weight)
	visual.pose("spine_01", Vector3(0.50, 0, 0), weight)
	visual.pose("spine_02", Vector3(0.25, 0, 0), weight)
	visual.pose("head", Vector3(-0.20, 0, 0), weight)
	if carried_action == "eat":
		var reaction := smoothstep(0.82, 0.92, carried_elapsed) * (1.0 - smoothstep(1.22, 1.48, carried_elapsed))
		visual.pose("head", Vector3(-0.035 * sin((carried_elapsed - 0.82) * TAU * 5.0), 0, 0), reaction)
	visual.pose("upperarm_l", Vector3(-0.25, 0, -0.25), weight)
	visual.pose("lowerarm_l", Vector3(-0.60, 0, 0), weight)
	for side in (["l", "r"] if weight > 0.001 else []):
		# Keep the feet planted during the held reach. Once controls resume,
		# carry the recovering crouch with the body instead of stretching back.
		var follow := Transform3D.IDENTITY if active else visual.global_transform * pickup_anchor_transform.affine_inverse()
		var foot_world: Vector3 = follow * foot_anchors[side]
		var foot_basis: Basis = follow.basis * foot_bases[side]
		if not active:
			var locomotion_foot: Transform3D = locomotion_feet[side]
			foot_world = locomotion_foot.origin.lerp(foot_world, weight)
			foot_basis = locomotion_foot.basis.orthonormalized().slerp(foot_basis.orthonormalized(), weight)
		var target: Vector3 = visual.skeleton.to_local(foot_world)
		var right_axis: Vector3 = (visual.skeleton.get_bone_global_rest(visual.skeleton.find_bone("upperarm_r")).origin - visual.skeleton.get_bone_global_rest(visual.skeleton.find_bone("upperarm_l")).origin).normalized()
		var forward_axis: Vector3 = (visual.skeleton.global_basis.inverse() * visual.global_basis.z).normalized()
		var knee_pole: Vector3 = right_axis * (0.60 if side == "r" else -0.60) + forward_axis * 1.0
		_solve_limb("thigh_" + side, "calf_" + side, "foot_" + side, target, knee_pole)
		_set_world_basis("foot_" + side, foot_basis)
	var hand_index: int = visual.skeleton.find_bone("hand_r")
	var palm_offset: Vector3 = visual.equipment.palm_offsets["r"]
	var hand: Transform3D = visual.skeleton.get_bone_global_pose(hand_index)
	var palm: Vector3 = visual.skeleton.to_global(hand * palm_offset)
	var target_world: Vector3 = (pickup_start_palm if active else palm).lerp(pickup_target if active else visual.to_global(pickup_target_local), weight)
	var forward := visual.global_basis.z.normalized()
	var normal := Vector3.DOWN
	var across := forward.cross(normal).normalized()
	var hand_world_basis: Basis = Basis(across, forward, normal) * visual.equipment.palm_axes["r"].inverse()
	if not carried_action.is_empty():
		var lift := smoothstep(0.0,0.7,carried_elapsed)
		var destination: Vector3
		if carried_action == "eat":
			var head: Transform3D = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("head"))
			destination = visual.skeleton.to_global(head.origin) + visual.global_basis * Vector3(0,-0.085,0.15)
			var eat_basis: Basis = Basis(Vector3.UP.cross(-forward).normalized(),Vector3.UP,-forward) * visual.equipment.palm_axes["r"].inverse()
			hand_world_basis = hand_world_basis.orthonormalized().slerp(eat_basis.orthonormalized(),lift)
		else:
			var pelvis: Transform3D = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("pelvis"))
			destination = visual.skeleton.to_global(pelvis.origin) + visual.global_basis * Vector3(-0.40,0.02,0.30)
		target_world = visual.to_global(carried_start_local).lerp(destination,lift)
		target_world += visual.global_basis.z * sin(lift * PI) * 0.18
		if carried_elapsed > 1.1 and carried_action == "eat":
			target_world = target_world.lerp(palm,smoothstep(1.1,1.6,carried_elapsed))
		if carried_elapsed > (1.1 if carried_action == "eat" else 0.45): carried_mango.hide()
	if not carried_action.is_empty():
		target_world = target_world.lerp(_outside_pickup_clothes(target_world), smoothstep(0.0,0.15,carried_elapsed))
	if carried_action == "store" and carried_elapsed > 0.45:
		# Once the prop is stored, return the hand to the current locomotion pose.
		var release := smoothstep(0.45, 0.65, carried_elapsed)
		target_world = target_world.lerp(palm, release)
		hand_world_basis = hand_world_basis.orthonormalized().slerp((visual.skeleton.global_basis * hand.basis).orthonormalized(), release)
	var start_basis: Basis = pickup_start_basis if active else visual.skeleton.global_basis * hand.basis
	hand_world_basis = start_basis.orthonormalized().slerp(hand_world_basis.orthonormalized(), maxf(weight, smoothstep(0.0,0.3,carried_elapsed)) if not carried_action.is_empty() else weight)
	for i in 3:
		_set_world_basis("hand_r", hand_world_basis)
		hand = visual.skeleton.get_bone_global_pose(hand_index)
		var wrist_target: Vector3 = visual.skeleton.to_local(target_world) - hand.basis * palm_offset
		var right_axis: Vector3 = (visual.skeleton.get_bone_global_rest(visual.skeleton.find_bone("upperarm_r")).origin - visual.skeleton.get_bone_global_rest(visual.skeleton.find_bone("upperarm_l")).origin).normalized()
		var forward_axis: Vector3 = (visual.skeleton.global_basis.inverse() * visual.global_basis.z).normalized()
		_solve_limb("upperarm_r", "lowerarm_r", "hand_r", wrist_target, right_axis + forward_axis * 0.8)
	_set_world_basis("hand_r", hand_world_basis)
	var grip := smoothstep(0.65,1.0,amount) * 0.35 if carried_action.is_empty() else 0.35
	if carried_action == "store": grip *= 1.0 - smoothstep(0.45, 0.65, carried_elapsed)
	visual.equipment._grasp("r",grip)
	if carried_mango.visible:
		hand = visual.skeleton.get_bone_global_pose(hand_index)
		var palm_basis: Basis = visual.skeleton.global_basis * hand.basis * visual.equipment.palm_axes["r"]
		carried_mango.global_transform = Transform3D(palm_basis,visual.skeleton.to_global(hand * palm_offset) + palm_basis.z * 0.035)

func _finish_ground_pickup() -> void:
	ground_pickup = false
	carried_action = ""
	carried_mango.hide()
	visual.equipment._grasp("r",0.0)
	foot_anchors.clear()
	foot_bases.clear()
	if visual.equipment.selected == pickup_weapon and visual.equipment.stowed and not visual.equipment.swimming:
		visual.equipment.stowed = previous_stowed
		visual.equipment._refresh()

func _outside_pickup_clothes(world_point: Vector3) -> Vector3:
	var rig: Skeleton3D = visual.skeleton
	var point := rig.to_local(world_point)
	var forward := (rig.global_basis.inverse() * visual.global_basis.z).normalized()
	var right := (rig.get_bone_global_rest(rig.find_bone("upperarm_r")).origin - rig.get_bone_global_rest(rig.find_bone("upperarm_l")).origin).normalized()
	# The trousers extend beyond the leg bones. Include hand width in these
	# conservative envelopes, then route around the outside of the garment.
	for pass_index in 3:
		for pair in [["thigh_r","calf_r",0.25],["thigh_l","calf_l",0.25],["calf_r","foot_r",0.20],["calf_l","foot_l",0.20],["pelvis","spine_03",0.29]]:
			var a := rig.get_bone_global_pose(rig.find_bone(pair[0])).origin
			var b := rig.get_bone_global_pose(rig.find_bone(pair[1])).origin
			var segment := b-a
			var nearest := a + segment * clampf((point-a).dot(segment)/maxf(segment.length_squared(),0.0001),0.0,1.0)
			var outward := point-nearest
			if outward.length() < float(pair[2]):
				if outward.length_squared() < 0.0001: outward = right+forward
				if outward.dot(right) < 0.0: outward += right * float(pair[2])
				point = nearest + outward.normalized() * float(pair[2])
	return rig.to_global(point)

func _make_bitten_mango(source: SphereMesh) -> ArrayMesh:
	var arrays := source.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	colors.resize(vertices.size())
	for i in vertices.size():
		var point := vertices[i]
		var radial := Vector2(point.x, point.y - 0.03).length()
		var depth := smoothstep(0.042, 0.012, radial) * smoothstep(0.0, 0.025, point.z)
		point.z -= 0.038 * depth
		point.y -= 0.006 * depth
		vertices[i] = point
		colors[i] = Color(0.93, 0.53, 0.07).lerp(Color(1.0, 0.86, 0.52), depth)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var bitten := ArrayMesh.new()
	bitten.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return bitten

func _set_world_basis(bone: String, world_basis: Basis) -> void:
	var rig: Skeleton3D = visual.skeleton
	var index := rig.find_bone(bone)
	var desired := rig.global_basis.inverse() * world_basis
	var parent := rig.get_bone_parent(index)
	if parent >= 0: desired = rig.get_bone_global_pose(parent).basis.inverse() * desired
	rig.set_bone_pose_rotation(index, desired.orthonormalized().get_rotation_quaternion())
	rig.force_update_all_bone_transforms()

func _solve_limb(upper: String, lower: String, tip: String, target: Vector3, pole: Vector3) -> void:
	var rig: Skeleton3D = visual.skeleton
	var origin := rig.get_bone_global_pose(rig.find_bone(upper)).origin
	var a := rig.get_bone_global_rest(rig.find_bone(upper)).origin.distance_to(rig.get_bone_global_rest(rig.find_bone(lower)).origin)
	var b := rig.get_bone_global_rest(rig.find_bone(lower)).origin.distance_to(rig.get_bone_global_rest(rig.find_bone(tip)).origin)
	var direction := (target - origin).normalized()
	var distance := clampf(origin.distance_to(target), absf(a - b) + 0.035, a + b - 0.0001)
	pole = pole - direction * pole.dot(direction)
	if pole.length_squared() < 0.0001: pole = direction.cross(Vector3.RIGHT)
	pole = pole.normalized()
	var along := (a * a - b * b + distance * distance) / (2.0 * distance)
	var elbow := origin + direction * along + pole * sqrt(maxf(0, a * a - along * along))
	visual.equipment._aim_bone(upper, elbow, lower)
	visual.equipment._aim_bone(lower, origin + direction * distance, tip)
