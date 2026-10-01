extends "res://tools/assets/build_activity_sets.gd"
func build() -> void:
	var wood := material(Color(.26,.15,.075))
	var rest := Node3D.new()
	rest.name = "RestCornerSet"
	instance_prop(rest,"res://objects/charpai.tscn","Charpai",Vector3.ZERO)
	instance_prop(rest,"res://objects/household/woven_mat.tscn","FootMat",Vector3(0,0,1.35))
	instance_prop(rest,"res://objects/household/storage/stool.tscn","LampStool",Vector3(1.45,0,-.1))
	# Read the shared stool's seat-height marker instead of guessing support height.
	var stool: Node3D = rest.get_node("LampStool")
	var seat := stool.get_node_or_null("Seat") as Marker3D
	var height := seat.position.y if seat != null else .44
	instance_prop(rest,"res://objects/household/oil_lamp_visual.tscn","Lamp",Vector3(1.45,height,-.1))
	marker(rest,"Approach",Vector3(0,0,.85))
	marker(rest,"ClearExit",Vector3(-1.45,0,.85))
	pack_set(rest,"rest_corner")
	var market := Node3D.new()
	market.name = "MarketSupplySet"
	part(market,"Counter",Vector3(1.6,.06,.75),Vector3(0,.73,0),wood)
	for x in [-.68,.68]:
		for z in [-.28,.28]:
			part(market,"Leg",Vector3(.08,.70,.08),Vector3(x,.35,z),wood)
	instance_prop(market,"res://objects/household/storage/basket.tscn","DisplayBasket",Vector3(-.38,.76,0))
	instance_prop(market,"res://objects/household/supplies/supply_parcel.tscn","Parcel",Vector3(.35,.76,.05))
	instance_prop(market,"res://objects/household/grain_sack.tscn","StockSack",Vector3(-1.12,0,-.2))
	marker(market,"Approach",Vector3(0,0,.95))
	marker(market,"VendorPosition",Vector3(0,0,-.95))
	marker(market,"ExchangeTarget",Vector3(.35,.86,.05))
	pack_set(market,"market_supply")
	var armoury := Node3D.new()
	armoury.name = "ArmourySupplySet"
	part(armoury,"ShelfTop",Vector3(1.4,.06,.6),Vector3(0,.94,0),wood)
	part(armoury,"LowerShelf",Vector3(1.4,.05,.6),Vector3(0,.28,0),wood)
	for x in [-.62,.62]:
		for z in [-.23,.23]:
			part(armoury,"Post",Vector3(.07,.91,.07),Vector3(x,.455,z),wood)
	instance_prop(armoury,"res://objects/household/supplies/bandage_roll.tscn","Bandage",Vector3(-.35,.97,.02))
	instance_prop(armoury,"res://objects/household/supplies/supply_parcel.tscn","SealedSupply",Vector3(.32,.97,0))
	instance_prop(armoury,"res://objects/household/supplies/folded_letter.tscn","StockNote",Vector3(0,.97,.17))
	marker(armoury,"Approach",Vector3(0,0,.90))
	marker(armoury,"CollectionTarget",Vector3(-.35,1.025,.02))
	pack_set(armoury,"armoury_supply")
	print("ACTIVITY B: rest, market and armoury prefabs built")
	quit()
