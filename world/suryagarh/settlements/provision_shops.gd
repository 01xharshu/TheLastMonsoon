extends Node3D
## Two permanent merchants on the public market lanes.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const Builder = preload("res://world/suryagarh/settlements/settlement_builder.gd")
const Door = preload("res://world/suryagarh/settlements/public_shop_gate.gd")
const Counter = preload("res://world/suryagarh/settlements/provision_counter.gd")
const Actor = preload("res://characters/npcs/households/household_npc_actor.gd")
const Human = preload("res://characters/human_scene.gd")
const FONT = preload("res://assets/ui/fonts/MFBOldstyle-Regular.otf")

func _ready() -> void:
	name = "ProvisionShops"
	var b := Builder.new()
	var layout := Layout.new()
	_build(b, layout, "VillageShop", "Bhairavpur provision shop", Vector2(-345, 279), PI, false)
	_build(b, layout, "CityShop", "Suryagarh provision shop", Vector2(-326, -328), 0, true)
	b.free()
	get_parent().get_node("Player/UI/WorldMap").refresh_sites()

func _build(b: Builder, layout: Layout, id: String, label: String, point: Vector2, yaw: float, city: bool) -> void:
	var shop := Node3D.new()
	shop.name = id
	shop.position = Vector3(point.x, layout.height(point.x, point.y), point.y)
	shop.rotation.y = yaw
	add_child(shop)
	var shell := Node3D.new()
	shell.name = "Building"
	shop.add_child(shell)
	var plaster := _masonry(Color("#bfa383") if city else Color("#a68d69"),0)
	var plinth := _masonry(Color("#706254"),1)
	var paving := _masonry(Color("#82715b") if city else Color("#8d795d"),0)
	var wall_base := _masonry(Color("#74604b"),0)
	var tile := ShaderMaterial.new()
	tile.shader = preload("res://world/suryagarh/settlements/village_surface.gdshader")
	tile.set_shader_parameter("tint",Color("#884b31"))
	var timber := ShaderMaterial.new()
	timber.shader = preload("res://world/suryagarh/settlements/building_wood.gdshader")
	var paper: Material = b.material(Color("#e6cf9e"))

	b.piece(shell, "StoneFloor", Vector3(0,.04,0), Vector3(7.4,.24,7.2), paving)
	b.piece(shell, "VerandaFloor", Vector3(4.86,.04,0), Vector3(2.35,.24,7.2), paving)
	for z in [-3.5,3.5]:
		b.piece(shell, "EndWall", Vector3(0,1.66,z), Vector3(7.2,3,.24), plaster)
		_gable(b,shell,z,plaster)
	b.piece(shell, "RearWall", Vector3(-3.6,1.66,0), Vector3(.25,3,7), plaster)
	for z in [-2.35,2.35]:
		b.piece(shell, "SideEntryWall", Vector3(3.6,1.66,z), Vector3(.25,3,2.3), plaster)
	b.piece(shell, "EntryLintel", Vector3(3.6,2.84,0), Vector3(.27,.64,2.4), plaster)
	for z in [-1.27,1.27]:
		b.piece(shell,"DoorJamb",Vector3(3.61,1.34,z),Vector3(.34,2.36,.14),timber,false)
	b.piece(shell,"TimberLintel",Vector3(3.61,2.55,0),Vector3(.34,.16,2.72),timber,false)
	for z in [-3.32,3.32]:
		b.piece(shell,"InteriorWallFoot",Vector3(0,.27,z),Vector3(7.08,.22,.13),wall_base,false)
	b.piece(shell,"RearWallFoot",Vector3(-3.44,.27,0),Vector3(.12,.22,6.55),wall_base,false)
	for x in [-1.0,1.0]:
		var roof := b.piece(shell, "ClayTileSlope", Vector3(x*1.94,3.51,0), Vector3(4.15,.18,7.7), tile, false)
		roof.rotation.z = -x*.18
		for z in [-2.82,-1.42,0.0,1.42,2.82]:
			var rafter := b.piece(shell,"RoofRafter",Vector3(x*1.87,3.34,z),Vector3(3.96,.17,.14),timber,false)
			rafter.rotation.z = roof.rotation.z
	for z in [-2.78,0.0,2.78]:
		b.piece(shell,"RoofTieBeam",Vector3(0,3.07,z),Vector3(7.12,.2,.18),timber,false)
	b.piece(shell, "RidgeCap", Vector3(0,3.91,0), Vector3(.28,.18,7.75), tile, false)
	var shed := b.piece(shell, "VerandaClayTiles", Vector3(4.93,2.91,0), Vector3(2.85,.16,7.65), tile)
	shed.rotation.z = -.17
	b.piece(shell,"WallPlate",Vector3(3.68,2.94,0),Vector3(.15,.16,7.22),timber,false)
	for z in [-3.3,-2.2,-1.1,0.0,1.1,2.2,3.3]:
		var rafter := b.piece(shell,"VerandaRafter",Vector3(4.93,2.79,z),Vector3(2.74,.13,.12),timber,false)
		rafter.rotation.z = shed.rotation.z
	b.piece(shell, "VerandaBeam", Vector3(6.1,2.55,0), Vector3(.16,.21,7.4), timber, false)
	for z in [-3.35,3.35]:
		b.piece(shell, "TimberPost", Vector3(6.04,1.36,z), Vector3(.18,2.42,.18), timber)
		b.piece(shell, "PostFoot", Vector3(6.04,.26,z), Vector3(.29,.2,.29), plinth)
		var brace := b.piece(shell, "KneeBrace", Vector3(6.04,2.28,z-signf(z)*.27), Vector3(.12,.74,.12), timber, false)
		brace.rotation.x = -signf(z)*.75
	for z in [-1.8,1.8]:
		var shelter := Marker3D.new()
		shelter.name = "VerandaShelterWest" if z < 0 else "VerandaShelterEast"
		shelter.position = Vector3(5.6,.16,z)
		shelter.add_to_group("rain_shelter")
		shop.add_child(shelter)
	for x in [4.22,5.5]:
		for z in [-3.66,3.66]:
			b.piece(shell, "VerandaThreshold", Vector3(x,.01,z), Vector3(1.18,.16,.22), plinth)
	var sign_board := b.piece(shell, "ShopSign", Vector3(3.77,2.73,0), Vector3(.08,.32,1.83), timber, false)
	var sign_label := Label3D.new()
	sign_label.text = "PROVISIONS"
	sign_label.font = FONT
	sign_label.font_size = 48
	sign_label.pixel_size = .0035
	sign_label.modulate = Color("#f3dca7")
	sign_label.outline_size = 0
	sign_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sign_label.rotation.y = PI*.5
	sign_label.position.x = .047
	sign_board.add_child(sign_label)

	var jamb := Node3D.new()
	jamb.name = "SideGateFrame"
	jamb.position = Vector3(3.6,.16,0)
	jamb.rotation.y = PI*.5
	shop.add_child(jamb)
	var gate := Door.new()
	gate.name = "ProvisionGate"
	gate.width = 2.4
	gate.height = 2.35
	gate.label_name = "shop gate"
	gate.opened = true
	gate.swing_direction = -1.0
	gate.night_lock = false
	gate.auto_open_at_dawn = false
	gate.always_open = true
	gate.auto_close_delay = 0.0
	gate.position.x = -gate.width*.5
	gate.build(timber)
	jamb.add_child(gate)
	var map_pin := Marker3D.new()
	map_pin.name = "ShopApproach"
	map_pin.position = Vector3(5.0,.16,0)
	map_pin.set_meta("parking_label", label)
	shop.add_child(map_pin)

	b.piece(shell, "CounterTop", Vector3(-.95,1.02,0), Vector3(.84,.1,3.15), timber)
	# Individual boards and the apron make the working surface read as joinery.
	var counter_wood := timber.duplicate() as ShaderMaterial
	counter_wood.set_shader_parameter("tint",Color("#67432b"))
	for x in [-1.23,-.95,-.67]:
		b.piece(shell,"CounterBoard",Vector3(x,1.075,0),Vector3(.272,.01,3.12),counter_wood,false)
	b.piece(shell,"CounterApron",Vector3(-.57,.85,0),Vector3(.08,.29,3.01),timber,false)
	for z in [-1.4,1.4]:
		b.piece(shell,"CounterEndRail",Vector3(-.95,.82,z),Vector3(.76,.11,.08),timber,false)
	for z in [-1.28,1.28]:
		b.piece(shell, "CounterTrestle", Vector3(-.95,.57,z), Vector3(.7,.82,.18), timber)
	for height in [1.81,2.36]:
		b.piece(shell, "GoodsShelf", Vector3(-3.17,height,0), Vector3(.62,.09,4.25), timber)
	for z in [-2.08,2.08]:
		b.piece(shell, "ShelfUpright", Vector3(-3.16,1.38,z), Vector3(.6,2.44,.10), timber)
	for z in [-2.8,2.8]:
		_prop(shell, preload("res://objects/household/grain_sack.tscn"), Vector3(-2.9,.16,z))
		_prop(shell, preload("res://objects/household/storage/basket.tscn"), Vector3(-1.85,.16,z))
	for z in [-1.56,-.74,.72,1.53]:
		_prop(shell, preload("res://objects/household/water_pot_visual.tscn"), Vector3(-3.12,1.86,z), .50+absf(z)*.085)
		_prop(shell, preload("res://objects/household/supplies/bandage_roll.tscn"), Vector3(-3.12,2.41,z))
	_prop(shell, preload("res://objects/household/supplies/supply_parcel.tscn"), Vector3(-3.09,1.38,-.94))
	_prop(shell, preload("res://objects/household/storage/basket.tscn"), Vector3(-3.08,1.38,1.36), .72)
	for z in [-.58,-.28,.08,.38]:
		var parcel := _prop(shell,preload("res://objects/household/supplies/supply_parcel.tscn"),Vector3(-3.1,1.38,z),.8)
		parcel.rotation.y = .2 if z < 0 else -.3
	for z in [-1.18,.15,1.2]:
		var bundle := _prop(shell,preload("res://objects/household/supplies/supply_parcel.tscn"),Vector3(-3.1,2.41,z),.82)
		bundle.rotation.y = .2*z
	_prop(shell, preload("res://objects/household/oil_lamp_visual.tscn"), Vector3(-.98,1.08,1.32), .84)
	_storage(b,shell,timber,city)
	_wall_stock(b,shell,timber,city)
	var ledger := Node3D.new()
	ledger.name = "CounterLedger"
	ledger.position = Vector3(-1.14,1.08,.15)
	shop.add_child(ledger)
	b.piece(ledger, "LeatherBinding", Vector3(0,.018,0), Vector3(.42,.036,.59), timber, false)
	for z in [-.14,.14]:
		b.piece(ledger, "PaperBlock", Vector3(0,.041,z), Vector3(.385,.035,.278), paper, false)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-.62,1.38,1.24)
	lamp.light_color = Color("#ffe0a8")
	lamp.light_energy = .42
	lamp.omni_range = 4.5
	shop.add_child(lamp)
	b.merge_visuals(shell)

	var keeper := Actor.new()
	keeper.name = "Shopkeeper"
	keeper.movement_enabled = false
	keeper.set_meta("population_expansion_exempt", true)
	keeper.set_meta("external_combat_motion", true)
	keeper.set_meta("world_role", "provision_shopkeeper")
	var source := "res://characters/npcs/households/merchant.glb" if city else "res://characters/npcs/street_residents/merchant.glb"
	keeper.add_child(Human.instantiate(source))
	keeper.position = Vector3(-1.67,.16,.15)
	keeper.rotation.y = PI*.5
	shop.add_child(keeper)
	for mesh: GeometryInstance3D in keeper.find_children("*","GeometryInstance3D",true,false):
		mesh.visibility_range_end = 110
	var counter := Counter.new()
	counter.name = "LedgerService"
	counter.position = Vector3(-.46,1.17,.15)
	counter.keeper = keeper
	counter.ledger = ledger
	shop.add_child(counter)

