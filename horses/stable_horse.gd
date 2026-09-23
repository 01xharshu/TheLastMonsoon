extends CharacterBody3D
## One rideable village horse. Forward is local -Z; the stable owns its starting place.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
var layout := Layout.new()
var rider: CharacterBody3D
var stolen := false
var pace := 0.0
var gait := 0.0
var stamina := 1.0
var saved_layer := 0
var saved_mask := 0
var transition := ""
var transition_time := 0.0
var transition_from := Vector3.ZERO
var transition_to := Vector3.ZERO
var legs: Array[Node3D] = []
var lower_legs: Array[Node3D] = []
var body_root: Node3D
var neck_root: Node3D
var tail_root: Node3D

func _ready() -> void:
	add_to_group("mountable_vehicles")
	add_to_group("horses")
	collision_layer = 1
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = 0.43
	shape.height = 1.65
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.83
	add_child(collider)
	_build_horse()

func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m

func _ellipsoid(parent: Node3D, label: String, at: Vector3, scale_by: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	mesh.mesh = sphere
	mesh.position = at
	mesh.scale = scale_by
	mesh.material_override = mat
	parent.add_child(mesh)

func _box(parent: Node3D, label: String, at: Vector3, size: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = mat
	parent.add_child(mesh)

func _cord(parent: Node3D, label: String, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 6
	mesh.mesh = cylinder
	mesh.position = (a+b)*.5
	mesh.basis = Basis(Quaternion(Vector3.UP,(b-a).normalized()))
	mesh.material_override = mat
	parent.add_child(mesh)

func _build_horse() -> void:
	var bay := _material(Color(0.31,0.14,0.075))
	var dark := _material(Color(0.055,0.036,0.027))
	var leather := _material(Color(0.17,0.075,0.038))
	var cloth := _material(Color(0.40,0.28,0.15))
	var eye := _material(Color(0.018,0.012,0.009))
	var muzzle := _material(Color(0.19,0.10,0.07))
	body_root = Node3D.new()
	body_root.name = "HorseBody"
	add_child(body_root)
	_ellipsoid(body_root,"Barrel",Vector3(0,1.43,0),Vector3(0.43,0.52,0.88),bay)
	_ellipsoid(body_root,"Chest",Vector3(0,1.38,-0.56),Vector3(.40,.50,.36),bay)
	_ellipsoid(body_root,"Haunch",Vector3(0,1.42,.61),Vector3(.40,.48,.38),bay)
	neck_root = Node3D.new()
	neck_root.name = "Neck"
	neck_root.position = Vector3(0,1.65,-.62)
	neck_root.rotation.x = -.48
	body_root.add_child(neck_root)
	_ellipsoid(neck_root,"NeckMass",Vector3(0,.28,-.12),Vector3(.28,.52,.30),bay)
	_ellipsoid(neck_root,"Head",Vector3(0,.73,-.34),Vector3(.18,.26,.34),bay)
	_ellipsoid(neck_root,"Muzzle",Vector3(0,.55,-.58),Vector3(.16,.12,.18),muzzle)
	tail_root = Node3D.new()
	tail_root.name = "Tail"
	tail_root.position = Vector3(0,1.48,.91)
	body_root.add_child(tail_root)
	_ellipsoid(tail_root,"TailMass",Vector3(0,-.35,.28),Vector3(.13,.49,.14),dark)
	for side in [-1.0,1.0]:
		_ellipsoid(neck_root,"Eye",Vector3(side*.18,.81,-.43),Vector3(.035,.04,.04),eye)
		_ellipsoid(neck_root,"Ear",Vector3(side*.12,1.02,-.20),Vector3(.055,.12,.065),bay)
		_ellipsoid(neck_root,"Nostril",Vector3(side*.13,.56,-.72),Vector3(.025,.018,.022),dark)
		_box(neck_root,"BridleCheek",Vector3(side*.205,.68,-.40),Vector3(.025,.34,.045),leather)
		_cord(body_root,"ReinFront",Vector3(side*.18,1.88,-1.43),Vector3(side*.30,2.14,-.77),.016,leather)
		_cord(body_root,"ReinBack",Vector3(side*.30,2.14,-.77),Vector3(side*.41,2.25,-.26),.016,leather)
		_cord(body_root,"StirrupLeather",Vector3(side*.40,1.94,.15),Vector3(side*.61,1.37,.18),.023,leather)
		_box(body_root,"StirrupTread",Vector3(side*.61,1.33,.20),Vector3(.24,.045,.22),dark)
		_box(body_root,"StirrupFront",Vector3(side*.61,1.42,.09),Vector3(.035,.19,.035),dark)
		_box(body_root,"StirrupBack",Vector3(side*.61,1.42,.31),Vector3(.035,.19,.035),dark)
	for i in 4:
		var leg := Node3D.new()
		leg.name = "Leg%d" % i
		leg.position = Vector3(-.27 if i%2==0 else .27,1.18,-.56 if i<2 else .59)
		body_root.add_child(leg)
		_ellipsoid(leg,"Upper",Vector3(0,-.25,0),Vector3(.125,.34,.14),bay)
		var hock := Node3D.new()
		hock.name = "KneeOrHock"
		hock.position = Vector3(0,-.54,.02)
		leg.add_child(hock)
		_ellipsoid(hock,"Joint",Vector3.ZERO,Vector3(.11,.12,.12),bay)
		_ellipsoid(hock,"Cannon",Vector3(0,-.25,0),Vector3(.075,.31,.085),bay)
		_ellipsoid(hock,"Fetlock",Vector3(0,-.47,-.03),Vector3(.10,.10,.11),bay)
		_box(hock,"Hoof",Vector3(0,-.55,-.08),Vector3(.22,.16,.31),dark)
		legs.append(leg)
		lower_legs.append(hock)
	_ellipsoid(body_root,"Mane",Vector3(0,2.02,-.72),Vector3(.12,.38,.18),dark)
	_box(body_root,"SaddleCloth",Vector3(0,1.90,.01),Vector3(.84,.055,.74),cloth)
	_box(body_root,"LeatherSaddle",Vector3(0,1.95,.02),Vector3(.52,.09,.60),leather)
	_box(body_root,"Pommel",Vector3(0,2.04,-.26),Vector3(.49,.12,.09),leather)
	_box(body_root,"Cantle",Vector3(0,2.04,.31),Vector3(.49,.14,.10),leather)
	_box(body_root,"Girth",Vector3(0,1.28,.08),Vector3(.87,.055,.07),leather)
	_box(neck_root,"Noseband",Vector3(0,.57,-.62),Vector3(.42,.035,.06),leather)

func seat_world() -> Vector3:
	return to_global(Vector3(0,1.98,.02))

func can_board(actor: CharacterBody3D) -> bool:
	return rider == null and not actor.get_meta("climbing",false) and actor.global_position.distance_to(global_position) < 3.0

func board(actor: CharacterBody3D) -> bool:
	if not can_board(actor): return false
	rider = actor
	stolen = true
	saved_layer = actor.collision_layer
	saved_mask = actor.collision_mask
	actor.collision_layer = 0
	actor.collision_mask = 0
	actor.set_meta("mounted_vehicle",self)
	actor.is_swimming = false
	actor.velocity = Vector3.ZERO
	actor.survival.set_sprinting(false)
	var visual: Node = actor.get_node("VisualRoot/CharacterVisual")
	visual.equipment.stowed = true
	visual.equipment._refresh()
	transition = "mount"
	transition_time = 0.0
	transition_from = actor.global_position
	actor.set_meta("horse_transition", "mount")
	actor.set_meta("horse_transition_progress", 0.0)
	actor.inventory.message_requested.emit("Horse taken from stable · W/S ride · A/D turn · Shift gallop · Space jump · F dismount")
	return true

func _sync_rider() -> void:
	if rider == null: return
	var visual: Node3D = rider.get_node("VisualRoot/CharacterVisual")
	var pelvis: int = visual.skeleton.find_bone("pelvis")
	if pelvis < 0: return
	var hip_local: Vector3 = rider.to_local(visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(pelvis).origin))
	rider.global_position = seat_world() - hip_local
	rider.visual_root.global_rotation.y = rotation.y + PI
	rider.velocity = Vector3.ZERO

func dismount() -> bool:
	if rider == null or transition != "" or not is_on_floor(): return false
	var actor := rider
	for side in [-1.0,1.0]:
		var p: Vector3 = global_position + global_basis.x * side * 1.55
		p.y = layout.height(p.x,p.z) + 1.0
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = actor.get_node("CollisionShape3D").shape
		query.transform = Transform3D(Basis.IDENTITY,p)
		query.exclude = [get_rid(),actor.get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): continue
		transition = "dismount"
		transition_time = 0.0
		transition_from = actor.global_position
		transition_to = p
		actor.set_meta("horse_transition", "dismount")
		actor.set_meta("horse_transition_progress", 0.0)
		return true
	actor.inventory.message_requested.emit("No clear ground beside the horse")
	return false

func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var steer := 0.0
	var gallop := false
	if rider != null and transition == "" and not rider.inventory_ui.is_open() and not rider.get_meta("map_open",false) and not rider.get_meta("weapon_wheel_open",false):
		throttle = Input.get_axis("move_backward","move_forward")
		steer = Input.get_axis("move_right","move_left")
		gallop = Input.is_key_pressed(KEY_SHIFT) and stamina > .08
		if Input.is_action_just_pressed("jump") and is_on_floor(): velocity.y = 5.7
	stamina = clampf(stamina + delta * (-.12 if gallop and absf(throttle)>.1 else .065),0.0,1.0)
	var target := throttle * (8.2 if gallop else 4.2)
	pace = move_toward(pace,target,delta * (4.5 if throttle != 0.0 else 7.0))
	rotation.y += steer * delta * 1.35 * clampf(absf(pace)/2.0,0.0,1.0)
	var forward := -global_basis.z
	velocity.x = forward.x * pace
	velocity.z = forward.z * pace
	velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	move_and_slide()
	if rider != null:
		if transition == "":
			_sync_rider()
		else:
			transition_time += delta
			var t: float = clampf(transition_time / 0.7, 0.0, 1.0)
			rider.set_meta("horse_transition_progress", t)
			if transition == "mount":
				var visual: Node3D = rider.get_node("VisualRoot/CharacterVisual")
				var pelvis: int = visual.skeleton.find_bone("pelvis")
				var hip_local: Vector3 = rider.to_local(visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(pelvis).origin))
				transition_to = seat_world() - hip_local
			rider.global_position = transition_from.lerp(transition_to, smoothstep(0.0, 1.0, t)) + Vector3.UP * (sin(t * PI) * 0.22)
			rider.visual_root.global_rotation.y = lerp_angle(rider.visual_root.global_rotation.y, rotation.y + PI, t)
			if t >= 1.0:
				var transition_actor := rider
				if transition == "dismount":
					rider = null
					transition_actor.set_meta("mounted_vehicle", null)
					transition_actor.collision_layer = saved_layer
					transition_actor.collision_mask = saved_mask
					transition_actor.velocity = Vector3.ZERO
				transition = ""
				transition_actor.set_meta("horse_transition", "")
	gait += delta * (1.25 + absf(pace) * 1.05) * clampf(absf(pace),0.0,1.0)
	var stride := clampf(absf(pace)/8.2,0.0,1.0)
	for i in legs.size():
		# Four-beat walk blends towards diagonal pairs at speed; bend the lower
		# segment on the lifted half of each step rather than swinging a rigid leg.
		var walk_offset: float = [0.0,PI,PI*.5,PI*1.5][i]
		var trot_offset: float = 0.0 if i==0 or i==3 else PI
		var phase: float = gait + lerpf(walk_offset,trot_offset,smoothstep(.24,.67,stride))
		var swing: float = sin(phase)
		legs[i].rotation.x = (swing * .48 * stride) if is_on_floor() else (-.32 if i<2 else .23)
		lower_legs[i].rotation.x = maxf(0.0,swing) * .44 * stride if is_on_floor() else .56
	body_root.position.y = (absf(sin(gait*2.0)) * .035 * stride) if is_on_floor() else .03
	neck_root.rotation.x = -.48 + sin(gait*2.0)*.035*stride
	tail_root.rotation.x = sin(gait*.45)*.10
