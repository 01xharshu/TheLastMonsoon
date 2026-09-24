extends StaticBody3D
## The lower timber remains planted while the severed upper pole carries its flag down.
var cut := false
var cloth: Node3D
var rope: Node3D
var fallen_top: RigidBody3D
const CUT_HEIGHT := 2.25

func _ready() -> void:
	add_to_group("cuttable_flags")

func bind_visual() -> void:
	cloth = find_child("eic_flag_cloth", true, false)
	rope = find_child("eic_flagpole_rope", true, false)

func cut_flag() -> bool:
	if cut: return false
	cut = true
	var timber: MeshInstance3D = find_child("eic_flagpole_timber",true,false)
	if timber == null: return true
	var scale_factor: float = timber.global_basis.y.length()
	var timber_material: Material = timber.mesh.surface_get_material(0)
	var stump := MeshInstance3D.new()
	stump.name = "BrokenPoleStump"
	var stump_mesh := CylinderMesh.new()
	stump_mesh.top_radius = .055*scale_factor
	stump_mesh.bottom_radius = .055*scale_factor
	stump_mesh.height = CUT_HEIGHT*scale_factor
	stump_mesh.material = timber_material
	stump.mesh = stump_mesh
	add_child(stump)
	stump.global_position = global_position+Vector3.UP*stump_mesh.height*.5
	fallen_top = RigidBody3D.new()
	fallen_top.name = "FallenFlagTop"
	fallen_top.mass = 5.0
	fallen_top.collision_layer = 1
	fallen_top.collision_mask = 1
	get_parent().add_child(fallen_top)
	fallen_top.global_position = global_position+Vector3.UP*(CUT_HEIGHT+1.125)*scale_factor
	var upper := MeshInstance3D.new()
	upper.name = "BrokenPoleUpper"
	var upper_mesh := CylinderMesh.new()
	upper_mesh.top_radius = .055*scale_factor
	upper_mesh.bottom_radius = .055*scale_factor
	upper_mesh.height = (4.5-CUT_HEIGHT)*scale_factor
	upper_mesh.material = timber_material
	upper.mesh = upper_mesh
	fallen_top.add_child(upper)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = .07*scale_factor
	shape.height = upper_mesh.height
	collision.shape = shape
	fallen_top.add_child(collision)
	for name in ["eic_flag_cloth","eic_flagpole_finial","eic_flagpole_rope"]:
		var original: Node3D = find_child(name,true,false)
		if original == null: continue
		var copy: Node3D = original.duplicate()
		var original_transform := original.global_transform
		fallen_top.add_child(copy)
		copy.global_transform = original_transform
		original.hide()
	for shape_node in get_children():
		if shape_node is CollisionShape3D:
			shape_node.position.y = stump_mesh.height*.5
			var stump_shape := CylinderShape3D.new()
			stump_shape.radius = .085*scale_factor
			stump_shape.height = stump_mesh.height
			shape_node.shape = stump_shape
	timber.hide()
	fallen_top.apply_impulse(Vector3(.8,0,.6)*fallen_top.mass)
	fallen_top.apply_torque_impulse(Vector3(0,0,1.8)*fallen_top.mass)
	return true
