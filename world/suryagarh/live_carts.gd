extends Node3D
## Playable carts close to the village start and on the Government House approach.
const Startup = preload("res://systems/world_startup.gd")
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const VillageCart = preload("res://vehicles/horse_cart_candidate.gd")
const FamilyCart = preload("res://vehicles/family_carriage_candidate.gd")
var layout := Layout.new()

func _ready() -> void:
	var startup_task := Startup.begin("Live carts")
	await Startup.checkpoint(self, "Preparing Suryagarh’s travellers…", true)
	_place("VillagePassengerEkka", VillageCart.new(), Vector2(-243.0, 207.0), PI)
	await Startup.checkpoint(self, "Preparing Suryagarh’s carriages…")
	var goods: Node3D = VillageCart.new()
	goods.variant = 1
	_place("VillageGoodsCart", goods, Vector2(-273.0, 183.0), PI)
	await Startup.checkpoint(self, "Preparing Suryagarh’s carriages…")
	_place("GovernmentHouseFamilyCarriage", FamilyCart.new(), Vector2(-265.0, -18.0), PI * .5)
	await Startup.checkpoint(self, "Preparing Suryagarh’s carriages…")
	_place("VillageBullockCart",preload("res://vehicles/bullock_cart.gd").new(),Vector2(-403,225),PI*.5)
	await Startup.checkpoint(self, "Preparing Suryagarh’s carriages…")
	var freight:=preload("res://vehicles/bullock_cart.gd").new()
	_place("RoadBullockFreight",freight,Vector2(-416,230),-PI*.5)
	await Startup.checkpoint(self, "Preparing Suryagarh’s carriages…")
	var journey:=preload("res://vehicles/bullock_road_journey.gd").new();journey.name="RoadJourney";journey.configure(freight);freight.add_child(journey)
	Startup.finish(startup_task)

func _place(label: String, cart: Node3D, at: Vector2, heading: float) -> void:
	cart.name = label
	cart.position = Vector3(at.x, layout.height(at.x, at.y), at.y)
	cart.rotation.y = heading
	add_child(cart)
	cart.add_to_group("live_travel_carts")

	cart.add_to_group("cart_parking_vehicles")
	var bay := preload("res://vehicles/cart_parking_bay.gd").new()
	bay.name = label + "Parking"
	add_child(bay)
	bay.configure(cart, label.capitalize() + " Parking")
	cart.set_meta("booking_status", "public")
