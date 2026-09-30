extends RefCounted
## Original small meshes: paper charges, lead balls and percussion-cap tin.
static func material(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = 0.8 if metallic == 0.0 else 0.55
	return result

static func mesh(parent: Node3D, label: String, shape: Mesh, position: Vector3, surface: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = shape
	node.position = position
	node.material_override = surface
	parent.add_child(node)
	return node

static func build_packet(parent: Node3D, ammo_id: String) -> void:
	var paper := material(Color(0.72, 0.63, 0.44))
	var lead := material(Color(0.28, 0.29, 0.30), 0.55)
	var brass := material(Color(0.51, 0.34, 0.13), 0.7)
	var tray := BoxMesh.new()
	tray.size = Vector3(0.34, 0.018, 0.23)
	mesh(parent, "FoldedPaperTray", tray, Vector3(0, 0.009, 0), paper)
	for row in 2:
		for column in 4:
			var position := Vector3(-0.105 + column * 0.07, 0.03, -0.055 + row * 0.11)
			if ammo_id == "pistol_ball":
				var ball := SphereMesh.new()
				ball.radius = 0.006
				ball.height = 0.012
				ball.radial_segments = 12
				ball.rings = 6
				position.y = 0.024
				mesh(parent, "LeadBall", ball, position, lead)
			else:
				var charge := CylinderMesh.new()
				charge.top_radius = 0.010 if ammo_id == "paper_cartridges" else 0.014
				charge.bottom_radius = charge.top_radius
				charge.height = 0.072
				charge.radial_segments = 10
				mesh(parent, "PaperCharge", charge, position, paper).rotation.x = PI * 0.5
				var fold := BoxMesh.new()
				fold.size = Vector3(0.016, 0.009, 0.010)
				mesh(parent, "FoldedSeal", fold, position + Vector3(0, 0, 0.04), paper)
	var tin := CylinderMesh.new()
	tin.top_radius = 0.033
	tin.bottom_radius = 0.033
	tin.height = 0.016
	tin.radial_segments = 16
	mesh(parent, "PercussionCapTin", tin, Vector3(0.15, 0.032, 0.065), brass)

static func furnish(builder: Node3D, parent: Node3D, center: Vector3, prefix: String) -> void:
	builder.piece(parent, "AmmunitionCounter", center + Vector3(0, 0.95, 0), Vector3(2.0, 0.12, 0.75), builder.wood)
	for x in [-0.85, 0.85]:
		for z in [-0.28, 0.28]:
			builder.piece(parent, "AmmunitionCounterLeg", center + Vector3(x, 0.46, z), Vector3(0.12, 0.92, 0.12), builder.wood)
	var entries := [["paper_cartridges", "Paper cartridges", 24], ["pistol_ball", "Lead balls and caps", 30], ["shot_charge", "Shot charges", 16]]
	for i in entries.size():
		var pickup := preload("res://world/suryagarh/settlements/ammunition_pickup.gd").new()
		pickup.name = "Ammo_" + entries[i][0]
		pickup.item_id = entries[i][0]
		pickup.display_name = entries[i][1]
		pickup.count = entries[i][2]
		pickup.supply_id = prefix + "/" + entries[i][0]
		pickup.position = center + Vector3(-0.62 + i * 0.62, 1.012, 0)
		parent.add_child(pickup)
		build_packet(pickup, pickup.item_id)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.38, 0.12, 0.27)
		collision.shape = shape
		collision.position.y = 0.06
		pickup.add_child(collision)
