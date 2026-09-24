@tool
extends Node3D
## Review candidate: two-wheeled ekka passenger cart or open produce cart.
@export_enum("Passenger ekka", "Open goods cart") var variant := 0:
	set(value):
		variant = value
		if is_inside_tree(): _build()
@export var show_horse := true:
	set(value):
		show_horse = value
		if is_inside_tree(): _build()

const HorseVisual = preload("res://assets/animals/horse/rigged_horse_candidate.glb")
var visual_root: Node3D
var wheels: Array[Node3D] = []
var horse_animation: AnimationPlayer
var seat_sockets: Dictionary = {}
var boarding: Node
var rider: CharacterBody3D:
	get:
		return boarding.rider if boarding != null else null

func _ready() -> void:
	_build()
	if Engine.is_editor_hint(): return
	boarding = preload("res://vehicles/cart_rider.gd").new()
	boarding.configure(self)
	add_child(boarding)
	_add_boarding_point("DriverSeat", Vector3(-1.0, 1.5, 1.7))
	if variant == 0: _add_boarding_point("PassengerSeat", Vector3(1.0, 1.5, 2.6))

func _add_boarding_point(seat: String, at: Vector3) -> void:
	var point: Interactable = preload("res://vehicles/cart_boarding_point.gd").new()
	point.name = seat + "Boarding"
	point.position = at
	point.configure(self, seat, "driver" if seat == "DriverSeat" else "passenger")
	var shape := SphereShape3D.new()
	shape.radius = .18
	var collision := CollisionShape3D.new()
	collision.shape = shape
	point.add_child(collision)
	add_child(point)

func board_at(actor: CharacterBody3D, seat: String, role: String) -> bool:
	return boarding.board_at(actor, seat, role) if boarding != null else false

func rein_grip_world(side: String) -> Vector3:
	return to_global(Vector3(-.30 if side == "l" else .30, 1.64, 1.80))

func set_forward_motion(speed: float, delta: float) -> void:
	_animate_motion(speed, delta)

