extends Node3D
## Original modular architecture for fictional 1857 Suryagarh. Shared materials and merged visible geometry.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const Gate = preload("res://world/suryagarh/settlements/compound_gate.gd")
const Pickup = preload("res://world/suryagarh/settlements/weapon_pickup.gd")
var layout := Layout.new()
var plaster: Material
var ochre: Material
var brick: Material
var wood: Material
var tile: Material
var stone: Material
var iron: Material

func material(color: Color, masonry := false) -> Material:
	var m := ShaderMaterial.new()
	m.shader = preload("res://world/suryagarh/settlements/period_surface.gdshader")
	m.set_shader_parameter("tint",color)
	m.set_shader_parameter("courses",1.0 if masonry else 0.0)
	return m

func _ready() -> void:
	plaster = material(Color(.76,.70,.56))
	ochre = material(Color(.55,.40,.24))
	brick = material(Color(.44,.24,.16),true)
	wood = material(Color(.23,.13,.07))
	tile = material(Color(.43,.19,.105),true)
	stone = material(Color(.42,.40,.33),true)
	iron = material(Color(.13,.14,.13))
	for i in 8:
		var x: float = -343+(i%4)*22
		var z: float = 214+(i/4)*35
		var house := make_building("BhairavpurHouse%d"%i,Vector2(x,z),Vector2(9.5,7.2),false)
		if i<4: house.rotation.y = PI
	add_civic("TownHall",Layout.PLOTS["TownHall"].center,false)
	add_civic("DistrictPolice",Layout.PLOTS["DistrictPolice"].center,true)
	var compound_center: Vector2 = Layout.PLOTS["CompanyCompound"].center
	make_building("DistrictJail",compound_center+Vector2(2,13),Vector2(21,18),true,true,true)
	make_building("CompanyArmoury",compound_center+Vector2(31,8),Vector2(17,13),true,true)
	compound()
	landing()
	var residence: Node3D = load("res://world/suryagarh/settlements/government_house.gd").new()
	add_child(residence)

func piece(parent: Node3D, label: String, center: Vector3, size: Vector3, mat: Material, solid := true) -> Node3D:
	var node := Node3D.new()
	node.name = label
	parent.add_child(node)
	node.position = center
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	node.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		node.add_child(body)
	return node

func column(parent: Node3D, center: Vector3, height: float) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = .22
	mesh.bottom_radius = .29
	mesh.height = height
	mesh.radial_segments = 12
	node.mesh = mesh
	node.position = center
	node.material_override = plaster
	parent.add_child(node)
	piece(parent,"ColumnBase",center-Vector3.UP*(height*.5-.12),Vector3(.75,.24,.75),stone)
	piece(parent,"ColumnCapital",center+Vector3.UP*(height*.5-.1),Vector3(.7,.2,.7),plaster,false)
	var body := StaticBody3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = .29
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.position = center
	body.add_child(collision)
	parent.add_child(body)

