extends "res://vehicles/family_carriage_candidate.gd"
## The merchant's open wagon uses the existing household travel and seating system.
var driver: Node3D
var cargo_parts: Array[Node3D] = []

func _build() -> void:
	visual_root = Node3D.new()
	visual_root.name = "MarketCartVisual"
	add_child(visual_root)

	var timber := _mat(Color(.29,.17,.09))
	var edge := _mat(Color(.18,.105,.055))
	var red := _mat(Color(.34,.16,.10))
	var iron := _mat(Color(.16,.15,.13),.35)
	var leather := _mat(Color(.15,.08,.045))
	var cotton := _mat(Color(.53,.42,.25))
	var indigo := _mat(Color(.18,.24,.27))
	var rope := _mat(Color(.44,.34,.19))

	for side in [-1.0,1.0]:
		_wheel(side,1.52,.57,timber,iron)
		_wheel(side,3.65,.76,timber,iron)
		_box("FrameRail",Vector3(side*.79,1.09,2.60),Vector3(.14,.20,3.18),edge)
		_box("BedSide",Vector3(side*1.03,1.54,3.17),Vector3(.075,.34,1.97),red)
		_box("SideCap",Vector3(side*1.03,1.72,3.17),Vector3(.10,.06,1.98),edge)
		for z in [2.24,3.10,4.05]:
			_box("SideStake",Vector3(side*1.081,1.48,z),Vector3(.046,.43,.085),edge)
		_box("BoardingStep",Vector3(side*1.40,.60,2.77),Vector3(.40,.09,.52),timber)
		_beam("StepHanger",Vector3(side*.90,1.23,2.69),Vector3(side*1.36,.62,2.69),.05,iron)
		_beam("StepHanger",Vector3(side*.90,1.23,2.85),Vector3(side*1.36,.62,2.85),.05,iron)
		_beam("Spring",Vector3(side*.84,.80,1.32),Vector3(side*.84,1.04,1.85),.054,iron)
		_beam("Spring",Vector3(side*.84,.91,3.38),Vector3(side*.84,1.05,3.96),.054,iron)
	for axle in [Vector2(.57,1.52),Vector2(.76,3.65)]:
		_beam("Axle",Vector3(-1.22,axle.x,axle.y),Vector3(1.22,axle.x,axle.y),.10,iron)

	for plank in 8:
		_box("DeckPlank",Vector3((plank-3.5)*.25,1.31,2.60),Vector3(.247,.12,3.04),timber if plank%2==0 else red)
	_box("Tailboard",Vector3(0,1.54,4.14),Vector3(2.04,.34,.075),red)
	for x in [-.72,.72]:
		_box("TailboardIron",Vector3(x,1.47,4.183),Vector3(.052,.31,.021),iron)

	_box("FrontBench",Vector3(0,1.69,1.40),Vector3(1.81,.14,.55),edge)
	_box("FrontCushion",Vector3(0,1.79,1.40),Vector3(1.77,.07,.52),cotton)
	_box("FrontBackrest",Vector3(0,2.02,1.75),Vector3(1.86,.40,.09),red)
	_box("BackrestCap",Vector3(0,2.24,1.75),Vector3(1.90,.055,.13),edge)
	_box("DriverFootboard",Vector3(0,1.19,.87),Vector3(1.73,.10,.48),timber)
	for x in [-.68,.68]:
		_box("BenchSupport",Vector3(x,1.49,1.40),Vector3(.14,.30,.43),edge)
	_seat_socket("CoachmanSeat",Vector3(0,1.85,1.40))
	_box("PassengerPerch",Vector3(-.48,1.58,3.40),Vector3(.86,.18,.59),timber)
	_box("PassengerBackrest",Vector3(-.48,1.92,3.73),Vector3(.86,.49,.085),red)
	_seat_socket("RearPassengerLeft",Vector3(-.48,1.71,3.40))

	# Leave a clear aisle from the side step to the passenger perch.
	_box("ClothChest",Vector3(.52,1.59,3.43),Vector3(.68,.44,.74),edge)
	_box("ChestLid",Vector3(.52,1.83,3.43),Vector3(.71,.06,.76),timber)
	for z in [3.15,3.71]:
		_box("ChestBand",Vector3(.52,1.866,z),Vector3(.70,.013,.055),iron)
	for i in 2:
		var roll := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = .125
		mesh.bottom_radius = .125
		mesh.height = .67
		roll.name = "BoundClothRoll"
		roll.mesh = mesh
		roll.material_override = cotton if i==0 else indigo
		roll.position = Vector3(.52,2.00,3.27+i*.27)
		roll.rotation.z = PI*.5
		visual_root.add_child(roll)
		cargo_parts.append(roll)
	for x in [.28,.76]:
		var before := visual_root.get_child_count()
		_beam("CargoLashing",Vector3(x,1.63,3.04),Vector3(x,2.125,3.22),.018,rope)
		_beam("CargoLashing",Vector3(x,2.125,3.22),Vector3(x,2.125,3.58),.018,rope)
		_beam("CargoLashing",Vector3(x,2.125,3.58),Vector3(x,1.73,4.10),.018,rope)
		for index in range(before,visual_root.get_child_count()):
			cargo_parts.append(visual_root.get_child(index))

	var horse := HorseVisual.instantiate() as Node3D
	horse.name = "DraftHorseVisual"
	horse.position = Vector3(0,.005,-1.48)
	horse.rotation.y = PI
	horse.scale = Vector3.ONE*.47
	visual_root.add_child(horse)
	var animation := horse.find_child("AnimationPlayer",true,false) as AnimationPlayer
	horse_animations.append(animation)
	for clip in ["AnimalArmature|Idle","AnimalArmature|Walk"]:
		animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	animation.play("AnimalArmature|Idle")

	for side in [-1.0,1.0]:
		_beam("DraftShaft",Vector3(side*.77,.98,1.73),Vector3(side*.51,1.19,-1.18),.073,edge)
		_beam("BreastCollar",Vector3(side*.37,1.53,-1.73),Vector3(side*.24,1.82,-2.16),.055,leather)
		_beam("OutsideTrace",Vector3(side*.37,1.53,-1.73),Vector3(side*.63,1.05,1.30),.023,leather)
		_box("ShaftLoop",Vector3(side*.54,1.18,-.89),Vector3(.11,.08,.23),leather)
		_beam("Rein",Vector3(side*.22,1.86,-2.63),rein_grip_local("l" if side<0 else "r"),.013,leather)
	_beam("Swingletree",Vector3(-.66,1.05,1.30),Vector3(.66,1.05,1.30),.066,edge)
	_beam("HarnessSaddle",Vector3(-.45,1.53,-1.13),Vector3(.45,1.53,-1.13),.085,leather)
	for side in [-1.0,1.0]:
		_beam("HarnessGirth",Vector3(side*.45,1.53,-1.13),Vector3(side*.47,1.20,-.93),.06,leather)

func rein_grip_local(side: String) -> Vector3:
	return Vector3(-.20 if side=="l" else .20,2.00,1.03)

func _build_boarding_doors() -> void:
	pass

func add_cart_clearance(rider_controller: Node) -> void:
	rider_controller._add_clearance(Vector3(0,1.58,2.62),Vector3(2.15,1.26,3.13))
	rider_controller._add_clearance(Vector3(0,1.16,-1.48),Vector3(.85,1.25,2.1))
	rider_controller.clearance_shapes.back().set_meta("draft_clearance",true)
	for side in [-1.0,1.0]:
		rider_controller._add_clearance(Vector3(side*1.40,.60,2.77),Vector3(.40,.09,.52))
	rider_controller._add_clearance(Vector3(0,.83,2.62),Vector3(1.78,.49,3.13))

func set_cargo_loaded(loaded: bool) -> void:
	for part in cargo_parts:
		part.visible = loaded
	set_meta("cargo_loaded",loaded)
