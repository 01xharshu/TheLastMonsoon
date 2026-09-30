extends "res://world/suryagarh/settlements/supply_pickup.gd"
## One collectible cloth dressing; original mesh, persistent building supply.
var supply_id := ""

func persistence_id() -> String:
	return supply_id

func _ready() -> void:
	item_id = "medkit"
	count = 1
	display_name = "Bandage"
	super._ready()
	marker_height = 0.08
	add_to_group("medical_supplies")
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.78,0.73,0.61)
	cloth.roughness = 0.98
	var roll := CylinderMesh.new()
	roll.top_radius = 0.055
	roll.bottom_radius = 0.055
	roll.height = 0.13
	roll.radial_segments = 20
	var visual := MeshInstance3D.new()
	visual.mesh = roll
	visual.material_override = cloth
	visual.rotation.z = PI / 2
	visual.position.y = 0.055
	add_child(visual)
	for x in [-0.045,-0.015,0.015,0.045]:
		var seam := TorusMesh.new()
		seam.inner_radius = 0.053
		seam.outer_radius = 0.057
		seam.rings = 12
		seam.ring_segments = 8
		var winding := MeshInstance3D.new()
		winding.mesh = seam
		winding.material_override = cloth
		winding.rotation.z = PI / 2
		winding.position = Vector3(x,0.055,0)
		add_child(winding)
	var loose := MeshInstance3D.new()
	var strip := BoxMesh.new()
	strip.size = Vector3(0.10,0.004,0.14)
	loose.mesh = strip
	loose.material_override = cloth
	loose.position = Vector3(0.07,0.003,0.07)
	add_child(loose)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.24,0.12,0.24)
	collision.shape = shape
	collision.position.y = 0.06
	add_child(collision)

static func furnish(builder: Node3D, parent: Node3D, center: Vector3, id: String) -> void:
	builder.piece(parent,"MedicalShelf",center+Vector3(0,0.95,0),Vector3(0.65,0.08,0.5),builder.wood)
	for x in [-0.25,0.25]:
		for z in [-0.18,0.18]:
			builder.piece(parent,"MedicalShelfLeg",center+Vector3(x,0.46,z),Vector3(0.07,0.92,0.07),builder.wood)
	var pickup = load("res://world/suryagarh/settlements/medical_supply.gd").new()
	pickup.name = "BandageSupply"
	pickup.supply_id = id
	pickup.position = center + Vector3(0,0.991,0)
	parent.add_child(pickup)
