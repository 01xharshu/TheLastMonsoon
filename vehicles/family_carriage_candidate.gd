@tool
extends Node3D
## Four-wheel, two-horse covered household carriage study with coachman's box.
const HorseVisual = preload("res://assets/animals/horse/rigged_horse_candidate.glb")
var visual_root: Node3D
var wheels: Array[Node3D] = []
var horse_animations: Array[AnimationPlayer] = []
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
	_add_boarding_point("CoachmanSeat", Vector3(0,1.7,.17), "driver")
	_add_boarding_point("RearPassengerRight", Vector3(1.15,1.89,2.26), "passenger")
	_add_boarding_point("RearPassengerLeft", Vector3(-1.15,1.89,2.26), "passenger")

func _add_boarding_point(seat: String, at: Vector3, role: String) -> void:
	var point: Interactable = preload("res://vehicles/cart_boarding_point.gd").new()
	point.name = seat + "Boarding"
	point.position = at
	point.configure(self, seat, role)
	var shape := SphereShape3D.new()
	shape.radius = .18
	var collision := CollisionShape3D.new()
	collision.shape = shape
	point.add_child(collision)
	add_child(point)

func board_at(actor: CharacterBody3D, seat: String, role: String) -> bool:
	var boarded: bool = boarding.board_at(actor, seat, role) if boarding != null else false
	if boarded and role == "driver":
		for part in visual_root.get_children():
			if part.name.begins_with("Coachman"): part.visible = false
	return boarded

func show_coachman_blockout() -> void:
	for part in visual_root.get_children():
		if part.name.begins_with("Coachman"): part.visible = true

func rein_grip_world(side: String) -> Vector3:
	return to_global(Vector3(-.20 if side == "l" else .20, 1.97, .43))

