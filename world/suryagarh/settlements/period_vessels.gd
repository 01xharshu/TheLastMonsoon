extends RefCounted
## Original turned profiles for ordinary water storage and serving.
const PROFILES = {
	"lota": [Vector2(0,0), Vector2(.075,0), Vector2(.105,.035), Vector2(.128,.095), Vector2(.119,.145), Vector2(.078,.183), Vector2(.058,.203), Vector2(.069,.226), Vector2(.064,.232), Vector2(.054,.226), Vector2(.047,.198), Vector2(.063,.173), Vector2(.108,.14), Vector2(.115,.095), Vector2(.091,.044), Vector2(0,.018)],
	"matka": [Vector2(0,0), Vector2(.115,0), Vector2(.179,.053), Vector2(.216,.158), Vector2(.208,.248), Vector2(.164,.319), Vector2(.108,.349), Vector2(.103,.378), Vector2(.12,.389), Vector2(.12,.402), Vector2(.099,.402), Vector2(.086,.366), Vector2(.098,.337), Vector2(.146,.307), Vector2(.189,.242), Vector2(.196,.156), Vector2(.153,.066), Vector2(0,.023)],
	"dish": [Vector2(0,0), Vector2(.084,0), Vector2(.14,.017), Vector2(.169,.051), Vector2(.164,.06), Vector2(.151,.052), Vector2(.124,.029), Vector2(0,.018)],
}
var meshes: Dictionary = {}
var brass := StandardMaterial3D.new()
var clay := StandardMaterial3D.new()

func _init() -> void:
	brass.albedo_color = Color(.48,.34,.14)
	brass.metallic = .7
	brass.roughness = .48
	clay.albedo_color = Color(.65,.34,.21)
	clay.albedo_texture = preload("res://assets/architecture/materials/clay_plaster_Diffuse.jpg")
	clay.roughness = .93

func place(parent: Node3D, form: String, at: Vector3, size := 1.0, earthen := false) -> void:
	if not meshes.has(form):
		meshes[form] = turn_profile(PROFILES[form])
	var vessel := MeshInstance3D.new()
	vessel.name = form.capitalize()
	vessel.mesh = meshes[form]
	vessel.material_override = clay if earthen else brass
	vessel.position = at
	vessel.scale = Vector3.ONE * size
	vessel.visibility_range_end = 95
	vessel.visibility_range_end_margin = 12
	parent.add_child(vessel)

func turn_profile(profile: Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector2i(0,0), Vector2i(0,1), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1), Vector2i(1,0)]
	for row in profile.size() - 1:
		for segment in 32:
			for corner: Vector2i in corners:
				var point: Vector2 = profile[row + corner.x]
				var fraction := float(segment + corner.y) / 32.0
				var angle := fraction * TAU
				surface.set_uv(Vector2(fraction, point.y * 2.4))
				surface.add_vertex(Vector3(cos(angle) * point.x, point.y, sin(angle) * point.x))
	surface.generate_normals()
	surface.index()
	return surface.commit()

func place_balance(parent: Node3D, at: Vector3) -> void:
	var props = preload("res://world/suryagarh/settlements/activity_props.gd")
	var balance := Node3D.new()
	balance.name = "MerchantBeamBalance"
	balance.position = at
	parent.add_child(balance)
	var wood := props.material(Color(.24,.14,.075))
	var cord := props.material(Color(.39,.29,.17))
	props.box(balance, "Foot", Vector3(0,.035,0), Vector3(.4,.07,.38), wood)
	props.box(balance, "Upright", Vector3(0,.49,.14), Vector3(.055,.91,.055), wood)
	props.box(balance, "PivotArm", Vector3(0,.92,.07), Vector3(.05,.045,.19), wood)
	props.box(balance, "EqualArms", Vector3(0,.86,0), Vector3(1.02,.03,.026), brass)
	props.cylinder(balance, "Pivot", Vector3(0,.89,0), .022,.07,brass)
	for side in [-1.0,1.0]:
		var x: float = side * .48
		place(balance, "dish", Vector3(x,.37,0), 1.05)
		for i in 3:
			var angle := TAU * float(i) / 3.0
			var from := Vector3(x,.86,0)
			var to := Vector3(x + cos(angle)*.158,.426,sin(angle)*.158)
			var string := props.cylinder(balance, "PanCord", (from+to)*.5, .004, from.distance_to(to), cord)
			string.quaternion = Quaternion(Vector3.UP,(to-from).normalized())
	for i in 3:
		props.cylinder(balance, "LooseWeight", Vector3(.33+i*.11,.025,.2), .047-i*.009,.05,brass)
	for visual: MeshInstance3D in balance.find_children("*","MeshInstance3D",true,false):
		visual.visibility_range_end = 95
		visual.visibility_range_end_margin = 12
