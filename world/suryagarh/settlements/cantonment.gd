extends RefCounted
## Fictional military district blockout; no claim of final period/art approval.
var b: Node3D
var district: Node3D
var wall_surface: Material
var timber_surface: Material
var roof_surface: Material

func build(builder: Node3D) -> void:
	b = builder
	wall_surface = preload("res://world/suryagarh/settlements/military_detail.gd").surface(Color(.73,.69,.57))
	timber_surface = preload("res://world/suryagarh/settlements/military_detail.gd").surface(Color(.26,.16,.085),2)
	roof_surface = preload("res://world/suryagarh/settlements/military_detail.gd").surface(Color(.43,.24,.15),3)
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
	var british := shell("BritishBarracks",Vector3(-43,0,-46),Vector2(24,10),"")
	british.add_to_group("british_barracks")
	for x in [-9,-6,-3,3,6,9]:
		bed(british,Vector3(x,0.24,-1.7),false)
		b.piece(british,"Footlocker",Vector3(x,0.5,0),Vector3(1,0.5,0.65),b.wood)
	var officers := shell("OfficersQuarters",Vector3(43,0,-46),Vector2(24,10),"")
	officers.add_to_group("officers_quarters")
	for x in [-8.0,8.0]:
		bed(officers,Vector3(x,0.24,-2),true)
		b.piece(officers,"OfficerDesk",Vector3(x,1,-0.1),Vector3(2,0.12,0.8),b.wood)
		for leg in [-0.8,0.8]:
			b.piece(officers,"DeskLeg",Vector3(x+leg,0.6,-0.1),Vector3(0.12,0.72,0.7),b.wood)
		b.piece(officers,"ClothesChest",Vector3(x,0.6,2.6),Vector3(1.8,0.72,0.7),b.wood)
	var stable := shell("CavalryStables",Vector3(0,0,-49),Vector2(32,10),"CAVALRY STABLES")
	for i in 8:
		var x := -16.0+i*4.0
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
	stock(grain,"barrel",[0.0])
	for x in [-6.0,-2.0,2.0,6.0]:
		var sack: Node3D = load("res://objects/household/grain_sack.tscn").instantiate()
		grain.add_child(sack)
		sack.position = Vector3(x,0.24,3.3)
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
	var church := shell("CantonmentChurch",Vector3(0,0,-33),Vector2(12,14),"")
	church.add_to_group("cantonment_church")
	var church_fittings := Node3D.new()
	church_fittings.name = "ChurchFittings"
	church.add_child(church_fittings)
	church_fittings.scale.z = .75
	preload("res://world/suryagarh/settlements/cantonment_service_detail.gd").church(b,church_fittings)
	preload("res://world/suryagarh/settlements/cantonment_service_detail.gd").cemetery(b,district)
	preload("res://world/suryagarh/settlements/cantonment_service_detail.gd").furnish(b,district)
	for node in district.get_children():
		if node is Node3D and node.get_child_count() > 0: b.merge_visuals(node)
	district.set_meta("parade_bounds",Rect2(Vector2(-26,-24),Vector2(52,48)))
	district.set_meta("location_numbers",[1,3,20,21,22,23])

