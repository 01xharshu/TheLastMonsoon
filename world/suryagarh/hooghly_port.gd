extends Node3D
## Fictional compact Hooghly anchorage; original explorable merchant ship at berth.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const SHIP = preload("res://assets/vehicles/ships/hooghly_merchant/hooghly_merchant_1850s.glb")
const CRATE = preload("res://assets/props/polyhaven/wooden_crate_02/wooden_crate_02_1k.gltf")
const BARREL = preload("res://assets/props/polyhaven/wine_barrel_01/wine_barrel_01_1k.gltf")
const SHIP_AT := Vector3(-85.0, 0.0, 680.0)
const DECK_Y := 3.32
var ship: Node3D
var boundary: StaticBody3D
var hint_cooldown := 0.0
var wood: StandardMaterial3D
var stone: StandardMaterial3D
var plaster: StandardMaterial3D
var roof_tile: StandardMaterial3D
var iron: StandardMaterial3D
var rope_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("hooghly_port")
	wood = material(Color(0.30,0.23,0.14))
	stone = material(Color(0.40,0.37,0.30))
	plaster = material(Color(0.66,0.59,0.44))
	roof_tile = material(Color(0.38,0.23,0.14))
	iron = material(Color(0.09,0.10,0.09))
	rope_material = material(Color(0.25,0.22,0.15))
	build_quay()
	build_ship()
	build_boundary()
	# Water is a continuous surface outside the hull, including beyond the limit.
	var river: MeshInstance3D = get_parent().get_node("Landscape/RiverSurface")
	var water: ShaderMaterial = river.mesh.surface_get_material(0)
	water.set_shader_parameter("exclude_moored_ship",true)
	water.set_shader_parameter("moored_ship_center",Vector2(SHIP_AT.x,SHIP_AT.z))
	print("HOOGHLY PORT READY | 51m ship | deck/cabin/hold | sea limit z=",Layout.SEA_LIMIT_Z)

func material(color: Color) -> StandardMaterial3D:
	var value := StandardMaterial3D.new()
	value.albedo_color = color
	value.roughness = 0.86
	return value

func piece(parent: Node3D, label: String, at: Vector3, size: Vector3, mat: Material, solid := true) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = mat
	visual.position = at
	parent.add_child(visual)
	if solid:
		var body := StaticBody3D.new()
		visual.add_child(body)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	return visual

