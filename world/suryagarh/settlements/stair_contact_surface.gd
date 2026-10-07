extends Node3D
## Visible tread support, independent of the capsule's smooth collision ramp.
var run := 24.0
var rise := 4.6
var width := 3.6
var count := 24
var backward := true
var tread_bias := .5
var tread_top := .065

static func add_flight(parent: Node3D, x: float, base: float, length: float, height: float, breadth: float, steps: int, toward_back: bool, bias: float, top: float, wood: Material) -> void:
	var surface = load("res://world/suryagarh/settlements/stair_contact_surface.gd").new()
	surface.name = "StairContactSurface"
	surface.position = Vector3(x, base, 0)
	surface.run = length
	surface.rise = height
	surface.width = breadth
	surface.count = steps
	surface.backward = toward_back
	surface.tread_bias = bias
	surface.tread_top = top
	parent.add_child(surface)
	surface.add_to_group("stair_contact_surfaces")
	for side in [-1.0, 1.0]:
		var stringer := MeshInstance3D.new()
		stringer.name = "StairStringer"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(.12, .28, sqrt(length * length + height * height))
		stringer.mesh = mesh
		stringer.material_override = wood
		stringer.position = Vector3(side * (breadth * .5 - .06), height * .5 - .13, 0)
		stringer.rotation.x = atan2(height, length) * (1.0 if toward_back else -1.0)
		surface.add_child(stringer)

func support(world: Vector3) -> Vector3:
	var local := to_local(world)
	if absf(local.x) > width * .5 or absf(local.z) > run * .5 or local.y < -.4 or local.y > rise + .6:
		return Vector3(INF, INF, INF)
	var distance := run * .5 - local.z if backward else local.z + run * .5
	var index := clampi(floori(distance / run * count), 0, count - 1)
	local.y = rise * (index + tread_bias) / count + tread_top
	return to_global(local)
