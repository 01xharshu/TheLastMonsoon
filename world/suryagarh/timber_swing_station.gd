extends Node3D
## Timber crossbars over a short practice approach to a low masonry platform.
const Timber := Color(.28, .16, .085)
const Stone := Color(.38, .32, .25)

func _ready() -> void:
	for offset in [0.0, 3.2]:
		var anchor := Node3D.new()
		anchor.name = "TimberSwingBar"
		anchor.position = Vector3(0, 2.60 + offset * .04, offset)
		add_child(anchor)
		anchor.add_to_group("traversal_swing_bars")
		var log_mesh := CylinderMesh.new()
		log_mesh.top_radius = .065
		log_mesh.bottom_radius = .075
		log_mesh.height = 2.7
		log_mesh.radial_segments = 10
		var collider := CylinderShape3D.new()
		collider.radius = .075
		collider.height = 2.7
		var bar := _part(anchor, log_mesh, collider, Vector3.ZERO, Timber)
		bar.rotation.z = PI * .5
		for side in [-1, 1]:
			var x: float = side * 1.29
			_box(self, Vector3(x, 1.25, offset), Vector3(.23, 2.95, .23), Timber)
			_box(self, Vector3(x, .20, offset), Vector3(.48, .50, .48), Stone)
			for band in [-.08, 0.0, .08]:
				_box(anchor, Vector3(x + band, 0, 0), Vector3(.055, .17, .17), Color(.43,.31,.16))
	var platform := _box(self, Vector3(0, 1.09, 7.0), Vector3(3.0, 2.26, 2.4), Stone.darkened(.24))
	for row in 7:
		for column in 6:
			var width := .46 if row % 2 == 0 else .38
			var x := (column - 2.5) * .49 + (.035 if row % 2 else -.025)
			var tone := Stone.lightened(float((row * 13 + column * 7) % 9) * .017)
			var block := MeshInstance3D.new()
			var shape := BoxMesh.new()
			shape.size = Vector3(width, .284, .025)
			block.mesh = shape
			var material := StandardMaterial3D.new()
			material.albedo_color = tone
			material.roughness = 1.0
			block.material_override = material
			block.position = Vector3(x, -.93 + row * .305, -1.205)
			platform.add_child(block)

func _box(parent: Node3D, center: Vector3, size: Vector3, tint: Color) -> StaticBody3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var shape := BoxShape3D.new()
	shape.size = size
	return _part(parent, mesh, shape, center, tint)

func _part(parent: Node3D, mesh: Mesh, shape: Shape3D, center: Vector3, tint: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = .94
	visual.material_override = material
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body
