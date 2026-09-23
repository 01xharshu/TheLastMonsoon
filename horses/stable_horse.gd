extends CharacterBody3D
## One rideable village horse. Forward is local -Z; the stable owns its starting place.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const BodyModel = preload("res://assets/animals/horse/village_horse_body.glb")
const HoofA = preload("res://audio/horses/hoof_dirt_01.wav")
const HoofB = preload("res://audio/horses/hoof_dirt_02.wav")
const HoofRoad = preload("res://audio/horses/hoof_packed_road.wav")
const HoofTimber = preload("res://audio/horses/hoof_timber.wav")
const Landing = preload("res://audio/horses/hoof_landing.wav")
const Tack = preload("res://audio/horses/leather_tack.wav")
const Snort = preload("res://audio/horses/horse_snort.wav")
const Neigh = preload("res://audio/horses/horse_neigh.ogg")
var layout := Layout.new()
var rider: CharacterBody3D
var stolen := false
var pace := 0.0
var gait := 0.0
const WALK_SPEED := 6.0
const GALLOP_SPEED := 13.5
const MAX_STAMINA := 240.0
var stamina := MAX_STAMINA
var gallop_exhausted := false
var saved_layer := 0
var saved_mask := 0
var transition := ""
var transition_time := 0.0
var transition_from := Vector3.ZERO
var transition_to := Vector3.ZERO
var legs: Array[Node3D] = []
var lower_legs: Array[Node3D] = []
var hoof_clearances: Array[float] = []
var body_root: Node3D
var neck_root: Node3D
var tail_root: Node3D
var hoof_players: Array[AudioStreamPlayer3D] = []
var landing_player: AudioStreamPlayer3D
var tack_player: AudioStreamPlayer3D
var voice_player: AudioStreamPlayer3D
var hoof_step_index := 0
var hoof_events := 0
var last_hoof_surface := "earth"
var landing_events := 0
var idle_voice_timer := 13.0

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
	_build_audio()

func _audio_player(label: String, volume: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = label
	player.volume_db = volume
	player.unit_size = 5.0
	player.max_distance = 55.0
	add_child(player)
	return player

func _build_audio() -> void:
	for i in 2:
		hoof_players.append(_audio_player("HoofSound%d" % i,-8.0))
	landing_player = _audio_player("LandingSound",-5.0)
	landing_player.stream = Landing
	tack_player = _audio_player("TackSound",-11.0)
	tack_player.stream = Tack
	voice_player = _audio_player("HorseVoice",-12.0)
	voice_player.stream = Snort

func _hoof_sound() -> void:
	var index: int = hoof_events % hoof_players.size()
	var player: AudioStreamPlayer3D = hoof_players[index]
	last_hoof_surface = ground_sound_surface()
	match last_hoof_surface:
		"timber": player.stream = HoofTimber
		"road": player.stream = HoofRoad
		_: player.stream = HoofA if index == 0 else HoofB
	player.volume_db = -10.0 if last_hoof_surface == "timber" else -8.0
	player.pitch_scale = 1.0 + (float(hoof_events % 5)-2.0)*.025
	player.play()
	hoof_events += 1

func ground_sound_surface() -> String:
	# Physical timber deck takes precedence over the dirt road beneath it.
	var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.45,global_position-Vector3.UP*.65)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var node: Node = hit.get("collider") as Node
	while node != null:
		if node.name == "TimberBridge": return "timber"
		node = node.get_parent()
	if layout.road_distance(global_position.x,global_position.z) < 3.0:
		return "road"
	return "earth"

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