func make_building(label: String, p: Vector2, extent: Vector2, civic: bool, north := false, jail := false) -> Node3D:
	var b := Node3D.new()
	b.name = label
	add_child(b)
	b.position = Vector3(p.x,layout.height(p.x,p.y),p.y)
	if north: b.rotation.y = PI
	var w: float = extent.x
	var d: float = extent.y
	var h: float = 4.6 if civic else 2.8
	var m: Material = plaster if civic else ochre
	piece(b,"Plinth",Vector3(0,.12,0),Vector3(w+1,.24,d+1),stone)
	# Actual doorway and window openings; there is no collision filling the room.
	for side in [-1.0,1.0]:
		piece(b,"DoorPier",Vector3(side*(w*.25+.65),h*.5+.24,d*.5),Vector3(w*.5-1.3,h,.38),m)
	piece(b,"DoorLintel",Vector3(0,(h+2.35)*.5+.24,d*.5),Vector3(2.6,h-2.35,.38),m)
	piece(b,"BackWall",Vector3(0,h*.5+.24,-d*.5),Vector3(w,h,.38),m)
	for side in [-1.0,1.0]:
		piece(b,"WindowSillWall",Vector3(side*w*.5,.79,0),Vector3(.38,1.1,d),m)
		piece(b,"WindowHeadWall",Vector3(side*w*.5,(h+2.25)*.5+.24,0),Vector3(.38,h-2.25,d),m)
		for end in [-1.0,1.0]:
			piece(b,"WindowPier",Vector3(side*w*.5,1.915,end*(d*.25+.55)),Vector3(.38,1.15,d*.5-1.1),m)
		for edge in [-1.0,1.0]:
			piece(b,"Shutter",Vector3(side*(w*.5+.05),1.915,edge*1.0),Vector3(.14,1.15,.34),wood,false)
		piece(b,"RoofSlope",Vector3(side*w*.25,h+.65,0),Vector3(w*.55,.15,d+1.6),tile).rotation.z = side*-.25
	piece(b,"RoofRidge",Vector3(0,h+1.32,0),Vector3(.25,.26,d+1.7),tile,false)
	for step in 3:
		piece(b,"ThresholdStep",Vector3(0,.04+step*.07,d*.5+.9-step*.24),Vector3(3,.08,.55),stone)
	if civic:
		piece(b,"Veranda",Vector3(0,.12,d*.5+1.5),Vector3(w+1,.24,3.4),stone)
		piece(b,"PorticoEntablature",Vector3(0,h+.13,d*.5+2.5),Vector3(w+1,.4,1.0),plaster)
		piece(b,"VerandaRoof",Vector3(0,h+.42,d*.5+1.2),Vector3(w+1,.2,4.3),tile)
		for i in 7:
			column(b,Vector3(-w*.46+i*w*.92/6,h*.5+.24,d*.5+2.5),h)
		piece(b,"Desk",Vector3(0,1.02,-d*.2),Vector3(3,.16,1.0),wood)
		for side in [-1.0,1.0]:
			piece(b,"DeskLeg",Vector3(side*1.2,.55,-d*.2),Vector3(.15,.95,.7),wood)
	else:
		piece(b,"VerandaShade",Vector3(0,h-.1,d*.5+1.1),Vector3(w+.8,.13,2.6),wood,false)
		for side in [-1.0,1.0]:
			piece(b,"ShadePost",Vector3(side*(w*.5-.3),h*.5,d*.5+2),Vector3(.13,h,.13),wood)
		piece(b,"SleepingPlatform",Vector3(-2,.52,-1.4),Vector3(1.7,.16,2.5),wood)
	if jail:
		for x in [-7.0,0.0,7.0]:
			piece(b,"CellPartition",Vector3(x,1.75,-4.7),Vector3(.35,3,7),stone)
		for i in 49:
			var x: float = -10+i*.416
			if absf(x-3.5)<.7: continue
			piece(b,"CellBar",Vector3(x,1.8,-1.0),Vector3(.045,3.1,.045),iron,false)
		piece(b,"CellBarsCollision",Vector3(-4.05,1.8,-1),Vector3(12,3.1,.12),iron)
		piece(b,"CellBarsCollision",Vector3(7.1,1.8,-1),Vector3(5.8,3.1,.12),iron)
	if "Armoury" in label:
		# Timber shelf against the rear masonry, reached through the real doorway.
		# Keep its front clear of the room's desk and the player capsule.
		var rack_z: float = -d*.5+1.15
		piece(b,"WeaponRackShelf",Vector3(0,1.02,rack_z),Vector3(3.6,.16,.78),wood)
		piece(b,"WeaponRackUpperShelf",Vector3(0,1.70,rack_z),Vector3(3.6,.13,.78),wood)
		piece(b,"WeaponRackBack",Vector3(0,1.23,rack_z-.34),Vector3(3.6,.65,.12),wood)
		for side in [-1.0,1.0]:
			piece(b,"WeaponRackPost",Vector3(side*1.72,.58,rack_z),Vector3(.12,1.16,.78),wood)
		var rack_weapons := [
			["enfield","res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb"],
			["talwar","res://environment/weapons/Talwar/weapon_talwar_01.glb"],
			["bow","res://environment/weapons/period_bow/period_bow.glb"],
			["pistol","res://environment/weapons/adams_1851/adams_1851.glb"],
		]
		for i in rack_weapons.size():
			var pickup := Pickup.new()
			pickup.weapon_id = rack_weapons[i][0]
			pickup.position = Vector3(-.85+(i%2)*1.7,1.2+floori(i/2.0)*.68,rack_z+.12)
			b.add_child(pickup)
			var source: String = rack_weapons[i][1]
			var model: Node3D = load(source).instantiate()
			pickup.add_child(model)
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(1.4,.25,.35) if i < 3 else Vector3(.6,.25,.35)
			collision.shape = shape
			pickup.add_child(collision)
	var sign := Label3D.new()
	sign.text = {"SuryagarhTownHall":"SURYAGARH · TOWN HALL","PoliceThana":"POLICE THANA","DistrictJail":"DISTRICT JAIL","CompanyArmoury":"COMPANY STORES"}.get(label,"")
	sign.font = preload("res://assets/ui/fonts/CormorantGaramond.ttf")
	sign.font_size = 48
	sign.pixel_size = .007
	sign.modulate = Color(.20,.13,.07)
	sign.position = Vector3(0,3.5,d*.5+.205)
	b.add_child(sign)
	merge_visuals(b)
	return b

