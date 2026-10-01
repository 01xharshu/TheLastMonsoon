extends RefCounted
## Fictional military district blockout; no claim of final period/art approval.
var b: Node3D
var district: Node3D

func build(builder: Node3D) -> void:
	b = builder
	district = Node3D.new()
	district.name = "BritishCantonment"
	district.position = Vector3(500,8.5,470)
	b.add_child(district)
	district.add_to_group("british_cantonment")
	district.set_meta("status","Integrated blockout; staffing/art/gameplay incomplete")
	b.piece(district,"ParadeGround",Vector3(0,0.035,0),Vector3(52,0.07,48),b.ochre)
	for side in [-1,1]:
		for z in [-16,16]:
			var barrack := shell("SepoyLines_%d_%d" % [side,z],Vector3(side*43,0,z),Vector2(24,8),"SEPOY LINES")
			barrack.rotation.y = -side*PI/2
			for x in [-9,-6,-3,3,6,9]:
				bed(barrack,Vector3(x,0.24,-1.7),false)
				b.piece(barrack,"Footlocker",Vector3(x,0.5,0),Vector3(1.0,0.5,0.65),b.wood)
			barrack.add_to_group("sepoy_barracks")
	var stable := shell("CavalryStables",Vector3(0,0,-47),Vector2(32,10),"CAVALRY STABLES")
	for i in 8:
		var x := -14.0+i*4.0
		b.piece(stable,"StallDivider",Vector3(x,1.15,-1.5),Vector3(0.12,1.8,4.4),b.wood)
		b.piece(stable,"Manger",Vector3(x+1.8,0.8,-3.5),Vector3(2.8,0.6,0.8),b.wood)
		b.piece(stable,"TetherRail",Vector3(x+1.8,1.35,0.7),Vector3(2.8,0.12,0.12),b.wood)
	stable.add_to_group("cavalry_stables")
	var hospital := shell("MilitaryHospital",Vector3(-43,0,45),Vector2(24,10),"MILITARY HOSPITAL")
	for x in [-9,-3,3,9]:
		for z in [-2,2]: bed(hospital,Vector3(x,0.24,z),true)
	var medicine = load("res://world/suryagarh/settlements/medical_supply.gd").new()
	medicine.name = "HospitalBandage"
	medicine.supply_id = "cantonment/hospital/bandage"
	medicine.position = Vector3(0,1.03,-3)
	hospital.add_child(medicine)
	b.piece(hospital,"DressingTable",Vector3(0,0.98,-3),Vector3(1.6,0.1,0.8),b.wood)
	for x in [-0.65,0.65]: b.piece(hospital,"TableLeg",Vector3(x,0.60,-3),Vector3(0.1,0.7,0.6),b.wood)
	var depot := shell("MilitarySupplyDepot",Vector3(-10,0,45),Vector2(22,10),"COMMISSARIAT STORES")
	stock(depot,"crate",[-7.0,-3.0,3.0,7.0])
	var grain := shell("GrainFodderWarehouse",Vector3(15,0,45),Vector2(18,10),"GRAIN AND FODDER")
	stock(grain,"barrel",[-5.0,0.0,5.0])
	for x in [-6.0,-2.0,2.0,6.0]:
		var sack: Node3D = load("res://objects/household/grain_sack.tscn").instantiate()
		grain.add_child(sack)
		sack.position = Vector3(x,0.24,1.5)
	var magazine := shell("GunpowderMagazine",Vector3(48,0,45),Vector2(14,10),"POWDER MAGAZINE")
	stock(magazine,"barrel",[-4.0,0.0,4.0])
	for side in [-1,1]:
		b.piece(magazine,"MagazineButtress",Vector3(side*7.35,1.7,0),Vector3(0.8,3.4,1.3),b.brick)
		b.piece(magazine,"BlastWall",Vector3(side*10,1.35,0),Vector3(0.55,2.7,15),b.brick)
		b.piece(magazine,"BlastReturn",Vector3(side*5.5,1.35,-7.5),Vector3(9.5,2.7,0.55),b.brick)
	for x in [-4.0,0.0,4.0]:
		for offset in [-0.3,0.0,0.3]:
			b.piece(magazine,"VentBar",Vector3(x+offset,3.1,-5.22),Vector3(0.035,0.4,0.035),b.iron,false)
	# Delineated drill yard and clear east-side approach; no closed checkpoint gameplay.
	for z in [-59.0,59.0]:
		for x in range(-68,69,8):
			if z < 0 and x > 48: continue
			b.piece(district,"BoundaryPost",Vector3(x,0.6,z),Vector3(0.16,1.2,0.16),b.wood)
	for node in district.get_children():
		if node is Node3D and node.get_child_count() > 0: b.merge_visuals(node)
	district.set_meta("parade_bounds",Rect2(Vector2(-26,-24),Vector2(52,48)))
	district.set_meta("location_numbers",[1,3,20,21,22,23])

