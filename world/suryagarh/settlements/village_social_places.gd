extends RefCounted
## Original fictional courtyard estate , informed by period research.
var village
var builder

func build(v) -> void:
	village = v
	builder = v.settlement
	_estate()

func piece(parent: Node3D,label: String,p: Vector3,size: Vector3,material: Material,solid := true) -> Node3D:
	return builder.piece(parent,label,p,size,material,solid)

func _estate() -> void:
	var estate: Node3D = village._root("BhairavpurLandownerEstate",Vector2(-321,344))
	estate.add_to_group("village_estate")
	var lime: Material = builder.material(Color(.78,.72,.58))
	var trim: Material = builder.material(Color(.52,.32,.21))
	# Three wings around an open 14 x 18 m courtyard. Ground arcade is traversable.
	piece(estate,"Courtyard",Vector3(0,.06,0),Vector3(34,.12,32),village.earth,false)
	for side in [-1.0,1.0]:
		piece(estate,"WingFloor",Vector3(side*13,.12,0),Vector3(8,.24,28),builder.stone)
		piece(estate,"OuterWall",Vector3(side*17,3.5,0),Vector3(.45,7,28),lime)
		piece(estate,"RearWingEnd",Vector3(side*13,3.5,14),Vector3(8,7,.45),lime)
		piece(estate,"FrontWingEnd",Vector3(side*13,3.5,-14),Vector3(8,7,.45),lime)
		piece(estate,"WingUpperFloor",Vector3(side*13,3.65,0),Vector3(8,.22,28),builder.wood)
		piece(estate,"WingRoof",Vector3(side*13,7.08,0),Vector3(8.6,.22,28.6),lime)
		piece(estate,"WingParapet",Vector3(side*17,7.45,0),Vector3(.32,.62,28),lime)
		for z in [-11.0,-6.5,-2.0,2.5,7.0,11.5]:
			piece(estate,"ArcadeColumn",Vector3(side*9,1.95,z),Vector3(.35,3.9,.35),trim)
			piece(estate,"ColumnCapital",Vector3(side*9,3.45,z),Vector3(.65,.22,.65),lime,false)
			piece(estate,"UpperWindowPier",Vector3(side*9,5.38,z),Vector3(.38,3.4,1.6),lime)
		piece(estate,"ArcadeBeam",Vector3(side*9,3.5,0),Vector3(.65,.3,28),trim)
		piece(estate,"UpperSill",Vector3(side*9,4.24,0),Vector3(.38,1.0,28),lime)
		piece(estate,"UpperLintel",Vector3(side*9,6.8,0),Vector3(.38,.55,28),lime)
	piece(estate,"RearHall",Vector3(0,3.5,13.8),Vector3(18,7,.45),lime)
	piece(estate,"RearShade",Vector3(0,3.45,10.7),Vector3(18,.22,6),builder.wood)
	for x in [-7.0,-3.5,3.5,7.0]:
		piece(estate,"HallColumn",Vector3(x,1.72,8),Vector3(.34,3.44,.34),trim)
	# Compound gate keeps a 4 m passage; brick apron meets the earth approach.
	for side in [-1.0,1.0]:
		piece(estate,"GateWall",Vector3(side*5.5,1.6,-14),Vector3(7,3.2,.5),lime)
		piece(estate,"GatePier",Vector3(side*2.15,2,-14),Vector3(.5,4,.65),trim)
		piece(estate,"OpenGateLeaf",Vector3(side*2.4,1.45,-12.8),Vector3(.15,2.9,2.2),builder.wood)
	piece(estate,"GateLintel",Vector3(0,3.9,-14),Vector3(4.8,.4,.8),trim)
	piece(estate,"GateApron",Vector3(0,.035,-16.0),Vector3(4.4,.07,4),builder.stone,false)
	# Rent office and stored grain signal estate function without asserting slavery.
	piece(estate,"RentDesk",Vector3(-12,.95,-7),Vector3(2.6,.14,1.1),builder.wood)
	for x in [-13.0,-11.0]: piece(estate,"DeskLeg",Vector3(x,.47,-7),Vector3(.13,.94,.9),builder.wood)
	piece(estate,"RentLedger",Vector3(-12,1.08,-7),Vector3(.4,.08,.3),trim,false)
	for i in 6:
		piece(estate,"GrainBin",Vector3(12,1.0,-9+i*3.3),Vector3(2,1.5,2),village.fabric[0])
	for i in 4:
		piece(estate,"CourtyardWaitingMat",Vector3(-5+i*3.3,.025,-7),Vector3(1,.025,1.5),village.fabric[2],false)
	# Worked estate plots differ from household vegetable beds in scale.
	for i in 6:
		var field: Node3D = village._root("EstateField%d"%i,Vector2(-288+(i%2)*11,334+(i/2)*10))
		piece(field,"CultivatedBed",Vector3(0,.035,0),Vector3(9,.07,8),village.earth,false)
		for row in 6:
			piece(field,"CropRow",Vector3(0,.23,-3+row*1.1),Vector3(8,.38,.25),village.crop_material,false)

