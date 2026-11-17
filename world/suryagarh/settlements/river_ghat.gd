extends RefCounted
## Small village river access: retained earth route, stone working edges and shade.
const Trees = preload("res://world/suryagarh/tree_variety.gd")

static func build(owner: Node3D, shore: Vector3, layout: RefCounted) -> void:
	var root := Node3D.new()
	root.name = "PrivateRiverGhat"
	owner.add_child(root)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(.40,.37,.30)
	stone.roughness = .98
	var reed := ShaderMaterial.new()
	reed.shader = preload("res://world/suryagarh/settlements/ghat_reed.gdshader")
	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color(.23,.16,.09)
	timber.roughness = .98
	# These are working edges beside the access, never a deck over the river.
	for side in [-1.0,1.0]:
		for index in 5:
			var x := shore.x-2.0-float(index)*1.25
			var z: float = shore.z+side*3.25
			var height: float = layout.height(x,z)
			block(root,"WornStoneEdge",Vector3(x,height+.10,z),Vector3(1.15,.20,.75),stone)
		# Opaque woven reed screens back up foliage at eye level; trees alone
		# have open trunks. Central 4.4m swept access remains unchanged.
		for index in 6:
			var x := shore.x-2.0-float(index)*2.0
			var z: float = shore.z+side*4.7
			var height: float = maxf(layout.height(x-1.0,z),layout.height(x+1.0,z))
			block(root,"WovenReedPrivacy",Vector3(x,height+1.05,z),Vector3(2.03,2.10,.065),reed)
			for end in [-1.0,1.0]:
				block(root,"ScreenTimberPost",Vector3(x+end*.97,height+1.12,z),Vector3(.08,2.35,.08),timber)
			for rail in [.20,.95,1.75]:
				block(root,"ScreenWovenRail",Vector3(x,height+rail,z-side*.045),Vector3(2.0,.035,.025),timber,false)
	# Reuse shared tree geometry/LOD. All roots sit on the actual bank, outside
	# the route and work lanes; a single physical owner retains trunk collision.
	var mesh: Mesh = Trees.mesh_for("young")
	var profile: Array[Dictionary] = Trees.profile_for(mesh)
	if profile.is_empty():
		push_error("River ghat shade tree has no trunk profile")
		return
	var base: Vector3 = profile[0].centre-Vector3.UP*float(profile[0].height)*.5
	var batch := MultiMeshInstance3D.new()
	batch.name = "GhatShadeTrees"
	batch.visibility_range_end = 240.0
	batch.visibility_range_end_margin = 20.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 8
	batch.multimesh = mm
	root.add_child(batch)
	var transforms: Array[Transform3D] = []
	for index in 8:
		var side := -1.0 if index<4 else 1.0
		var x := shore.x-2.0-float(index%4)*4.0
		var z := shore.z+side*6.4
		var scale_factor := 5.8/maxf(mesh.get_aabb().size.y,.1)
		var basis := Basis(Vector3.UP,float(index)*1.7).scaled(Vector3.ONE*scale_factor)
		var at := Transform3D(basis,Vector3(x,layout.height(x,z)-.06,z)-basis*base)
		mm.set_instance_transform(index,at)
		transforms.append(at)
	var body := StaticBody3D.new()
	body.name = "ShadeTreeTrunks"
	root.add_child(body)
	Trees.append_trunks(body,transforms,profile,{})
	root.set_meta("adult_river_activity_site",true)
	root.set_meta("bathing_implemented",true)

static func block(root: Node3D, label: String, at: Vector3, size: Vector3, material: Material, solid := true) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	root.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		mesh.add_child(body)