func beam(parent: Node3D, label: String, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var visual := MeshInstance3D.new()
	visual.name = label
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 8
	visual.mesh = cylinder
	visual.material_override = mat
	visual.position = (a+b)*0.5
	var y := (b-a).normalized()
	var reference := Vector3.RIGHT if absf(y.dot(Vector3.UP))>0.95 else Vector3.UP
	var x := y.cross(reference).normalized()
	visual.basis = Basis(x,y,x.cross(y).normalized())
	parent.add_child(visual)

func build_quay() -> void:
	var quay := Node3D.new()
	quay.name = "Quay"
	add_child(quay)
	# The surveyed terrace, masonry face and timber piles actually meet the ground.
	piece(quay,"QuayApron",Vector3(-171,2.82,680),Vector3(38,0.12,62),stone)
	piece(quay,"QuayFace",Vector3(-150.5,0.9,680),Vector3(2.2,3.8,63),stone)
	for z in range(650,715,4):
		piece(quay,"QuayCoping",Vector3(-150.5,2.83,z),Vector3(2.4,0.20,3.94),plaster,false)
	# Inclined approach reaches the deck continuously from the 2.8m terrace.
	var ramp := piece(quay,"JettyApproach",Vector3(-155,3.065,680),Vector3(10,0.18,8),wood)
	ramp.rotation.z = atan2(0.52,10.0)
	piece(quay,"PierWalk",Vector3(-125.5,DECK_Y-0.12,680),Vector3(51,0.24,8),wood)
	piece(quay,"BerthHead",Vector3(-101,DECK_Y-0.12,680),Vector3(6,0.24,66),wood)
	var layout := Layout.new()
	for x in range(-149,-99,6):
		for z in [676.4,683.6]:
			var bed: float = layout.height(x,z)
			piece(quay,"DrivenTimberPile",Vector3(x,(bed+3.08)*0.5,z),Vector3(0.38,3.08-bed,0.38),wood)
			piece(quay,"PierCrossbeam",Vector3(x,2.96,680),Vector3(0.35,0.32,8.5),wood,false)
	for z in range(649,714,6):
		for x in [-103.5,-98.5]:
			var bed: float = layout.height(x,z)
			piece(quay,"BerthPile",Vector3(x,(bed+4.0)*0.5,z),Vector3(0.4,4.0-bed,0.4),wood)
	for x in range(-148,-102,2):
		for z in [676.2,683.8]:
			piece(quay,"PierGuardPost",Vector3(x,3.84,z),Vector3(0.13,1.15,0.13),wood)
	for z in [676.2,683.8]:
		piece(quay,"PierHandrail",Vector3(-126,4.35,z),Vector3(45,0.12,0.12),wood)
	# Gangway has fixed ends at the berth and the actual opening in port bulwark.
	piece(quay,"ShipGangway",Vector3(-95.2,DECK_Y-0.10,684),Vector3(12.0,0.20,2.2),wood)
	for z in [682.9,685.1]:
		piece(quay,"GangwayRail",Vector3(-95.2,4.40,z),Vector3(11.9,0.12,0.12),wood)
		for x in [-100.5,-97.0,-93.5,-90.0]:
			piece(quay,"GangwayPost",Vector3(x,3.85,z),Vector3(0.12,1.15,0.12),wood)
	for z in [653.0,707.0]:
		piece(quay,"MooringBollard",Vector3(-100,3.72,z),Vector3(0.36,0.8,0.36),iron)
	# A supported tidal landing gives swimmers a return route onto the quay.
	for i in 23:
		var top := 2.8-float(i)*0.18
		piece(quay,"TidalLandingStep",Vector3(-150.5+float(i)*0.48,top-0.12,712),Vector3(0.52,0.24,3.2),stone,false)
	# Buoyant movement cannot step up a vertical riser. A continuous collision
	# grade beneath the stair treads allows the swimmer to walk out naturally.
	var tidal_body := StaticBody3D.new()
	tidal_body.name = "TidalLandingGrade"
	quay.add_child(tidal_body)
	var tidal_shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for z in [710.4,713.6]:
		points.append(Vector3(-150.8,2.86,z))
		points.append(Vector3(-139.25,-1.36,z))
		points.append(Vector3(-139.25,-1.65,z))
		points.append(Vector3(-150.8,2.57,z))
	tidal_shape.points = points
	var tidal_collision := CollisionShape3D.new()
	tidal_collision.shape = tidal_shape
	tidal_body.add_child(tidal_collision)
	build_warehouse(quay)
	for i in 12:
		cargo(quay,CRATE,"LandingCrate",Vector3(-176+(i%3)*1.55,2.89,657+floori(i/3.0)*1.65))
	for i in 6:
		cargo(quay,BARREL,"CargoCask",Vector3(-163+(i%2)*1.5,2.89,698+floori(i/2.0)*1.7))
	# Simple unloading shear legs: timber, tackle and a suspended empty hook.
	beam(quay,"ShearLeg",Vector3(-154,2.9,701),Vector3(-148,10.8,702),0.20,wood)
	beam(quay,"ShearLeg",Vector3(-142,3.32,701),Vector3(-148,10.8,702),0.20,wood)
	beam(quay,"Tackle",Vector3(-148,10.8,702),Vector3(-148,5.6,702),0.035,rope_material)
	piece(quay,"CargoHook",Vector3(-148,5.5,702),Vector3(0.20,0.32,0.16),iron,false)
	var sign := Label3D.new()
	sign.name = "PortSign"
	sign.text = "HOOGHLY REACH\nCOMPANY LANDING"
	sign.font_size = 48
	sign.pixel_size = 0.013
	sign.modulate = Color(0.83,0.76,0.54)
	sign.position = Vector3(-191.6,5.6,666)
	sign.rotation.y = PI*0.5
	quay.add_child(sign)

func cargo(parent: Node3D, scene: PackedScene, label: String, at: Vector3) -> void:
	var prop: Node3D = scene.instantiate()
	prop.name = label
	prop.position = at
	parent.add_child(prop)
	var bounds := AABB()
	var first := true
	for child in prop.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = child
		var box: AABB = prop.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var cargo_scale := (1.0 if scene == CRATE else 0.80)/maxf(bounds.size.x,bounds.size.z)
	prop.scale = Vector3.ONE*cargo_scale
	prop.position.y -= bounds.position.y*cargo_scale
	var body := StaticBody3D.new()
	prop.add_child(body)
	var shape := BoxShape3D.new()
	shape.size = bounds.size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = bounds.get_center()
	body.add_child(collision)

func build_warehouse(parent: Node3D) -> void:
	var warehouse := Node3D.new()
	warehouse.name = "CustomsWarehouse"
	warehouse.position = Vector3(-206,2.8,680)
	parent.add_child(warehouse)
	piece(warehouse,"WarehouseFloor",Vector3(0,0.04,0),Vector3(28,0.08,22),stone)
	piece(warehouse,"RearWall",Vector3(-14,2.2,0),Vector3(0.38,4.4,22),plaster)
	for z in [-11.0,11.0]:
		piece(warehouse,"EndWall",Vector3(0,2.2,z),Vector3(28,4.4,0.38),plaster)
	for z in [-7.4,7.4]:
		piece(warehouse,"WarehouseFront",Vector3(14,2.2,z),Vector3(0.38,4.4,7.2),plaster)
	piece(warehouse,"EntranceHeader",Vector3(14,4.05,0),Vector3(0.45,0.7,7.7),wood)
	for z in [-4.0,4.0]:
		piece(warehouse,"OpenCargoDoor",Vector3(13.8,1.8,z),Vector3(3.5,3.6,0.14),wood)
	# Pitched tiled roof with open door and timber trusses, no modern containers.
	for side in [-1,1]:
		var roof := piece(warehouse,"PitchedRoof",Vector3(0,5.1,side*5.9),Vector3(30,0.22,12.5),roof_tile)
		roof.rotation.x = side*0.16
	for x in range(-12,15,4):
		piece(warehouse,"RoofTie",Vector3(x,4.32,0),Vector3(0.25,0.24,22.5),wood,false)
	for i in 14:
		cargo(warehouse,CRATE,"WarehouseCrate",Vector3(-10+(i%7)*2.4,0.08,-7+floori(i/7.0)*2.0))
	for i in 5:
		cargo(warehouse,BARREL,"WarehouseCask",Vector3(-10+i*2.0,0.08,7))
	interior_lamp(warehouse,Vector3(0,3.2,0),8.0)

func build_ship() -> void:
	ship = Node3D.new()
	ship.name = "MerchantShip"
	ship.position = SHIP_AT
	ship.add_to_group("explorable_merchant_ship")
	add_child(ship)
	var visual: Node3D = SHIP.instantiate()
	visual.name = "ShipVisual"
	ship.add_child(visual)
	# Use the real authored deck/stairs/walls, with the companionway opening intact.
	for child in visual.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = child
		if not ("WeatherDeck" in mesh.name or "TarredHull" in mesh.name or "CopperSheathing" in mesh.name or "OakSpars" in mesh.name or "IvoryRail" in mesh.name or "CargoWood" in mesh.name): continue
		var body := StaticBody3D.new()
		body.name = "ShipStructure"
		mesh.add_child(body)
		var collision := CollisionShape3D.new()
		collision.shape = mesh.mesh.create_trimesh_shape()
		collision.shape.backface_collision = true
		body.add_child(collision)
	for z in [-13.0,-3.0,13.0]: interior_lamp(ship,Vector3(0.8,1.7,z),6.0)
	interior_lamp(ship,Vector3(1.6,5.1,20),5.0)
	for pair in [[Vector3(-4.2,4.4,-19),Vector3(-15.0,3.8,-27)], [Vector3(-4.05,4.4,20),Vector3(-15.0,3.8,27)]]:
		var a: Vector3 = pair[0]
		var b: Vector3 = pair[1]
		for i in 12:
			var t0 := float(i)/12.0
			var t1 := float(i+1)/12.0
			beam(ship,"MooredHawser",a.lerp(b,t0)-Vector3.UP*sin(t0*PI)*0.35,a.lerp(b,t1)-Vector3.UP*sin(t1*PI)*0.35,0.065,rope_material)
	var nameplate := Label3D.new()
	nameplate.text = "MERCY"
	nameplate.position = Vector3(0,5.55,23.82)
	nameplate.rotation.y = PI
	nameplate.font_size = 64
	nameplate.pixel_size = 0.012
	nameplate.modulate = Color(0.71,0.56,0.25)
	ship.add_child(nameplate)

func interior_lamp(parent: Node3D, at: Vector3, reach: float) -> void:
	piece(parent,"LanternTop",at+Vector3(0,0.16,0),Vector3(0.24,0.06,0.24),iron,false)
	piece(parent,"LanternBase",at-Vector3(0,0.16,0),Vector3(0.24,0.06,0.24),iron,false)
	var glow := OmniLight3D.new()
	glow.position = at
	glow.light_color = Color(1.0,0.69,0.35)
	glow.light_energy = 0.65
	glow.omni_range = reach
	glow.shadow_enabled = false
	parent.add_child(glow)

func is_dry_ship_interior(world_position: Vector3) -> bool:
	var p := world_position-SHIP_AT
	# The sealed cargo hold/crew floor is below waterline. Outside the hull,
	# ordinary estuary swimming resumes immediately; no global water toggle.
	return absf(p.x)<3.60 and p.z>-18.5 and p.z<18.5 and p.y>-1.4 and p.y<3.4

func build_boundary() -> void:
	boundary = StaticBody3D.new()
	boundary.name = "InvisibleSeaBoundary"
	boundary.set_meta("purpose","Finite playable estuary; sea remains visible beyond")
	add_child(boundary)
	for region in [
		[Vector3(0,10,Layout.SEA_LIMIT_Z),Vector3(Layout.SIZE+8,100,1.0)],
		[Vector3(-Layout.HALF+5,10,690),Vector3(1.0,100,262)],
		[Vector3(Layout.HALF-5,10,690),Vector3(1.0,100,262)]]:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = region[1]
		collision.shape = shape
		collision.position = region[0]
		boundary.add_child(collision)

func _physics_process(delta: float) -> void:
	hint_cooldown = maxf(0.0,hint_cooldown-delta)
	var player: CharacterBody3D = get_parent().get_node("Player")
	if hint_cooldown<=0.0 and player.is_swimming and player.position.z>Layout.SEA_LIMIT_Z-2.0 and Input.is_action_pressed("move_forward"):
		player.inventory.request_message("The open sea lies beyond this reach")
		hint_cooldown = 5.0