func shell(label: String, center: Vector3, size: Vector2, caption: String) -> Node3D:
	var military: bool = district.name == "BritishCantonment"
	var wall_mat: Material = wall_surface if military else b.plaster
	var roof_mat: Material = roof_surface if military else b.tile
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
	elif label in ["CavalryStables","GrainFodderWarehouse","MilitaryHospital"]:
		rear_windows(room,w,d,wall_mat)
	else:
		b.piece(room,"RearWall",Vector3(0,1.9,-d/2),Vector3(w,3.35,0.4),wall_mat)
	for side in [-1,1]:
		if military:
			b.piece(room,"SideEaveClosure",Vector3(side*w/2,3.6375,0),Vector3(.4,.125,d),wall_mat)
			for z in [-1.0,1.0]:
				b.piece(room,"SideWindowPier",Vector3(side*w/2,1.9,z*(d/4+.55)),Vector3(.4,3.35,d/2-1.1),wall_mat)
			b.piece(room,"WindowSillWall",Vector3(side*w/2,.8,0),Vector3(.4,1.15,2.2),wall_mat)
			b.piece(room,"WindowHeaderWall",Vector3(side*w/2,3.12,0),Vector3(.4,.9,2.2),wall_mat)
			# Barred collision prevents climbing through decorative window openings.
			for z in [-.8,-.4,0.0,.4,.8]:
				b.piece(room,"WindowBar",Vector3(side*w/2,2.0,z),Vector3(.06,1.35,.045),b.iron)
		else:
			b.piece(room,"SideWall",Vector3(side*w/2,1.9,0),Vector3(.4,3.35,d),b.plaster)
		b.piece(room,"DoorPier",Vector3(side*(w/4+0.75),1.9,d/2),Vector3(w/2-1.5,3.35,0.4),wall_mat)
		b.piece(room,"Roof",Vector3(side*w/4,3.7+w*.03 if military else 3.85,0),Vector3(w/2+0.55,0.16,d+1.4),roof_mat).rotation.z = side*-0.12
	b.piece(room,"Lintel",Vector3(0,3.08,d/2),Vector3(3,1.0,0.4),b.plaster)
	b.piece(room,"Ridge",Vector3(0,3.7+w*.06 if military else 3.85+w*.03,0),Vector3(0.25,0.2,d+1.4),b.tile)
	b.piece(room,"EntryStep",Vector3(0,0.06,d/2+0.7),Vector3(3.2,0.12,0.8),b.stone)
	var marker := Marker3D.new()
	marker.name = "Entrance"
	marker.position = Vector3(0,0.25,d/2+1.5)
	room.add_child(marker)
	if military:
		for z in [-d/2,d/2]:
			b.piece(room,"EaveClosure",Vector3(0,3.64,z),Vector3(w,.13,.4),wall_mat)
			var gable := MeshInstance3D.new()
			gable.name = "ClosedPlasterGable"
			gable.mesh = preload("res://world/suryagarh/settlements/bhairavpur_house_detail.gd").new()._gable_mesh(w,w*.06,.4)
			gable.material_override = wall_mat
			gable.position = Vector3(0,3.7,z)
			room.add_child(gable)
	if military: preload("res://world/suryagarh/settlements/military_detail.gd").room(b,room,w,d,label not in ["GrainFodderWarehouse","CavalryStables","MilitaryHospital","CantonmentChurch"])
	if label in ["GrainFodderWarehouse","CavalryStables","MilitaryHospital","CantonmentChurch"]:
		preload("res://world/suryagarh/settlements/cantonment_service_detail.gd").roof(b,room,w,d)
	room.add_to_group("cantonment_buildings")
	return room

func bed(parent: Node3D, p: Vector3, white: bool) -> void:
	b.piece(parent,"CotFrame",p+Vector3(0,0.45,0),Vector3(1.3,0.12,2.1),b.wood)
	preload("res://world/suryagarh/settlements/military_room_finish.gd").bed(parent,p,white)
	for x in [-0.5,0.5]:
		for z in [-0.85,0.85]: b.piece(parent,"CotLeg",p+Vector3(x,0.21,z),Vector3(0.09,0.42,0.09),b.wood)

func stock(parent: Node3D, slug: String, positions: Array) -> void:
	for x in positions:
		var prop: Node3D = load("res://objects/household/storage/"+slug+".tscn").instantiate()
		parent.add_child(prop)
		prop.position = Vector3(x,0.24,-2.5)

func rear_windows(room: Node3D, w: float, d: float, mat: Material) -> void:
	var count := 4 if w >= 24 else 3
	var opening := 1.6
	var spacing := w / count
	b.piece(room,"RearSillWall",Vector3(0,.85,-d/2),Vector3(w,1.25,.4),mat)
	b.piece(room,"RearWindowHeader",Vector3(0,3.125,-d/2),Vector3(w,.9,.4),mat)
	var edge := -w/2
	for i in count:
		var x := -w/2+spacing*(i+.5)
		var left := x-opening/2
		b.piece(room,"RearWindowPier",Vector3((edge+left)/2,2.075,-d/2),Vector3(left-edge,1.2,.4),mat)
		b.piece(room,"RearWindowSill",Vector3(x,1.475,-d/2),Vector3(opening+.15,.10,.55),b.stone)
		for dx in [-.85,.85]: b.piece(room,"RearWindowJamb",Vector3(x+dx,2.075,-d/2),Vector3(.1,1.2,.5),timber_surface)
		for dx in [-.6,-.3,0,.3,.6]: b.piece(room,"RearWindowBar",Vector3(x+dx,2.075,-d/2),Vector3(.035,1.2,.035),b.iron)
		for shutter in [-1,1]: b.piece(room,"RearOpenShutter",Vector3(x+shutter*1.2,2.075,-d/2-.3),Vector3(.7,1.15,.09),timber_surface,false)
		edge = x+opening/2
	b.piece(room,"RearEndPier",Vector3((edge+w/2)/2,2.075,-d/2),Vector3(w/2-edge,1.2,.4),mat)