func _taper(parent: Node3D, label: String, at: Vector3, height: float, top: float, bottom: float, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.radial_segments = 12
	mesh.mesh = cylinder
	mesh.position = at
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
	var body_model: Node3D = BodyModel.instantiate()
	body_model.name = "SculptedBody"
	body_root.add_child(body_model)
	neck_root = Node3D.new()
	neck_root.name = "Neck"
	neck_root.position = Vector3(0,1.65,-.62)
	neck_root.rotation.x = -.48
	body_root.add_child(neck_root)
	_ellipsoid(neck_root,"Muzzle",Vector3(0,.55,-.58),Vector3(.16,.12,.18),muzzle)
	tail_root = Node3D.new()
	tail_root.name = "Tail"
	tail_root.position = Vector3(0,1.48,.91)
	body_root.add_child(tail_root)
	for strand in [-2.0,-1.0,0.0,1.0,2.0]:
		var root_at := Vector3(strand*.018,-.03,.03)
		var bend_at := Vector3(strand*.028,-.30,.22)
		var tip_at := Vector3(strand*.042,-.72,.41)
		_cord(tail_root,"TailRoot",root_at,bend_at,.029,dark)
		_cord(tail_root,"TailHair",bend_at,tip_at,.019,dark)
	for side in [-1.0,1.0]:
		_ellipsoid(neck_root,"Eye",Vector3(side*.18,.81,-.43),Vector3(.035,.04,.04),eye)
		_ellipsoid(neck_root,"Ear",Vector3(side*.12,1.02,-.20),Vector3(.055,.12,.065),bay)
		_ellipsoid(neck_root,"Nostril",Vector3(side*.13,.56,-.72),Vector3(.025,.018,.022),dark)
		_box(neck_root,"BridleCheek",Vector3(side*.205,.68,-.40),Vector3(.025,.34,.045),leather)
		_cord(body_root,"ReinFront",Vector3(side*.18,1.88,-1.43),Vector3(side*.30,2.14,-.77),.016,leather)
		_cord(body_root,"ReinBack",Vector3(side*.30,2.14,-.77),Vector3(side*.38,2.21,-.29),.016,leather)
		_cord(body_root,"StirrupLeather",Vector3(side*.36,1.94,.15),Vector3(side*.48,1.38,.20),.023,leather)
		_box(body_root,"StirrupTread",Vector3(side*.48,1.32,.21),Vector3(.20,.035,.19),dark)
		_box(body_root,"StirrupFront",Vector3(side*.48,1.41,.11),Vector3(.027,.18,.027),dark)
		_box(body_root,"StirrupBack",Vector3(side*.48,1.41,.30),Vector3(.027,.18,.027),dark)
		_cord(body_root,"GirthSide",Vector3(side*.36,1.91,.07),Vector3(side*.43,1.12,.07),.032,leather)
	for i in 4:
		var foreleg: bool = i < 2
		var leg := Node3D.new()
		leg.name = "Leg%d" % i
		leg.position = Vector3(-.28 if i%2==0 else .28,1.18,-.60 if foreleg else .64)
		body_root.add_child(leg)
		_ellipsoid(leg,"UpperMuscle",Vector3(0,-.22,.02 if foreleg else -.025),Vector3(.10 if foreleg else .12,.28,.105 if foreleg else .125),bay)
		_taper(leg,"ForearmOrGaskin",Vector3(0,-.38,0),.35,.105,.075,bay)
		var hock := Node3D.new()
		hock.name = "Knee" if foreleg else "Hock"
		hock.position = Vector3(0,-.55,-.015 if foreleg else .10)
		leg.add_child(hock)
		_ellipsoid(hock,"Joint",Vector3.ZERO,Vector3(.095,.10,.11 if foreleg else .14),bay)
		_taper(hock,"Cannon",Vector3(0,-.235,-.015),.45,.069,.055,bay)
		_ellipsoid(hock,"Fetlock",Vector3(0,-.45,-.04),Vector3(.086,.075,.095),bay)
		_taper(hock,"Pastern",Vector3(0,-.50,-.075),.13,.072,.083,bay)
		_taper(hock,"Hoof",Vector3(0,-.57,-.10),.12,.085,.15,dark)
		legs.append(leg)
		lower_legs.append(hock)
		hoof_clearances.append(0.0)
	_ellipsoid(body_root,"Mane",Vector3(0,2.02,-.72),Vector3(.12,.38,.18),dark)
	_box(body_root,"SaddleCloth",Vector3(0,1.90,.01),Vector3(.80,.045,.70),cloth)
	_ellipsoid(body_root,"LeatherSaddle",Vector3(0,1.95,.02),Vector3(.31,.085,.36),leather)
	_ellipsoid(body_root,"Pommel",Vector3(0,2.03,-.25),Vector3(.24,.07,.065),leather)
	_ellipsoid(body_root,"Cantle",Vector3(0,2.04,.29),Vector3(.24,.08,.07),leather)
	_cord(body_root,"GirthUnder",Vector3(-.43,1.12,.07),Vector3(.43,1.12,.07),.032,leather)
	_box(neck_root,"Noseband",Vector3(0,.57,-.62),Vector3(.42,.035,.06),leather)

func seat_world() -> Vector3:
	return to_global(Vector3(0,1.98,.02))

func can_board(actor: CharacterBody3D) -> bool:
	return rider == null and not actor.get_meta("climbing",false) and actor.global_position.distance_to(global_position) < 3.0

func board(actor: CharacterBody3D) -> bool:
	if not can_board(actor): return false
	rider = actor
	var first_take := not stolen
	stolen = true
	tack_player.play()
	voice_player.stream = Neigh if first_take else Snort
	voice_player.play()
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
		tack_player.play()
		return true
	actor.inventory.message_requested.emit("No clear ground beside the horse")
	return false

func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var steer := 0.0
	var gallop := false
	if stamina <= 0.0:
		gallop_exhausted = true
	elif stamina >= MAX_STAMINA * .25:
		gallop_exhausted = false
	if rider != null and transition == "" and not rider.inventory_ui.is_open() and not rider.get_meta("map_open",false) and not rider.get_meta("weapon_wheel_open",false):
		throttle = Input.get_axis("move_backward","move_forward")
		steer = Input.get_axis("move_right","move_left")
		gallop = Input.is_action_pressed("sprint") and not gallop_exhausted and stamina > 0.0
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = 5.7
			tack_player.play()
	stamina = clampf(stamina + delta * (-1.6 if gallop and absf(throttle)>.1 else 2.5),0.0,MAX_STAMINA)
	var target := throttle * (GALLOP_SPEED if gallop else WALK_SPEED)
	pace = move_toward(pace,target,delta * (6.5 if throttle != 0.0 else 9.0))
	rotation.y += steer * delta * 1.35 * clampf(absf(pace)/2.0,0.0,1.0)
	var forward := -global_basis.z
	velocity.x = forward.x * pace
	velocity.z = forward.z * pace
	var was_grounded := is_on_floor()
	var fall_speed: float = velocity.y
	velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	move_and_slide()
	if not was_grounded and is_on_floor() and fall_speed < -1.0:
		landing_player.play()
		landing_events += 1
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
	gait += delta * (1.8 + absf(pace) * .65) * clampf(absf(pace),0.0,1.0)
	var new_hoof_step: int = floori(gait * 4.0 / TAU)
	if is_on_floor() and absf(pace) > .8 and new_hoof_step > hoof_step_index:
		_hoof_sound()
	hoof_step_index = new_hoof_step
	if rider == null:
		idle_voice_timer -= delta
		if idle_voice_timer <= 0.0:
			voice_player.stream = Snort
			voice_player.play()
			idle_voice_timer = 17.0 + float(randi() % 9)
	var stride := clampf(absf(pace)/GALLOP_SPEED,0.0,1.0)
	for i in legs.size():
		# Four-beat walk blends towards diagonal pairs at speed; bend the lower
		# segment on the lifted half of each step rather than swinging a rigid leg.
		var walk_offset: float = [0.0,PI,PI*.5,PI*1.5][i]
		var trot_offset: float = 0.0 if i==0 or i==3 else PI
		var phase: float = gait + lerpf(walk_offset,trot_offset,smoothstep(.24,.67,stride))
		var swing: float = sin(phase)
		legs[i].position.y = 1.18
		legs[i].rotation.x = (swing * .48 * stride) if is_on_floor() else (-.58 if i<2 else .32)
		lower_legs[i].rotation.x = maxf(0.0,swing) * .44 * stride if is_on_floor() else (1.05 if i<2 else -.55)
	body_root.position.y = (absf(sin(gait*2.0)) * .035 * stride) if is_on_floor() else .03
	body_root.rotation.x = 0.0 if is_on_floor() else (-.09 if velocity.y > 0.0 else .05)
	# Keep the planted hoof at ground height while the body bobs; lift the
	# advancing hoof clear of the surface. These are small corrections to the
	# procedural joints, not a full anatomical leg solver.
	if is_on_floor():
		for i in legs.size():
			var walk_offset: float = [0.0,PI,PI*.5,PI*1.5][i]
			var trot_offset: float = 0.0 if i==0 or i==3 else PI
			var phase: float = gait + lerpf(walk_offset,trot_offset,smoothstep(.24,.67,stride))
			var lift: float = maxf(0.0,sin(phase)) * .085 * stride
			var hoof_y: float = lower_legs[i].to_global(Vector3(0,-.64,-.08)).y
			var correction: float = clampf(global_position.y + .015 + lift - hoof_y,-.18,.18)
			legs[i].position.y += correction
			hoof_clearances[i] = lower_legs[i].to_global(Vector3(0,-.64,-.08)).y - global_position.y
	neck_root.rotation.x = -.48 + sin(gait*2.0)*.035*stride
	tail_root.rotation.x = sin(gait*.45)*.10
