extends RefCounted
## Late placement pass: preserve existing building geometry, rewards and world-root bed.
var world: Node3D
var settlement: Node3D
func place(parent: Node3D, scene: String, label: String, at: Vector3) -> Node3D:
	var prop: Node3D = load(scene).instantiate()
	prop.name = label
	prop.position = at
	prop.add_to_group("asset_first_placed")
	prop.set_meta("placement_id",label)
	parent.add_child(prop)
	return prop
func integrate(target: Node3D) -> void:
	world = target
	settlement = world.get_node("Settlement")
	var home: Node3D = settlement.get_node("BhairavpurHouse0")
	var rest := place(home,"res://objects/household/sets/rest_corner.tscn","ArjunRestDressing",Vector3(-2.35,.24,-1.4))
	# Preserve the existing world-root Charpai and its sleep/save references.
	rest.get_node("Charpai").free()
	# Keep the partition-side exit clear; mat remains beside the sleeping room.
	rest.get_node("FootMat").position = Vector3(-.25,0,1.35)
	rest.get_node("LampStool").position = Vector3(-1.45,0,-.1)
	rest.get_node("Lamp").position.x = -1.45
	replace_lamp(rest)
	var cooking := place(settlement.get_node("BhairavpurHouse1"),"res://objects/household/sets/cooking_corner.tscn","CourtyardCooking",Vector3(2.2,0,6.3))
	# Use an actual water source in the courtyard too, without a duplicate visual.
	cooking.get_node("WaterPot").free()
	place(cooking,"res://objects/water_pot.tscn","CookingWaterSource",Vector3(.65,.4,-.36))
	place(home,"res://objects/water_pot.tscn","IndoorWaterSource",Vector3(2.6,.64,.75))
	var roti := place(cooking,"res://objects/roti.tscn","CourtyardRoti",Vector3(-.4,.315,-.2))
	persistent(roti,"village/courtyard_roti")
	var pouch := place(home,"res://objects/water_bag.tscn","SpareWaterPouch",Vector3(3.65,.89,1.15))
	persistent(pouch,"arjun_home/spare_pouch")
	var records := place(settlement.get_node("TownHall"),"res://objects/household/sets/records_desk.tscn","TownRecordsDesk",Vector3(-4,0,1.4))
	replace_lamp(records)
	place(settlement.get_node("BhairavpurGrainStore"),"res://objects/household/sets/market_supply.tscn","GrainStoreCounter",Vector3(0,.16,0))
	var armoury: Node3D = settlement.get_node("CompanyArmoury")
	var shelf := place(armoury,"res://objects/household/sets/armoury_supply.tscn","ArmourySupplyShelf",Vector3(-5,.24,-3))
	# Reuse the existing medical pickup; move its visual onto the new shelf.
	shelf.get_node("Bandage").free()
	var medical: Node3D = armoury.get_node("BandageSupply")
	medical.set_meta("asset_first_visual",true)
	medical.position = Vector3(-5.35,1.21,-2.98)
	for child in medical.get_children():
		if child is MeshInstance3D: child.free()
	place(medical,"res://objects/household/supplies/bandage_roll.tscn","SharedBandageVisual",Vector3.ZERO)
	# Fences and open gate sit at the grain-store perimeter, away from its loading aisle.
	var store: Node3D = settlement.get_node("BhairavpurGrainStore")
	place(store,"res://objects/obstacles/timber_fence.tscn","StoreFenceWest",Vector3(-2,0,-4))
	place(store,"res://objects/obstacles/timber_fence.tscn","StoreFenceEast",Vector3(2,0,-4))
	var gate := place(store,"res://objects/obstacles/timber_gate.tscn","StoreOpenGate",Vector3(0,0,-4))
	gate.get_node("HingePivot").rotation_degrees.y = -95
	for boundary in [store.get_node("StoreFenceWest"),store.get_node("StoreFenceEast"),gate]:
		boundary.get_node("Approach").position.z = -.85
		boundary.get_node("Approach").rotation.y = PI
	var court: Vector2 = preload("res://world/suryagarh/landscape_layout.gd").PLOTS["CompanyCompound"].center
	var grade: float = preload("res://world/suryagarh/landscape_layout.gd").PLOTS["CompanyCompound"].grade+.08
	place(settlement,"res://objects/obstacles/timber_barricade.tscn","StoresBarricade",Vector3(court.x+23,grade,court.y+22))
	place(settlement,"res://objects/obstacles/low_masonry_cover.tscn","StoresLowCover",Vector3(court.x+26,grade,court.y+22))
func persistent(prop: Node3D, id: String) -> void:
	prop.add_to_group("household_pickups")
	prop.set_meta("pickup_id",id)

func replace_lamp(parent: Node3D) -> void:
	var visual: Node3D = parent.get_node("Lamp")
	var at := visual.position
	visual.free()
	var lamp: Node3D = load("res://objects/oil_lamp.tscn").instantiate()
	lamp.name = "Lamp"
	lamp.position = at
	lamp.starts_lit = false
	parent.add_child(lamp)