func _storage(b: Builder, shell: Node3D, timber: Material, city: bool) -> void:
	var storage := Node3D.new()
	storage.name = "ShopStorage"
	shell.add_child(storage)
	var stained := timber.duplicate() as ShaderMaterial
	stained.set_shader_parameter("tint",Color("#5a3926"))
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("#332a22")
	iron.metallic = .65
	iron.roughness = .76
	b.piece(storage,"DrawerCase",Vector3(-3.15,.78,0),Vector3(.68,1.16,4.2),timber)
	b.piece(storage,"DrawerPlinth",Vector3(-3.17,.18,0),Vector3(.61,.04,4.12),timber,false)
	b.piece(storage,"DrawerCaseTop",Vector3(-3.15,1.355,0),Vector3(.77,.05,4.31),stained,false)
	for bay in [-1.38,0.0,1.38]:
		for height in [.48,1.04]:
			b.piece(storage,"DrawerFront",Vector3(-2.791,height,bay),Vector3(.056,.438,1.29),stained,false)
			for side in [-1.0,1.0]:
				b.piece(storage,"PullMount",Vector3(-2.753,height,bay+side*.075),Vector3(.042,.044,.045),iron,false)
			b.piece(storage,"DrawerPull",Vector3(-2.714,height-.014,bay),Vector3(.04,.024,.164),iron,false)
	var crate := preload("res://objects/household/storage/crate.tscn")
	var sack := preload("res://objects/household/grain_sack.tscn")
	var stack := _prop(storage,crate,Vector3(2.3,.16,2.89),.8)
	var top: Vector3 = stack.get_node("TopReference").global_position
	_prop(storage,crate,storage.to_local(top)+Vector3.UP*.029,.57)
	_prop(storage,crate,Vector3(2.7 if city else 1.85,.16,-2.85),.73)
	for i in 3:
		var bag := _prop(storage,sack,Vector3(.25+i*.58,.16,-2.96),[1.12,.91,1.03][i])
		bag.rotation.y = .35+i*.6
	_prop(storage,sack,Vector3(1.74,.16,2.84),1.02)
	# The stored containers sit against the end wall, clear of the customer lane.
	var basket := _prop(storage,preload("res://objects/household/storage/basket.tscn"),Vector3(.3,.16,3.03),.9)
	basket.rotation.y = -.22
	var parcel := _prop(storage,preload("res://objects/household/supplies/supply_parcel.tscn"),Vector3(.3,.277,3.03),.8)
	parcel.rotation.y = .3

