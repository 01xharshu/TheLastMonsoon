extends RefCounted
## Arjun and Dev's modest home, within an existing surveyed village footprint.
func furnish(b, home: Node3D) -> void:
	home.add_to_group("arjun_home")
	home.set_meta("residents", ["Arjun", "Dev"])
	home.set_meta("story", "Dev raised Arjun after their parents died early; Dev serves as a sepoy.")
	for node in home.get_children():
		if str(node.name).begins_with("Sleeping") or str(node.name) in ["CookingHearth","HearthOpening","CookingPot","StorageChest","ChestLid"]: node.free()
	# Open the sleeping-room shutter so Arjun can actually look outside.
	# Apply before the village batches static meshes; preserve the other shutters.
	for frame in home.get_children():
		if not str(frame.name).begins_with("TimberWindowFrame") or frame.position.x >= 0: continue
		var shutters := frame.get_node_or_null("PairedWoodShutters")
		if shutters != null:
			shutters.opened=true
			shutters.swing=1.0
			shutters.night_lock=false
			shutters.auto_open_at_dawn=true
	home.set_meta("sleeping_window", "open outward")
	var lime: Material = surface(Color(0.73,0.68,0.55),0)

	# Front sleeping-room aperture overlooks the southern approach.
	for node in home.get_children():
		if str(node.name).begins_with("DoorPier") and node.position.x < 0: node.free()
	b.piece(home,"ApproachWindowSill",Vector3(-3.025,0.82,3.6),Vector3(3.45,1.16,0.38),lime)
	b.piece(home,"ApproachWindowHead",Vector3(-3.025,2.65,3.6),Vector3(3.45,0.78,0.38),lime)
	b.piece(home,"ApproachWindowOuterPier",Vector3(-4.5,1.83,3.6),Vector3(0.5,0.86,0.38),lime)
	b.piece(home,"ApproachWindowInnerPier",Vector3(-1.875,1.83,3.6),Vector3(1.15,0.86,0.38),lime)
	for x in [-4.23,-2.48]:
		b.piece(home,"ApproachWindowJamb",Vector3(x,1.83,3.82),Vector3(0.08,0.94,0.10),b.wood,false)
	for y in [1.4,2.26]:
		b.piece(home,"ApproachWindowRail",Vector3(-3.35,y,3.82),Vector3(1.83,0.08,0.10),b.wood,false)
	var window := Marker3D.new()
	window.name = "BrotherApproachWindow"
	home.add_child(window)
	window.position = Vector3(-3.35,1.86,3.6)
	home.set_meta("brother_approach_start", Vector2(-339.65,204))
	home.set_meta("brother_approach_end", Vector2(-326,30))
	_build_brother_approach(b,home)
	var earth: Material = surface(Color(0.40,0.31,0.21),3)
	var cloth: Material = surface(Color(0.49,0.43,0.30),2)
	var timber: Material = surface(Color(0.27,0.16,0.09),1)
	# Replace the generic grey grid finish; keep all surveyed collision surfaces.
	for node in home.get_children():
		var mesh: MeshInstance3D = node if node is MeshInstance3D else (node.get_child(0) as MeshInstance3D if node.get_child_count() > 0 else null)
		if mesh == null: continue
		var label := str(node.name)
		if label.begins_with("Plinth") or label.begins_with("ThresholdStep"):
			mesh.material_override = surface(Color(0.43,0.34,0.25),3)
		elif label.begins_with("BackWall") or label.begins_with("Window") and not label.begins_with("WindowFrame") or label.begins_with("DoorPier") or label.begins_with("DoorLintel"):
			mesh.material_override = surface(Color(0.65,0.56,0.40),0)
	# A sleeping alcove and cooking/storage room share a 1.5 m internal opening.
	b.piece(home,"AlcovePartitionRear",Vector3(0,1.44,-2.55),Vector3(0.18,2.4,1.8),lime)
	b.piece(home,"AlcovePartitionFront",Vector3(0,1.44,1.25),Vector3(0.18,2.4,2.7),lime)
	b.piece(home,"AlcoveLintel",Vector3(0,2.64,-0.75),Vector3(0.18,0.4,1.5),b.wood)
	# Dev's bedding is rolled during the day, leaving the central aisle open.
	b.piece(home,"DevBeddingMat",Vector3(2.5,0.255,-1.45),Vector3(1.55,0.025,2.2),cloth,false)
	var quilt := MeshInstance3D.new()
	quilt.name = "RolledQuilt"
	var roll := CylinderMesh.new()
	roll.top_radius = 0.16
	roll.bottom_radius = 0.16
	roll.height = 1.35
	roll.radial_segments = 24
	quilt.mesh = roll
	quilt.material_override = cloth
	quilt.rotation.z = PI/2
	quilt.position = Vector3(2.5,0.425,-2.35)
	home.add_child(quilt)
	for x in [1.95,3.05]:
		b.piece(home,"QuiltTie",Vector3(x,0.578,-2.35),Vector3(0.045,0.015,0.08),b.wood,false)
	for z in [-2.48,-0.42]:
		b.piece(home,"MatBoundEdge",Vector3(2.5,0.275,z),Vector3(1.55,0.012,0.045),surface(Color(0.30,0.22,0.15),2),false)
	b.piece(home,"StorageChest",Vector3(3.65,0.52,1.15),Vector3(1.15,0.56,0.68),timber)
	b.piece(home,"ChestLid",Vector3(3.65,0.84,1.15),Vector3(1.2,0.08,0.72),timber,false)
	b.piece(home,"ChestLatch",Vector3(3.65,0.70,1.51),Vector3(0.09,0.20,0.04),b.iron,false)
	for x in [3.2,4.1]:
		b.piece(home,"ChestIronBand",Vector3(x,0.85,1.15),Vector3(0.05,0.025,0.74),b.iron,false)
	for y in [0.39,0.57,0.75]:
		b.piece(home,"ChestBoardSeam",Vector3(3.65,y,1.494),Vector3(1.09,0.008,0.012),b.iron,false)
	for x in [3.21,4.09]:
		for y in [0.39,0.74]:
			b.piece(home,"ChestForgedNail",Vector3(x,y,1.50),Vector3(0.022,0.022,0.016),b.iron,false)
	for z in [-1.65,-0.55]:
		b.piece(home,"ShelfWallBracket",Vector3(4.42,1.26,z),Vector3(0.30,0.30,0.09),timber,false)
	for z in [-2.70,0.9]:
		b.piece(home,"PartitionSkirting",Vector3(0.11,0.35,z),Vector3(0.06,0.20,1.45),surface(Color(0.48,0.43,0.33),0),false)
	b.piece(home,"CookingHearth",Vector3(3.65,0.43,-2.65),Vector3(1.1,0.38,0.8),surface(Color(0.37,0.25,0.16),3))
	b.piece(home,"HearthSmokeStain",Vector3(3.65,1.20,-3.402),Vector3(1.15,1.7,0.016),surface(Color(0.40,0.32,0.24),4),false)
	b.piece(home,"HearthAsh",Vector3(3.65,0.63,-2.65),Vector3(0.45,0.02,0.34),b.iron,false)
	b.piece(home,"KitchenShelf",Vector3(4.32,1.45,-1.1),Vector3(0.5,0.10,1.5),b.wood,false)
	for scene_path in ["res://assets/props/polyhaven/brass_pot_01/brass_pot_01_1k.gltf","res://assets/props/polyhaven/wicker_basket_01/wicker_basket_01_1k.gltf"]:
		var prop: Node3D = load(scene_path).instantiate()
		home.add_child(prop)
		prop.position = Vector3(3.7,0.24,-0.8 if "pot" in scene_path else 0.0)
	b.piece(home,"WallPegRail",Vector3(-3.0,1.65,-3.35),Vector3(1.2,0.12,0.08),b.wood,false)
	for x in [-3.45,-3.0,-2.55]:
		b.piece(home,"TimberPeg",Vector3(x,1.65,-3.22),Vector3(0.06,0.06,0.24),b.wood,false)
	b.piece(home,"FoldedBlueCloth",Vector3(-3,1.38,-3.20),Vector3(0.45,0.50,0.06),b.material(Color(0.18,0.23,0.27)),false)
	# Courtyard gate and compacted earth approach meet the existing south lane.
	b.piece(home,"FrontCourtyard",Vector3(0,0.025,6.35),Vector3(9.0,0.05,5.0),earth,false)
	for side in [-1.0,1.0]:
		b.piece(home,"CourtyardLowWall",Vector3(side*4.5,0.47,6.5),Vector3(0.23,0.94,5.4),surface(Color(0.58,0.47,0.32),0))
		b.piece(home,"CourtyardGateWall",Vector3(side*2.9,0.47,9.1),Vector3(3.2,0.94,0.23),surface(Color(0.58,0.47,0.32),0))
	b.piece(home,"HomeToSouthLane",Vector3(0,0.018,16.7),Vector3(2.4,0.035,15.2),earth,false)
	# Timber eaves and veranda joints physically meet existing posts and roof planes.
	for side in [-1.0,1.0]:
		b.piece(home,"EavesWallPlate",Vector3(side*4.73,2.99,0),Vector3(0.18,0.14,7.4),timber,false)
		b.piece(home,"VerandaPostFoot",Vector3(side*4.45,0.15,5.6),Vector3(0.25,0.30,0.25),surface(Color(0.42,0.32,0.22),3),false)
		var brace = b.piece(home,"VerandaKneeBrace",Vector3(side*4.18,2.39,5.6),Vector3(0.13,0.85,0.13),timber,false)
		brace.rotation.z = -side*PI/4
	b.piece(home,"VerandaFrontBeam",Vector3(0,2.70,5.6),Vector3(9.1,0.18,0.19),timber,false)
	for z in [-3.5,3.5]:
		for side in [-1.0,1.0]:
			var rafter = b.piece(home,"RoofGableRafter",Vector3(side*2.375,3.66,z),Vector3(4.94,0.12,0.14),timber,false)
			rafter.rotation.z = -side*0.27
	# Keep a stable world-root Charpai so existing interaction/save references survive.
	var bed: Node3D = b.get_parent().get_node("Charpai")
	bed.global_transform = home.global_transform * Transform3D(Basis.IDENTITY,Vector3(-2.35,0.24,-1.4))
	bed.set_meta("home", "Arjun and Dev")