func shell(label: String, center: Vector3, size: Vector2, caption: String) -> Node3D:
	var room := Node3D.new()
	room.name = label
	district.add_child(room)
	room.position = center
	var w := size.x
	var d := size.y
	b.piece(room,"Floor",Vector3(0,0.12,0),Vector3(w+0.6,0.24,d+0.6),b.stone)
	if label == "GunpowderMagazine":
		b.piece(room,"VentSillWall",Vector3(0,1.5625,-d/2),Vector3(w,2.675,0.4),b.plaster)
		b.piece(room,"VentHeader",Vector3(0,3.4375,-d/2),Vector3(w,0.275,0.4),b.plaster)
		for span in [Vector2(-7,-4.4),Vector2(-3.6,-0.4),Vector2(0.4,3.6),Vector2(4.4,7)]:
			b.piece(room,"VentPier",Vector3((span.x+span.y)/2,3.1,-d/2),Vector3(span.y-span.x,0.4,0.4),b.plaster)
	else:
		b.piece(room,"RearWall",Vector3(0,1.9,-d/2),Vector3(w,3.35,0.4),b.plaster)
	for side in [-1,1]:
		b.piece(room,"SideWall",Vector3(side*w/2,1.9,0),Vector3(0.4,3.35,d),b.plaster)
		b.piece(room,"DoorPier",Vector3(side*(w/4+0.75),1.9,d/2),Vector3(w/2-1.5,3.35,0.4),b.plaster)
		b.piece(room,"Roof",Vector3(side*w/4,3.85,0),Vector3(w/2+0.55,0.16,d+1.4),b.tile).rotation.z = side*-0.12
	b.piece(room,"Lintel",Vector3(0,3.08,d/2),Vector3(3,1.0,0.4),b.plaster)
	b.piece(room,"Ridge",Vector3(0,3.85+w*0.03,0),Vector3(0.25,0.2,d+1.4),b.tile)
	b.piece(room,"EntryStep",Vector3(0,0.06,d/2+0.7),Vector3(3.2,0.12,0.8),b.stone)
	var marker := Marker3D.new()
	marker.name = "Entrance"
	marker.position = Vector3(0,0.25,d/2+1.5)
	room.add_child(marker)
	room.add_to_group("cantonment_buildings")
	return room

func bed(parent: Node3D, p: Vector3, white: bool) -> void:
	b.piece(parent,"CotFrame",p+Vector3(0,0.45,0),Vector3(1.3,0.12,2.1),b.wood)
	b.piece(parent,"Bedding",p+Vector3(0,0.54,0),Vector3(1.2,0.08,2),b.plaster if white else b.ochre,false)
	for x in [-0.5,0.5]:
		for z in [-0.85,0.85]: b.piece(parent,"CotLeg",p+Vector3(x,0.21,z),Vector3(0.09,0.42,0.09),b.wood)

func stock(parent: Node3D, slug: String, positions: Array) -> void:
	for x in positions:
		var prop: Node3D = load("res://objects/household/storage/"+slug+".tscn").instantiate()
		parent.add_child(prop)
		prop.position = Vector3(x,0.24,-2.5)