func _gable(b: Builder, parent: Node3D, z: float, material: Material) -> void:
	# Overlapping masonry courses meet the roof slopes and the wall top.
	for course in 14:
		var bottom := 3.13 + course*.05
		var half_width := maxf(.04,3.58*(3.83-bottom)/.70)
		b.piece(parent,"GableCourse",Vector3(0,bottom+.025,z),Vector3(half_width*2,.052,.24),material,false)

func _wall_stock(b: Builder, shell: Node3D, timber: Material, city: bool) -> void:
	# A narrow stock shelf is fixed to the end wall, above the stored sacks.
	var stock := Node3D.new()
	stock.name = "EndWallStock"
	shell.add_child(stock)
	b.piece(stock,"StockShelf",Vector3(.05,1.78,-3.16),Vector3(3.4,.09,.45),timber,false)
	for x in [-1.36,1.46]:
		b.piece(stock,"ShelfBracket",Vector3(x,1.66,-3.25),Vector3(.11,.19,.25),timber,false)
	var brass := preload("res://objects/household/storage/brass_pot.tscn")
	var clay := preload("res://objects/household/water_pot_visual.tscn")
	var parcel := preload("res://objects/household/supplies/supply_parcel.tscn")
	_prop(stock,brass,Vector3(-1.17,1.825,-3.17),.7 if city else .58)
	_prop(stock,clay,Vector3(-.52,1.825,-3.17),.55 if city else .72)
	var parcel_a := _prop(stock,parcel,Vector3(.16,1.825,-3.16),.85)
	parcel_a.rotation.y = -.18
	var parcel_b := _prop(stock,parcel,Vector3(.65,1.825,-3.16),.7)
	parcel_b.rotation.y = .16
	_prop(stock,brass,Vector3(1.23,1.825,-3.17),.48)

func _prop(parent: Node3D, scene: PackedScene, at: Vector3, size := 1.0) -> Node3D:
	var prop := scene.instantiate() as Node3D
	prop.position = at
	prop.scale = Vector3.ONE * size
	parent.add_child(prop)
	return prop

func _masonry(color: Color, kind: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://world/suryagarh/settlements/administrative_surface.gdshader")
	material.set_shader_parameter("tint",color)
	material.set_shader_parameter("kind",kind)
	return material