func surface(color: Color, kind: int) -> Material:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://world/suryagarh/settlements/home_surface.gdshader")
	mat.set_shader_parameter("tint",color)
	mat.set_shader_parameter("kind",kind)
	return mat

func _build_brother_approach(b, home: Node3D) -> void:
	# A narrow, terrain-following footpath joins the south lane and continues
	# between the surveyed houses. It adds no raised slab or terrain flattening.
	var start: Vector2 = home.get_meta("brother_approach_start")
	var finish: Vector2 = home.get_meta("brother_approach_end")
	var side := Vector2(-(finish-start).y,(finish-start).x).normalized()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 87:
		var a := start.lerp(finish,float(i)/87)
		var c := start.lerp(finish,float(i+1)/87)
		var wa := 1.05 + 0.07*sin(float(i)*0.27)
		var wc := 1.05 + 0.07*sin(float(i+1)*0.27)
		for p: Vector2 in [a-side*wa,c-side*wc,a+side*wa,a+side*wa,c-side*wc,c+side*wc]:
			surface.set_uv(Vector2(p.x,p.y)*0.3)
			surface.add_vertex(home.to_local(Vector3(p.x,b.layout.height(p.x,p.y)+0.035,p.y)))
	surface.generate_normals()
	var path := MeshInstance3D.new()
	path.name = "BrotherApproachPath"
	path.mesh = surface.commit()
	var soil := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode cull_back; varying vec3 p; void vertex(){ p=VERTEX; NORMAL=vec3(0.0,1.0,0.0); } void fragment(){ float n=fract(sin(dot(floor(p.xz*34.0),vec2(12.9898,78.233)))*43758.5453); ALBEDO=vec3(0.42,0.27,0.13)*(0.76+0.4*n); ROUGHNESS=1.0; float center=-3.35-0.078448*(p.z-10.0); ALPHA=(1.0-smoothstep(0.88,1.05,abs(p.x-center)))*(1.0-smoothstep(130.0,184.0,p.z)); }"
	soil.shader = shader
	path.material_override = soil
	home.add_child(path)
