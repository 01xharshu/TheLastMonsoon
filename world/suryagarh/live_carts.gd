extends Node3D
## Playable carts close to the village start and on the Government House approach.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const VillageCart = preload("res://vehicles/horse_cart_candidate.gd")
const FamilyCart = preload("res://vehicles/family_carriage_candidate.gd")
var layout := Layout.new()

func _ready() -> void:
	_place("VillagePassengerEkka", VillageCart.new(), Vector2(-243.0, 207.0), PI)
	var goods: Node3D = VillageCart.new()
	goods.variant = 1
	_place("VillageGoodsCart", goods, Vector2(-273.0, 183.0), PI)
	_place("GovernmentHouseFamilyCarriage", FamilyCart.new(), Vector2(-265.0, -18.0), PI * .5)

func _place(label: String, cart: Node3D, at: Vector2, heading: float) -> void:
	cart.name = label
	cart.position = Vector3(at.x, layout.height(at.x, at.y), at.y)
	cart.rotation.y = heading
	add_child(cart)