func _mat(color: Color, metal := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	material.metallic = metal
	return material

func _box(label: String, pos: Vector3, size: Vector3, material: Material) -> Node3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	visual_root.add_child(node)
	return node

func _beam(label: String, start: Vector3, finish: Vector3, width: float, material: Material) -> void:
	var middle := (start + finish) * .5
	var part := _box(label,middle,Vector3(width,start.distance_to(finish),width),material)
	part.quaternion = Quaternion(Vector3.UP,(finish-start).normalized())

func _wheel(side: float, center_z: float, radius: float, wood: Material, iron: Material) -> void:
	var center := Vector3(side*.98,radius,center_z)
	var wheel := Node3D.new()
	wheel.name = "WheelLeft" if side < 0.0 else "WheelRight"
	wheel.position = center
	visual_root.add_child(wheel)
	wheels.append(wheel)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius-.075
	torus.outer_radius = radius
	torus.rings = 32
	torus.ring_segments = 8
	rim.mesh = torus
	rim.rotation.z = PI*.5
	rim.material_override = iron
	wheel.add_child(rim)
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = .11
	hub_mesh.bottom_radius = .11
	hub_mesh.height = .18
	hub.mesh = hub_mesh
	hub.rotation.z = PI*.5
	hub.material_override = wood
	wheel.add_child(hub)
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var start := Vector3(0,sin(angle)*.10,cos(angle)*.10)
		var end := Vector3(0,sin(angle)*(radius-.07),cos(angle)*(radius-.07))
		var spoke := MeshInstance3D.new()
		var spoke_mesh := CylinderMesh.new()
		spoke_mesh.top_radius = .020
		spoke_mesh.bottom_radius = .027
		spoke_mesh.height = start.distance_to(end)
		spoke.mesh = spoke_mesh
		spoke.material_override = wood
		spoke.position = (start+end)*.5
		spoke.quaternion = Quaternion(Vector3.UP,(end-start).normalized())
		wheel.add_child(spoke)

func _build() -> void:
	if visual_root != null: visual_root.queue_free()
	wheels.clear()
	seat_sockets.clear()
	horse_animation = null
	visual_root = Node3D.new()
	visual_root.name = "CartVisual"
	add_child(visual_root)
	var wood := _mat(Color(.30,.18,.085))
	var dark_wood := _mat(Color(.18,.105,.05))
	var worn_iron := _mat(Color(.22,.21,.19),.35)
	var leather := _mat(Color(.17,.075,.038))
	var rope := _mat(Color(.54,.43,.24))
	var straw := _mat(Color(.68,.53,.25))
	var radius := .62 if variant == 0 else .68
	var axle_z := 2.35 if variant == 0 else 2.55
	_wheel(-1.0,axle_z,radius,dark_wood,worn_iron)
	_wheel(1.0,axle_z,radius,dark_wood,worn_iron)
	_beam("Axle",Vector3(-1.08,radius,axle_z),Vector3(1.08,radius,axle_z),.09,worn_iron)
	var deck_y := 1.04 if variant == 0 else 1.12
	var deck_z := 2.48 if variant == 0 else 2.75
	var deck_length := 1.9 if variant == 0 else 2.5
	_box("PlankedDeck",Vector3(0,deck_y,deck_z),Vector3(1.75,.13,deck_length),wood)
	for i in 5:
		_box("DeckSeam",Vector3(-.68+float(i)*.34,deck_y+.069,deck_z),Vector3(.012,.005,deck_length),dark_wood)
	for side in [-1.0,1.0]:
		_beam("DraftShaft",Vector3(side*.68,.93,deck_z+deck_length*.42),Vector3(side*.48,1.14,-.75),.075,dark_wood)
		_beam("Underbrace",Vector3(side*.78,.67,axle_z),Vector3(side*.61,.99,1.30),.065,wood)
		_beam("LeatherTrace",Vector3(side*.45,1.22,-1.0),Vector3(side*.61,1.02,1.15),.022,leather)
		_box("ShaftLoop",Vector3(side*.49,1.15,-.51),Vector3(.11,.07,.25),leather)
	if variant == 0:
		_box("PassengerBench",Vector3(0,1.47,2.57),Vector3(1.62,.16,.68),dark_wood)
		_box("Backrest",Vector3(0,1.84,2.93),Vector3(1.64,.68,.13),wood)
		for side in [-1.0,1.0]:
			_box("LowSideRail",Vector3(side*.87,1.47,2.51),Vector3(.08,.42,1.37),wood)
			_beam("SeatSupport",Vector3(side*.68,1.13,2.45),Vector3(side*.68,1.41,2.45),.08,wood)
		_box("FrontFootboard",Vector3(0,1.06,1.56),Vector3(1.55,.09,.44),wood)
		_box("DriverCushion",Vector3(-.43,1.56,2.55),Vector3(.73,.06,.58),leather)
		_box("PassengerCushion",Vector3(.43,1.56,2.55),Vector3(.73,.06,.58),leather)
		_seat("DriverSeat",Vector3(-.43,1.59,2.55))
		_seat("PassengerSeat",Vector3(.43,1.59,2.55))
	else:
		for side in [-1.0,1.0]:
			_box("SlattedSide",Vector3(side*.87,1.44,deck_z),Vector3(.085,.50,deck_length),wood)
			for i in 5:
				_box("SideSlatGap",Vector3(side*.925,1.33,deck_z-1.0+float(i)*.5),Vector3(.015,.04,.08),dark_wood)
		for end in [-1.0,1.0]:
			_box("EndBoard",Vector3(0,1.43,deck_z+end*deck_length*.48),Vector3(1.7,.47,.09),wood)
		for i in 5:
			_box("ProduceBundle",Vector3(-.52+float(i%3)*.46,1.35,deck_z-.61+float(i/3)*.55),Vector3(.37,.33,.43),straw)
		_beam("LoadTie",Vector3(-.84,1.69,deck_z),Vector3(.84,1.69,deck_z),.02,rope)
		_box("DriverBench",Vector3(0,1.44,1.70),Vector3(1.45,.13,.48),dark_wood)
		_seat("DriverSeat",Vector3(0,1.51,1.70))
	if show_horse:
		var horse := HorseVisual.instantiate() as Node3D
		horse.name = "DraftHorseVisual"
		horse.scale = Vector3.ONE*.47
		horse.rotation.y = PI
		horse.position = Vector3(0,.04,-1.15)
		visual_root.add_child(horse)
		var animation := horse.find_child("AnimationPlayer",true,false) as AnimationPlayer
		if animation != null:
			horse_animation = animation
			animation.get_animation("AnimalArmature|Idle").loop_mode = Animation.LOOP_LINEAR
			animation.get_animation("AnimalArmature|Walk").loop_mode = Animation.LOOP_LINEAR
			animation.play("AnimalArmature|Idle")
		for side in [-1.0,1.0]:
			_beam("BreastCollar",Vector3(side*.36,1.53,-1.40),Vector3(side*.24,1.82,-1.83),.055,leather)
			_beam("CollarToTrace",Vector3(side*.36,1.53,-1.40),Vector3(side*.46,1.22,-1.0),.025,leather)
			_beam("Rein",Vector3(side*.22,1.86,-2.30),Vector3(side*.30,1.64,1.80),.012,leather)

func _seat(label: String, at: Vector3) -> void:
	var socket := Node3D.new()
	socket.name = label
	socket.position = at
	visual_root.add_child(socket)
	seat_sockets[label] = socket

func _animate_motion(speed: float, delta: float) -> void:
	var radius := .62 if variant == 0 else .68
	for wheel in wheels:
		wheel.rotation.x += speed * delta / radius
	if horse_animation != null:
		var clip := "AnimalArmature|Walk" if absf(speed) > .25 else "AnimalArmature|Idle"
		if horse_animation.current_animation != clip:
			horse_animation.play(clip,.15)
		horse_animation.speed_scale = clampf(absf(speed)/4.2,.65,1.5) if clip.ends_with("Walk") else 1.0
