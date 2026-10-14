extends Node3D
## Actual workplace builders without unrelated story/forest startup owners.
var site:="port"
var complete:=false

class Port extends "res://world/suryagarh/hooghly_port.gd":
	func _ready()->void:
		wood=aged_surface(Color(.43,.34,.23),0.0);stone=aged_surface(Color(.40,.37,.30),4.0)
		plaster=aged_surface(Color(.66,.59,.44),4.0);roof_tile=aged_surface(Color(.38,.23,.14),4.0)
		iron=material(Color(.09,.10,.09));rope_material=material(Color(.25,.22,.15))
		build_quay()
	func _physics_process(_delta:float)->void:pass
	func _process(_delta:float)->void:pass

class Market extends "res://world/suryagarh/settlements/urban_west.gd":
	func _ready()->void:
		b.plaster=b.material(Color(.76,.69,.56));b.wood=b.material(Color(.26,.16,.09))
		b.stone=b.material(Color(.49,.43,.34));b.tile=b.material(Color(.43,.24,.15));b.ochre=b.material(Color(.67,.48,.29))
		market();set_process(false)

class Home extends "res://world/suryagarh/settlements/wealthy_households.gd":
	func _ready()->void:
		plaster=material(Color(.83,.77,.64));wood=material(Color(.25,.14,.08));stone=material(Color(.52,.47,.38))
		tile=material(Color(.47,.24,.14));iron=material(Color(.15,.15,.14));ochre=material(Color(.61,.42,.24))
		var home:=_anchor("MerchantHousehold",Vector3(-420,8,-405),"wealthy_indian")
		_house(home,false);_service(home,Vector3(-11,0,-16));_shelter(home,Vector3(23,0,-24),"ReceivingStore",Vector2(16,8))
		piece(home,"ReceivingStoreRaisedFloor",Vector3(23,.12,-24),Vector3(16,.24,8),stone)
		var span:=Vector3(0,-.24,2);var angle:float=-atan2(span.y,span.z)
		var center:=Vector3(23,.12,-19)-Basis(Vector3.RIGHT,angle).y*.05
		piece(home,"ReceivingStoreRamp",center,Vector3(4,.1,span.length()),stone).rotation.x=angle

func _ready()->void:
	var workplace:Node3D=Port.new() if site=="port" else (Market.new() if site=="market" else Home.new())
	add_child(workplace)
	complete=true