func compound() -> void:
	var c := Node3D.new()
	c.name = "ColonialCompound"
	add_child(c)
	var surveyed: Vector2 = Layout.PLOTS["CompanyCompound"].center
	c.position = Vector3(surveyed.x,Layout.PLOTS["CompanyCompound"].grade,surveyed.y)
	piece(c,"Courtyard",Vector3(0,.04,0),Vector3(102,.08,94),ochre)
	for side in [-1.0,1.0]:
		var wall := piece(c,"ClimbableWall",Vector3(side*52,2.4,0),Vector3(1.4,4.8,96),brick)
		var body: StaticBody3D = wall.get_child(1)
		if side<0:
			body.add_to_group("climbable_walls")
			body.set_meta("top_y",16.8)
			body.set_meta("climb_center_z",300.0)
		piece(c,"WallWalk",Vector3(side*50.3,4.62,0),Vector3(3.5,.36,96),stone)
		piece(c,"Coping",Vector3(side*52,4.8,0),Vector3(1.55,.14,96),stone,false)
		# Worn projecting masonry communicates the climb route.
		if side<0:
			for row in 8:
				for col in 3:
					piece(c,"ClimbingStone",Vector3(side*52.78,.42+row*.55,-.9+col*.8+(row%2)*.22),Vector3(.2,.14,.42),stone,false)
	piece(c,"SouthWall",Vector3(0,2.4,48),Vector3(104,4.8,1.4),brick)
	for side in [-1.0,1.0]:
		piece(c,"GateWall",Vector3(side*28,2.4,-48),Vector3(48,4.8,1.4),brick)
		piece(c,"GatePier",Vector3(side*4.25,2.7,-48),Vector3(1.3,5.4,1.8),stone)
	piece(c,"GateLintel",Vector3(0,5.15,-48),Vector3(8,.5,1.6),stone)
	var gate := Gate.new()
	gate.name = "BarredGate"
	gate.position = Vector3(0,1.9,-48)
	c.add_child(gate)
	var gate_visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(7.0,3.8,.3)
	gate_visual.mesh = box
	gate_visual.material_override = wood
	gate.add_child(gate_visual)
	var shape := BoxShape3D.new()
	shape.size = box.size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	gate.add_child(collision)
	# Walkway staircase gives the player a physical descent into the courtyard.
	for i in 24:
		piece(c,"WallWalkStair",Vector3(-47.2,.1+i*.1,-5+i*.38),Vector3(2,.2+i*.2,.4),stone)
	var flag: Node3D = preload("res://assets/props/flags/eic/prop_eic_checkpoint_flag_01.glb").instantiate()
	flag.position = Vector3(8,.1,-41)
	c.add_child(flag)
	merge_visuals(c)

func landing() -> void:
	var dock := Node3D.new()
	dock.name = "BhairavpurBoatLanding"
	add_child(dock)
	var z := 235.0
	var end: float = layout.river_x(z)-layout.river_width(z)+1.0
	var start: float = end-43
	var bank: float = layout.height(start,z)
	for i in 64:
		var t: float = float(i)/63
		var x: float = lerpf(start,end,t)
		var y: float = maxf(.45,lerpf(bank+.1,.45,clampf(t/.8,0,1)))
		piece(dock,"JettyPlank",Vector3(x,y-.09,z),Vector3(.72,.18,3),wood)
		if i%8==0:
			for side in [-1.0,1.0]:
				var ground: float = layout.height(x,z+side*1.25)
				piece(dock,"JettyPile",Vector3(x,(ground+y)*.5,z+side*1.25),Vector3(.18,maxf(.2,y-ground+.2),.18),wood)
	merge_visuals(dock)

func merge_visuals(parent: Node3D) -> void:
	var groups: Dictionary = {}
	for node in parent.find_children("*","MeshInstance3D",true,false):
		# Keep interactable/vehicle model geometry separate; it can disappear or animate.
		var p: Node = node.get_parent()
		var dynamic := false
		while p!=parent:
			if p is Interactable: dynamic = true
			p=p.get_parent()
		if dynamic or node.material_override==null or not node.visible: continue
		var m: Material = node.material_override
		if not groups.has(m):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[m]=st
		var relative: Transform3D = parent.global_transform.affine_inverse()*node.global_transform
		groups[m].append_from(node.mesh,0,relative)
		node.queue_free()
	for m in groups:
		var mesh := MeshInstance3D.new()
		mesh.mesh = groups[m].commit()
		mesh.material_override=m
		mesh.visibility_range_end=750
		mesh.visibility_range_end_margin=60
		parent.add_child(mesh)

func add_civic(label: String,p: Vector2,police: bool) -> void:
	var building := Node3D.new()
	building.set_script(load("res://world/suryagarh/settlements/civic_building.gd"))
	building.name = label
	building.set("police",police)
	building.position = Vector3(p.x,0,p.y)
	add_child(building)