func _mat(color: Color, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = .83
	return m

func _box(label: String, at: Vector3, size: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	(parent if parent != null else visual_root).add_child(node)
	return node

func _beam(label: String, a: Vector3, b: Vector3, width: float, material: Material) -> void:
	var node := _box(label,(a+b)*.5,Vector3(width,a.distance_to(b),width),material)
	node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func _roof(material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for i in 12:
		var x0 := lerpf(-1.15,1.15,float(i)/12.0)
		var x1 := lerpf(-1.15,1.15,float(i+1)/12.0)
		var y0 := 3.0 + .14*(1.0-pow(x0/1.15,2.0))
		var y1 := 3.0 + .14*(1.0-pow(x1/1.15,2.0))
		for point in [Vector3(x0,y0,1.31),Vector3(x1,y1,4.19),Vector3(x1,y1,1.31),Vector3(x0,y0,1.31),Vector3(x0,y0,4.19),Vector3(x1,y1,4.19)]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(point)
	var roof := MeshInstance3D.new()
	roof.name = "Roof"
	roof.mesh = surface.commit()
	visual_root.add_child(roof)

func _wheel(side: float, z: float, radius: float, wood: Material, iron: Material) -> void:
	var wheel := Node3D.new()
	wheel.name = "FrontWheel" if z < 2.0 else "RearWheel"
	wheel.position = Vector3(side*1.22,radius,z)
	visual_root.add_child(wheel)
	wheels.append(wheel)
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = radius-.073
	ring.outer_radius = radius
	ring.rings = 32
	ring.ring_segments = 8
	rim.mesh = ring
	rim.rotation.z = PI*.5
	rim.material_override = iron
	wheel.add_child(rim)
	var hub := CylinderMesh.new()
	hub.top_radius = .12
	hub.bottom_radius = .12
	hub.height = .20
	var middle := MeshInstance3D.new()
	middle.mesh = hub
	middle.rotation.z = PI*.5
	middle.material_override = wood
	wheel.add_child(middle)
	for i in 12:
		var angle := TAU*float(i)/12.0
		var tip := Vector3(0,sin(angle)*(radius-.055),cos(angle)*(radius-.055))
		var spoke := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = .021
		mesh.bottom_radius = .029
		mesh.height = radius-.08
		spoke.mesh = mesh
		spoke.position = tip*.51
		spoke.quaternion = Quaternion(Vector3.UP,tip.normalized())
		spoke.material_override = wood
		wheel.add_child(spoke)

func _seat_socket(label: String, at: Vector3, facing_back := false) -> void:
	var socket := Node3D.new()
	socket.name = label
	socket.position = at
	socket.rotation.y = PI if facing_back else 0.0
	visual_root.add_child(socket)
	seat_sockets[label] = socket

func seat_world(label: String) -> Vector3:
	var socket: Node3D = seat_sockets.get(label)
	return socket.global_position if socket != null else global_position

func _build() -> void:
	if visual_root != null: visual_root.queue_free()
	wheels.clear()
	horse_animations.clear()
	seat_sockets.clear()
	visual_root = Node3D.new()
	visual_root.name = "FamilyCarriageVisual"
	add_child(visual_root)
	var paint := _mat(Color(.14,.20,.16))
	var wood := _mat(Color(.29,.17,.09))
	var dark := _mat(Color(.11,.075,.052))
	var iron := _mat(Color(.20,.20,.19),.35)
	var leather := _mat(Color(.14,.075,.045))
	var brass := _mat(Color(.43,.32,.13),.55)
	var cloth := _mat(Color(.21,.24,.24))
	var skin := _mat(Color(.39,.25,.16))
	var upholstery := _mat(Color(.34,.20,.16))
	var lining := _mat(Color(.37,.33,.26))
	var glass := _mat(Color(.65,.72,.69,.22))
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var roof_cover := _mat(Color(.12,.10,.075))
	roof_cover.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [-1.0,1.0]:
		_wheel(side,1.52,.57,wood,iron)
		_wheel(side,3.65,.76,wood,iron)
	for z in [1.52,3.65]:
		_beam("IronAxle",Vector3(-1.27,.63,z),Vector3(1.27,.63,z),.10,iron)
	for side in [-1.0,1.0]:
		_beam("LongitudinalFrame",Vector3(side*.82,.87,1.25),Vector3(side*.82,1.05,4.03),.12,wood)
		_beam("SpringLeaf",Vector3(side*.85,.77,1.95),Vector3(side*.85,.91,3.50),.045,iron)
	_box("CabinFloor",Vector3(0,1.28,2.75),Vector3(2.14,.15,2.50),dark)
	_box("InteriorFloorMat",Vector3(0,1.363,2.77),Vector3(1.74,.012,1.83),lining)
	_box("RearCabinSeat",Vector3(0,1.58,3.40),Vector3(1.83,.18,.65),leather)
	_box("RearSeatBack",Vector3(0,1.98,3.78),Vector3(1.83,.77,.12),leather)
	_box("ForwardCabinSeat",Vector3(0,1.58,2.10),Vector3(1.83,.18,.60),leather)
	_box("FrontSeatBack",Vector3(0,1.95,1.76),Vector3(1.83,.72,.12),leather)
	for z in [2.10,3.40]:
		for side in [-1.0,1.0]:
			_box("IndividualSeatCushion",Vector3(side*.46,1.69,z),Vector3(.86,.085,.56),upholstery)
		_box("SeatCushionSeam",Vector3(0,1.738,z),Vector3(.012,.004,.55),dark)
	for z in [1.71,3.83]:
		for side in [-1.0,1.0]:
			_box("UpholsteredBackPanel",Vector3(side*.46,2.01,z),Vector3(.84,.56,.035),upholstery)
	_box("InteriorCeilingLiner",Vector3(0,2.87,2.75),Vector3(1.94,.025,2.39),lining)
	for side in [-1.0,1.0]:
		_seat_socket("RearPassengerLeft" if side < 0.0 else "RearPassengerRight",Vector3(side*.48,1.71,3.40))
		_seat_socket("ForwardPassengerLeft" if side < 0.0 else "ForwardPassengerRight",Vector3(side*.48,1.71,2.10),true)
	for side in [-1.0,1.0]:
		_box("LowerDoorPanel",Vector3(side*1.04,1.65,2.77),Vector3(.10,.68,1.30),paint)
		_box("DoorWaistRail",Vector3(side*1.05,2.01,2.77),Vector3(.11,.075,1.32),wood)
		_box("DoorHandle",Vector3(side*1.11,1.88,2.26),Vector3(.035,.035,.15),brass)
		_box("DoorInsetPanel",Vector3(side*1.101,1.62,2.77),Vector3(.015,.44,1.08),dark)
		for z in [2.18,3.36]:
			_box("DoorHinge",Vector3(side*1.115,1.71,z),Vector3(.045,.15,.055),brass)
		_box("InteriorDoorLining",Vector3(side*.975,1.61,2.77),Vector3(.018,.46,1.15),lining)
		_box("InteriorDoorPull",Vector3(side*.951,1.89,2.60),Vector3(.035,.035,.29),leather)
		_box("BoardingStep",Vector3(side*1.27,.84,2.79),Vector3(.38,.07,.57),wood)
		_box("LowerBoardingStep",Vector3(side*1.48,.56,2.79),Vector3(.32,.065,.47),iron)
		_beam("StepBracket",Vector3(side*1.11,1.15,2.55),Vector3(side*1.43,.59,2.55),.04,iron)
		_beam("StepBracket",Vector3(side*1.11,1.15,3.03),Vector3(side*1.43,.59,3.03),.04,iron)
		_box("FrontQuarter",Vector3(side*1.04,2.21,1.65),Vector3(.10,1.43,.42),paint)
		_box("RearQuarter",Vector3(side*1.04,2.21,3.88),Vector3(.10,1.43,.38),paint)
		for z in [2.09,3.43]:
			_box("WindowPost",Vector3(side*1.05,2.36,z),Vector3(.09,.72,.065),wood)
		_box("WindowLintel",Vector3(side*1.05,2.76,2.77),Vector3(.11,.09,2.48),wood)
		_box("WindowSill",Vector3(side*1.05,2.04,2.77),Vector3(.12,.075,2.48),wood)
		_box("SideGlazing",Vector3(side*1.054,2.39,2.75),Vector3(.012,.66,1.32),glass)
		_box("UpperPaintMoulding",Vector3(side*1.115,2.77,2.75),Vector3(.035,.034,2.36),brass)
		_box("LowerPaintMoulding",Vector3(side*1.113,1.30,2.75),Vector3(.036,.035,2.40),brass)
		_box("RoofEdge",Vector3(side*1.10,2.95,2.75),Vector3(.13,.13,2.86),dark)
		_beam("RearSuspensionBrace",Vector3(side*.82,.88,3.55),Vector3(side*.88,1.22,3.76),.055,iron)
		for z in [1.92,3.57]:
			_beam("SuspensionShackle",Vector3(side*.83,.80,z),Vector3(side*.83,1.12,z+.12),.038,iron)
	_box("CabinFrontLower",Vector3(0,1.65,1.49),Vector3(2.08,.68,.10),paint)
	_box("FrontWindowRail",Vector3(0,2.75,1.49),Vector3(2.08,.09,.10),wood)
	_box("FrontWindowPost",Vector3(0,2.39,1.49),Vector3(.09,.71,.10),wood)
	for side in [-1.0,1.0]:
		_box("FrontGlazing",Vector3(side*.53,2.39,1.493),Vector3(.93,.65,.012),glass)
	_box("CabinRear",Vector3(0,2.12,4.01),Vector3(2.08,1.64,.10),paint)
	_roof(roof_cover)
	for z in [1.40,4.10]:
		_box("RoofEndBinding",Vector3(0,3.005,z),Vector3(2.32,.045,.052),brass)
	for x in [-.55,.55]:
		_box("RoofSeam",Vector3(x,3.118,2.76),Vector3(.023,.012,2.40),brass)
	# The coachman's exposed box sits ahead of the enclosed family compartment.
	_box("DriverBoxBase",Vector3(0,1.22,.97),Vector3(1.86,.14,.74),wood)
	_box("DriverCushion",Vector3(0,1.73,.94),Vector3(1.53,.16,.50),leather)
	_box("DriverSeatBack",Vector3(0,2.02,1.25),Vector3(1.54,.56,.12),paint)
	_box("DriverFootboard",Vector3(0,1.13,.30),Vector3(1.77,.08,.51),wood)
	_seat_socket("CoachmanSeat",Vector3(0,1.83,.94))
	for side in [-1.0,1.0]:
		_beam("DriverSeatSupport",Vector3(side*.65,1.25,.98),Vector3(side*.65,1.65,.98),.08,wood)
		_beam("DriverHandRail",Vector3(side*.84,1.26,.46),Vector3(side*.84,1.72,1.18),.055,iron)
	# Temporary seated coachman volume establishes sight line and reach to reins.
	_box("CoachmanCoat",Vector3(0,2.17,.91),Vector3(.51,.72,.30),cloth)
	_box("CoachmanLegLeft",Vector3(-.19,1.43,.52),Vector3(.15,.48,.42),cloth)
	_box("CoachmanLegRight",Vector3(.19,1.43,.52),Vector3(.15,.48,.42),cloth)
	var head := MeshInstance3D.new()
	head.name = "CoachmanHeadBlockout"
	var sphere := SphereMesh.new()
	sphere.radius = .18
	sphere.height = .36
	head.mesh = sphere
	head.position = Vector3(0,2.72,.87)
	head.material_override = skin
	visual_root.add_child(head)
	_box("CoachmanTurbanBlockout",Vector3(0,2.90,.87),Vector3(.38,.13,.34),cloth)
	for side in [-1.0,1.0]:
		_beam("CoachmanArm",Vector3(side*.26,2.39,.85),Vector3(side*.21,1.97,.45),.095,cloth)
		_beam("Rein",Vector3(side*.20,1.97,.43),Vector3(side*.78,1.84,-2.99),.013,leather)
	# Pair harness: central pole, crossbar, breast straps, and traces to the frame.
	_beam("CentralPole",Vector3(0,.97,1.48),Vector3(0,1.14,-2.57),.09,wood)
	_beam("PoleCrossbar",Vector3(-1.03,1.12,-.60),Vector3(1.03,1.12,-.60),.075,wood)
	for side in [-1.0,1.0]:
		var horse := HorseVisual.instantiate() as Node3D
		horse.name = "DraftHorseLeft" if side < 0.0 else "DraftHorseRight"
		horse.position = Vector3(side*.79,.04,-1.88)
		horse.rotation.y = PI
		horse.scale = Vector3.ONE*.47
		visual_root.add_child(horse)
		var anim := horse.find_child("AnimationPlayer",true,false) as AnimationPlayer
		if anim != null:
			horse_animations.append(anim)
			for clip in ["AnimalArmature|Idle","AnimalArmature|Walk"]:
				anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			anim.play("AnimalArmature|Idle")
		_beam("BreastStrap",Vector3(side*.53,1.61,-2.07),Vector3(side*1.05,1.60,-2.07),.053,leather)
		_beam("OutsideTrace",Vector3(side*1.13,1.57,-2.04),Vector3(side*.86,.98,1.26),.023,leather)
		_beam("InsideTrace",Vector3(side*.47,1.55,-2.04),Vector3(side*.57,.98,1.24),.023,leather)
		_beam("PoleStrap",Vector3(side*.54,1.25,-.60),Vector3(side*.53,1.63,-1.83),.025,leather)

func set_forward_motion(speed: float, delta: float) -> void:
	for wheel in wheels:
		var radius := .57 if wheel.name == "FrontWheel" else .76
		wheel.rotation.x += speed*delta/radius
	for anim in horse_animations:
		var clip := "AnimalArmature|Walk" if absf(speed) > .25 else "AnimalArmature|Idle"
		if anim.current_animation != clip: anim.play(clip,.15)
		anim.speed_scale = clampf(absf(speed)/4.2,.65,1.4) if clip.ends_with("Walk") else 1.0
