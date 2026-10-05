extends RefCounted
## Functional room divisions, leaving the entrance and service aisles clear.
static func install(b, district: Node3D) -> void:
	var ward: Node3D = district.get_node("MilitaryHospital")
	ward.set_meta("rooms",["main ward","isolation wing","convalescent wing","dressing room"])
	for x in [-6.0,6.0]:
		for z in [-3.0,3.0]: b.piece(ward,"WardDivision",Vector3(x,1.75,z),Vector3(.16,3,4),b.plaster)
		b.piece(ward,"WardDoorHeader",Vector3(x,2.85,0),Vector3(.16,.8,2),b.plaster)
	for x in [-1.35,1.35]: b.piece(ward,"DressingRoomSide",Vector3(x,1.75,-3.1),Vector3(.14,3,3.8),b.plaster)
	for x in [-1.15,1.15]: b.piece(ward,"DressingRoomFront",Vector3(x,1.75,-1.2),Vector3(.4,3,.14),b.plaster)
	b.piece(ward,"DressingDoorHeader",Vector3(0,2.85,-1.2),Vector3(1.9,.8,.14),b.plaster)
	var grain: Node3D = district.get_node("GrainFodderWarehouse")
	grain.set_meta("rooms",["grain store","fodder bay","issue office"])
	for x in [-5.25,5.25]: b.piece(grain,"GrainFodderDivision",Vector3(x,1.65,-.2),Vector3(7.5,2.8,.14),b.wood)
	b.piece(grain,"IssueOfficeSide",Vector3(-4,1.65,3.65),Vector3(.14,2.8,2.7),b.wood)
	for x in [-7.4,-4.6]: b.piece(grain,"IssueOfficeFront",Vector3(x,1.65,2.3),Vector3(1.2,2.8,.14),b.wood)
	table(b,grain,Vector3(-6,1.0,3.5),Vector2(2,.7))
	for prop in grain.get_children():
		if prop is Node3D and prop.scene_file_path.ends_with("grain_sack.tscn") and prop.position.x == -6 and prop.position.z > 3:
			prop.position = Vector3(-6,.52,-1.6)
	var stable: Node3D = district.get_node("CavalryStables")
	stable.set_meta("rooms",["eight horse stalls","working aisle","tack and grooming room"])
	b.piece(stable,"TackRoomSide",Vector3(-10,1.65,3.5),Vector3(.14,2.8,3),b.wood)
	b.piece(stable,"TackRoomFront",Vector3(-14.7,1.65,2),Vector3(2.6,2.8,.14),b.wood)
	b.piece(stable,"TackRoomFront",Vector3(-10.8,1.65,2),Vector3(1.6,2.8,.14),b.wood)
	table(b,stable,Vector3(-12.5,.95,3),Vector2(1.8,.6))
	var church: Node3D = district.get_node("CantonmentChurch")
	church.set_meta("rooms",["nave","raised chancel","vestry"])
	b.piece(church,"VestrySide",Vector3(-2,1.75,-5.2),Vector3(.14,3,3.2),b.plaster)
	for x in [-5.1,-2.6]: b.piece(church,"VestryFront",Vector3(x,1.75,-3.6),Vector3(1.2,3,.14),b.plaster)
	table(b,church,Vector3(-3.4,1.2,-6.0),Vector2(1.0,.3))
	var yard: Node3D = district.get_node("MilitaryCemetery")
	yard.set_meta("rooms",["burial plots","gate and central path","groundskeeper station"])
	table(b,yard,Vector3(-4.5,.9,8),Vector2(1.4,.6))

static func table(b, parent: Node3D, p: Vector3, size: Vector2) -> void:
	b.piece(parent,"WorkSurface",p,Vector3(size.x,.10,size.y),b.wood)
	var ground := .44 if parent.name == "CantonmentChurch" else (.24 if parent.name != "MilitaryCemetery" else 0.0)
	var height: float = p.y-.05-ground
	for x in [-size.x*.4,size.x*.4]:
		b.piece(parent,"WorkSurfaceLeg",Vector3(p.x+x,ground+height*.5,p.z),Vector3(.10,height,size.y*.8),b.wood)
	var folio: Node3D = load("res://objects/household/supplies/record_folio.tscn").instantiate()
	parent.add_child(folio)
	folio.position = p+Vector3(0,.05,0)
