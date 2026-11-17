extends RefCounted
## Shared repair/milk handcart, open baltis and ordinary workshop furnishings.
static func material(color: Color, metal := 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new();result.albedo_color=color
	result.roughness=.85;result.metallic=metal
	return result

static func box(parent: Node3D, label: String, at: Vector3, size: Vector3, mat: Material, solid := false) -> Node3D:
	var node := MeshInstance3D.new();node.name=label;node.position=at
	var mesh := BoxMesh.new();mesh.size=size;node.mesh=mesh;node.material_override=mat
	parent.add_child(node)
	if solid:
		var body := StaticBody3D.new();var shape := CollisionShape3D.new();var volume := BoxShape3D.new()
		volume.size=size;shape.shape=volume;body.add_child(shape);node.add_child(body)
	return node

static func cylinder(parent: Node3D, label: String, at: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new();node.name=label;node.position=at
	var mesh := CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=24
	node.mesh=mesh;node.material_override=mat;parent.add_child(node);return node

static func cart(parent: Node3D, label: String) -> Node3D:
	var root := Node3D.new();root.name=label;parent.add_child(root)
	root.set_meta("cart_design","village_wooden_handcart_v1")
	var wood := material(Color(.28,.17,.08));var iron := material(Color(.14,.13,.12),.6)
	for plank in 7:box(root,"DeckPlank",Vector3(-.54+plank*.18,.72,0),Vector3(.17,.10,1.60),wood)
	for side in [-1.0,1.0]:
		box(root,"LongSide",Vector3(side*.64,.91,0),Vector3(.07,.26,1.68),wood)
		box(root,"Handle",Vector3(side*.46,1.0,-1.30),Vector3(.07,.08,1.5),wood)
		var wheel := Node3D.new();wheel.name="WheelLeft" if side<0 else "WheelRight"
		wheel.position=Vector3(side*.78,.47,.20);root.add_child(wheel)
		var rim := TorusMesh.new();rim.inner_radius=.40;rim.outer_radius=.47;rim.rings=24;rim.ring_segments=8
		var ring := MeshInstance3D.new();ring.mesh=rim;ring.rotation.z=PI*.5;ring.material_override=wood;wheel.add_child(ring)
		for spoke in 10:
			var beam := box(wheel,"Spoke",Vector3.ZERO,Vector3(.05,.87,.035),wood)
			beam.rotation.x=float(spoke)*PI/10.0
		var hub := cylinder(wheel,"Hub",Vector3.ZERO,.10,.24,wood);hub.rotation.z=PI*.5
	box(root,"Axle",Vector3(0,.47,.20),Vector3(1.8,.09,.09),iron)
	box(root,"RestingLeg",Vector3(0,.32,-.62),Vector3(.09,.64,.09),wood)
	var body := AnimatableBody3D.new();body.name="CartBody";body.sync_to_physics=false
	var collision := CollisionShape3D.new();var volume := BoxShape3D.new();volume.size=Vector3(1.9,1.2,2.0)
	collision.shape=volume;collision.position=Vector3(0,.60,0);body.add_child(collision);root.add_child(body)
	return root

static func balti(parent: Node3D, at: Vector3) -> Node3D:
	var root := Node3D.new();root.name="MilkBalti";root.position=at;root.set_meta("milk_balti",true);parent.add_child(root)
	var metal := material(Color(.43,.42,.38),.65)
	var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Open tapered metal vessel, including inner wall and a closed base.
	var profile := [Vector2(.12,0),Vector2(.17,.33),Vector2(.158,.33),Vector2(.108,.018),Vector2(0,.018),Vector2(0,0)]
	for row in profile.size()-1:
		for segment in 32:
			for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
				var p: Vector2=profile[row+corner.x];var angle:=float(segment+corner.y)*TAU/32.0
				st.add_vertex(Vector3(cos(angle)*p.x,p.y,sin(angle)*p.x))
	st.generate_normals();var mesh:=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=metal;root.add_child(mesh)
	var milk:=cylinder(root,"MilkSurface",Vector3(0,.27,0),.15,.008,material(Color(.84,.81,.69)))
	milk.set_meta("milk",true)
	var handle:=TorusMesh.new();handle.inner_radius=.17;handle.outer_radius=.18;handle.rings=24;handle.ring_segments=6
	var hoop:=MeshInstance3D.new();hoop.name="BaltiHandle";hoop.mesh=handle;hoop.rotation.x=PI*.5;hoop.position.y=.31;hoop.material_override=metal;root.add_child(hoop)
	return root
