extends Node3D
const Startup = preload("res://systems/world_startup.gd")
## Main-world 120 x 100 m ruined hill fort; standalone scene remains available. Z+ is the approach; Z- climbs to the keep.
const WIDTH := 120.0
const DEPTH := 100.0
const SCENERY_MARGIN := 25.0
const GRID := 2.0
const Modules = preload("res://world/ruined_fort/fort_modules.gd")
const Shape = preload("res://world/ruined_fort/fort_shape.gd")
const Landscape = preload("res://world/suryagarh/landscape_layout.gd")
const NAV_FILE := "res://world/ruined_fort/fort_navigation.res"
@export var embedded_in_world := false
@export var force_navigation_rebake := false
var stone := _masonry(Color("a79b84"))
var pale := _masonry(Color("c1b49a"))
var dark_stone := _rock_material(Color("817e72"))
var soil := _mat(Color("968875"))
var rubble_mat := _masonry(Color("b2a38d"))
var wood := _mat(Color("715940"))
var cloth := _mat(Color("aaa08a"))
var grass := _mat(Color("777b54"))
var shrub := _mat(Color("68715a"))
var nodes := {}
var rock_mesh_shared: ArrayMesh
var stone_mesh_shared: ArrayMesh
var masonry_transforms: Array[Transform3D] = []
var nav_ground_faces := PackedVector3Array()
var rng := RandomNumberGenerator.new()
var landscape = Landscape.new()

func _ready() -> void:
	var startup_task := Startup.begin("Fort")
	await Startup.checkpoint(self, "Preparing the countryside…", true)
	rng.seed = 1857
	rock_mesh_shared = Modules.fractured_rock()
	stone_mesh_shared = Modules.chipped_stone()
	for group in ["Terrain", "Architecture", "Cover", "Props", "Vegetation", "Navigation", "Gameplay", "Lighting"]:
		var node := Node3D.new()
		node.name = group
		add_child(node)
		nodes[group] = node
	if not embedded_in_world:
		$Player.reparent(nodes.Gameplay)
		$Sun.reparent(nodes.Lighting)
		$WorldEnvironment.reparent(nodes.Lighting)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("728393")
	sky_material.sky_horizon_color = Color("c7bba5")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	if not embedded_in_world: $Lighting/WorldEnvironment.environment = environment
	_build_terrain()
	await Startup.checkpoint(self, "Preparing the countryside…")
	_build_architecture()
	await Startup.checkpoint(self, "Preparing the countryside…")
	_build_cover()
	await Startup.checkpoint(self, "Preparing the countryside…")
	_build_props()
	await Startup.checkpoint(self, "Preparing the countryside…")
	_build_vegetation()
	await Startup.checkpoint(self, "Preparing the countryside…")
	_finish_masonry()
	await Startup.checkpoint(self, "Preparing the countryside…")
	_build_navigation()
	await Startup.checkpoint(self, "Preparing the countryside…")
	if not force_navigation_rebake:
		var encounter := preload("res://world/ruined_fort/fort_encounter.gd").new()
		encounter.name = "FortEncounter"
		nodes.Gameplay.add_child(encounter)
	if not embedded_in_world: $Gameplay/Player.position = Vector3(0, height_at(0, 47) + 1.1, 47)
	print("RUINED FORT BLOCKOUT READY | 120 x 100 m | three routes | 8 m ascent")
	Startup.finish(startup_task)

func _masonry(color: Color) -> StandardMaterial3D:
	return _weathered_stone(color,0.38)

func _rock_material(color: Color) -> StandardMaterial3D:
	return _weathered_stone(color,0.62)

func _weathered_stone(color: Color, normal_strength: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.albedo_texture = preload("res://assets/nature/materials/rock_boulder_dry_diff_1k.jpg")
	result.normal_enabled = true
	result.normal_texture = preload("res://assets/nature/materials/rock_boulder_dry_nor_gl_1k.jpg")
	result.normal_scale = normal_strength
	result.uv1_triplanar = true
	result.uv1_world_triplanar = true
	result.uv1_scale = Vector3.ONE*.72
	result.roughness = .97
	return result

func _mat(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 1.0
	return result

func height_at(x: float, z: float) -> float:
	return Shape.height_at(x,z)

func _build_terrain() -> void:
	if embedded_in_world and not force_navigation_rebake and ResourceLoader.exists(NAV_FILE):
		_build_cliffs()
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_x: float = WIDTH * 0.5 + (0.0 if embedded_in_world else SCENERY_MARGIN)
	var half_z: float = DEPTH * 0.5 + (0.0 if embedded_in_world else SCENERY_MARGIN)
	for ix in range(int(2.0 * half_x / GRID)):
		for iz in range(int(2.0 * half_z / GRID)):
			var x: float = -half_x + ix * GRID
			var z: float = -half_z + iz * GRID
			var a := Vector3(x, height_at(x,z), z)
			var b := Vector3(x+GRID, height_at(x+GRID,z), z)
			var c := Vector3(x, height_at(x,z+GRID), z+GRID)
			var d := Vector3(x+GRID, height_at(x+GRID,z+GRID), z+GRID)
			for vertex in [a,b,c,b,d,c]:
				surface.add_vertex(vertex)
				if embedded_in_world: nav_ground_faces.append(vertex)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, soil)
	if not embedded_in_world:
		_add_standalone_ground(mesh)
	# Broken cliff chains constrain play while retaining an open entrance.
	_build_cliffs()

func _add_standalone_ground(mesh: Mesh) -> void:
	var body := StaticBody3D.new()
	body.name = "IrregularGround"
	nodes.Terrain.add_child(body)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)

func _build_cliffs() -> void:
	if not embedded_in_world:
		for i in range(-7,8):
			for side in [-1.0,1.0]:
				var zz: float = i * 7.0 + rng.randf_range(-1.3,1.3)
				var xx: float = side * rng.randf_range(59.0,63.0)
				_block("BoundaryCliff", "Terrain", Vector3(xx,height_at(xx,zz)+3.0,zz),Vector3(7.0,6.0,8.2),dark_stone,rng.randf_range(-0.2,0.2))
			if abs(i) > 1:
				for edge in [-1.0,1.0]:
					var xx: float = i * 7.0 + rng.randf_range(-1.3,1.3)
					var zz: float = edge * rng.randf_range(49.5,52.5)
					_block("BoundaryCliff", "Terrain", Vector3(xx,height_at(xx,zz)+3.0,zz),Vector3(8.2,6.0,7.0),dark_stone,rng.randf_range(-0.2,0.2))
	# Tall peripheral rock faces make the additional 25 m read as inaccessible scenery.
	for i in range(14 if embedded_in_world else 36):
		var side: int = i % 4
		var x: float = rng.randf_range(-82,82) if side < 2 else (-70.0 if side == 2 else 70.0)
		var z: float = (-62.0 if side == 0 else 62.0) if side < 2 else rng.randf_range(-64,64)
		var size := Vector3(rng.randf_range(7,15),rng.randf_range(4,10),rng.randf_range(5,11))
		var ground: float = height_at(x,z)
		if embedded_in_world:
			var world_site := to_global(Vector3(x,0,z))
			ground = landscape.height(world_site.x,world_site.z)-global_position.y
		_block("SceneryRidge", "Terrain", Vector3(x,ground+size.y*0.32,z),size,dark_stone,rng.randf_range(-0.45,0.45),false)
func _block(label: String, group: String, at: Vector3, size: Vector3, material: Material, yaw: float = 0.0, collides: bool = true) -> Node3D:
	var body: Node3D = StaticBody3D.new() if collides else Node3D.new()
	body.name = label
	body.position = at
	body.rotation.y = yaw
	nodes[group].add_child(body)
	var visual := MeshInstance3D.new()
	var is_rock: bool = label in ["BoundaryCliff", "SceneryRidge", "RockyRidge", "RockCover"]
	if is_rock:
		visual.mesh = rock_mesh_shared
		visual.scale = size
	elif label in ["Rubble","FallenMasonry","FallenVoussoir","BrokenFloorSlab","ClimbingStone"]:
		visual.mesh = stone_mesh_shared
		visual.scale = size
	else:
		var mesh := BoxMesh.new()
		mesh.size = size
		visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	if collides:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size * (0.78 if label == "RockCover" else 1.0)
		shape.shape = box
		body.add_child(shape)
	return body

func _wall(x: float, z: float, length: float, tall: float, yaw: float = 0.0, damaged: bool = false, thickness:float=.82) -> void:
	var count: int = maxi(2, ceili(length / 2.8))
	var section: float = length / count
	for i in range(count):
		var offset: float = -length * 0.5 + (i + 0.5) * section
		var site: Vector3 = Vector3(x,0,z) + Vector3(offset,0,0).rotated(Vector3.UP,yaw)
		var ground: float = entrance_ground(site.x,site.z) if embedded_in_world and site.z>50.0 else height_at(site.x,site.z)
		var section_height: float = tall
		if damaged:
			section_height *= ([.95,.84,.92,1.0,.88] if embedded_in_world and z>=85.0 else [.91,.58,.76,.98,.67])[i%5]
		if embedded_in_world and site.z>50.0:
			ground-=.42
			section_height+=.42
		var width: float = section - (0.08 if damaged else 0.025)
		var body := _block("DamagedWallStone" if damaged else "WallStone", "Architecture", Vector3(site.x,ground+section_height*0.5,site.z), Vector3(width,section_height,thickness),stone,yaw)
		body.get_child(0).hide()
		if embedded_in_world and damaged and site.z>50.0:
			# The authored fracture mesh owns both the visible wall and its collision.
			body.get_child(1).disabled=true
			_broken_wall_crown(site,ground,tall+.42,section,thickness,yaw)
		elif embedded_in_world:
			var wall_basis:=Basis(Vector3.UP,yaw).scaled_local(Vector3(section-.018,section_height,thickness))
			masonry_transforms.append(Transform3D(wall_basis,body.position))
		else:
			_stone_section(site,ground,width,section_height,yaw)
		if damaged and i % 3 == 1:
			_block("FallenMasonry", "Props", Vector3(site.x+0.8,ground+0.18,site.z+1.1),Vector3(0.7,0.36,0.8),rubble_mat,yaw+0.33,false)

func _broken_wall_crown(site:Vector3,base_y:float,tall:float,width:float,depth:float,yaw:float) -> void:
	# Continuous world-space fracture profile meets across neighbouring sections.
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for piece in 4:
		var points:=PackedVector3Array()
		for z in [-depth*.5,depth*.5]:
			for edge in [piece,piece+1]:
				var x:float=-width*.5+width*float(edge)/4.0
				var sample_at:Vector3=site+Vector3(x,0,0).rotated(Vector3.UP,yaw)
				var top:float=tall*(.86+.09*sin(sample_at.x*.18+sample_at.z*.11)+.08*sin(sample_at.x*.81-sample_at.z*.63))
				points.append(Vector3(x,-.12,z))
				points.append(Vector3(x,top,z))
		for face in [[0,2,3,1],[4,5,7,6],[1,3,7,5],[0,4,6,2],[0,1,5,4],[2,6,7,3]]:
			for vertex in [0,1,2,0,2,3]:surface.add_vertex(points[face[vertex]])
	surface.generate_normals()
	var crown:=MeshInstance3D.new()
	crown.name="FracturedWallCrown"
	crown.mesh=surface.commit()
	crown.material_override=ruin_material()
	crown.position=Vector3(site.x,base_y,site.z)
	crown.rotation.y=yaw
	nodes.Architecture.add_child(crown)
	crown.create_trimesh_collision()

func _arch_block(root: Node3D, label: String, at: Vector3, size: Vector3, material: Material, tilt: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.rotation.z = tilt
	root.add_child(body)
	var visual := MeshInstance3D.new()
	visual.mesh = stone_mesh_shared
	visual.scale = size
	visual.material_override = material
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func _arch(x: float, z: float, yaw: float, variant: int) -> void:
	var root := Node3D.new()
	root.name = ["IntactArch", "DamagedArch", "CollapsedArch"][variant]
	root.position = Vector3(x,height_at(x,z),z)
	root.rotation.y = yaw
	nodes.Architecture.add_child(root)
	for side in [-1.0,1.0]:
		for course in range(5):
			_arch_block(root,"ArchPierStone",Vector3(side*2.55,0.35+course*0.7,0),Vector3(1.0,0.68,1.25),pale if course % 2 else stone)
	for index in range(7):
		if variant == 1 and index == 2: continue
		if variant == 2 and index in [2,3,4]: continue
		var theta: float = PI * index / 6.0
		var at := Vector3(2.0*cos(theta),3.35+2.0*sin(theta),0)
		_arch_block(root,"ArchVoussoir",at,Vector3(0.92,0.9,1.3),pale if index % 2 else stone,theta+PI*0.5)
	if variant > 0:
		_block("FallenVoussoir", "Props", root.position + Vector3(2.0,0.35,1.9), Vector3(1.3,0.7,1.0), rubble_mat, 0.4)

func _stairs(x: float, z: float, count: int, direction: float = -1.0) -> void:
	for i in range(count):
		var zz: float = z + direction * i * 1.15
		var y: float = height_at(x,zz)
		_block("StoneStep", "Architecture", Vector3(x,y+0.1,zz), Vector3(4.3,0.2,1.3), pale)

func _build_architecture() -> void:
	# Outer gate and fragmented eastern/western curtains leave broad silhouette openings.
	if embedded_in_world:
		_build_private_entry()
		_build_entry_galleries()
	# The older inner curtain survives behind the outer entry.
	_arch(0,45,0,0)
	for front in [[-20,45,22,3.2,0.05],[20,45,22,3.6,-0.08],[-42,41,13,2.8,0.12],[43,40,12,3.1,-0.16]]:
		_wall(front[0],front[1],front[2],front[3],front[4],true)
	_arch(0,30,0,1)
	if not embedded_in_world:_arch(-7,4,0,0)
	_arch(8,-21,0,1)
	_arch(-13,-38,0,2)
	_arch(2,-40,0,0)
	for item in [[-31,30,12,3.1,0.3], [23,31,17,4.2,-0.2], [-27,17,11,2.5,-0.4], [28,16,14,3.5,0.24], [-18,8,9,3.1,0.3], [19,5,10,3.7,-0.4], [-25,-10,13,3.8,0.25], [29,-13,10,3.2,-0.28], [-32,-29,17,4.5,0.1], [31,-32,14,4.1,-0.2], [-17,-42,10,3.7,-0.4], [19,-43,13,4.5,0.4]]:
		_wall(item[0],item[1],item[2],item[3],item[4],true)
	# Ruined room fragments and corners; gaps deliberately connect all three routes.
	for base in [Vector2(-24,23),Vector2(25,8),Vector2(-26,-5),Vector2(24,-25),Vector2(-19,-30),Vector2(18,-40)]:
		_wall(base.x,base.y,8,3.4,0,true)
		_wall(base.x+4,base.y-4,7,2.6,PI*0.5,true)
	# Mid-field fragments interrupt long shots while keeping openings between zones.
	for fragment in [[-10,28,7,2.7,0.4],[10,24,6,3.3,-0.6],[-7,14,5,2.4,-0.3],[7,8,8,3.4,0.4],[-15,-3,6,3.0,-0.5],[17,-8,7,2.7,0.3],[-6,-15,8,3.8,0.5],[13,-25,5,3.1,-0.4],[-9,-35,7,3.4,0.2]]:
		if embedded_in_world and absf(fragment[0])<12 and absf(fragment[1])<21:continue
		_wall(fragment[0],fragment[1],fragment[2],fragment[3],fragment[4],true)
	if embedded_in_world:_build_rebel_courtyard()
	# The left flank is longer and elevated, the right flank narrower and enclosed.
	for z in [17,0,-17,-34]:
		_wall(-45,z,12,2.8,PI*0.5,true)
		_wall(42,z,13,3.6,PI*0.5,true)
	for ridge in [[-49,24,8,2.5,8],[-48,-12,9,3.0,7],[-42,-37,7,2.7,9],[47,11,8,2.8,7],[45,-24,9,3.2,8]]:
		_block("RockyRidge", "Terrain", Vector3(ridge[0],height_at(ridge[0],ridge[1])+ridge[3]*0.5,ridge[1]),Vector3(ridge[2],ridge[3],ridge[4]),dark_stone,0.28)
	_stairs(-30,-7,5)
	_stairs(0,-31,5)
	_stairs(23,-30,4)
	# Watchtower carcass: three broken sides with a walkable open center.
	for segment in [[-9,-48,8,0],[9,-48,8,0],[-12,-43,10,PI*0.5],[12,-43,9,PI*0.5]]:
		_wall(segment[0],segment[1],segment[2],4.8,segment[3],true)
	_wall(-15,-47,7,8.3,PI*0.5,true)
	_wall(15,-47,7,7.6,PI*0.5,true)
	for column_x in [-5.0,5.0]:
		_block("WatchtowerPier", "Architecture", Vector3(column_x,height_at(column_x,-47)+4.1,-47),Vector3(1.5,8.2,1.5),stone)
	_build_climb_route()
	var keep_top: float = height_at(0,-47)+.7
	for step in range(12):
		var zz: float = -37.7-step*.48
		var top: float = keep_top-.25*(11-step)
		_block("KeepAccessStep", "Architecture",Vector3(2,top-.15,zz),Vector3(3.4,.3,.5),pale)
	_block("WatchtowerBase", "Architecture", Vector3(0,height_at(0,-47)+0.35,-47), Vector3(13,0.7,8), pale)

func entrance_ground(x:float,z:float) -> float:
	var at:=to_global(Vector3(x,0,z))
	return landscape.height(at.x,at.z)-global_position.y

func _build_private_entry() -> void:
	# The outer opening follows the existing cut-and-fill road at this elevation.
	var entry:=Node3D.new()
	entry.name="OuterFortGate"
	entry.position=Vector3(11.5,entrance_ground(11.5,86.0),86.0)
	nodes.Architecture.add_child(entry)
	_wall(-31.25,86.0,75.5,7.8,0,true,1.45)
	_wall(35.5,86.0,38.0,8.0,0,true,1.45)
	_wall(-69.0,69.0,34.0,6.5,PI*.5,true)
	_wall(54.5,69.0,34.0,6.3,PI*.5,true)
	# Thick, battered piers hold a deep semicircular barrel opening.
	for side in [-1.0,1.0]:
		var pier:=_block("GateTowerPier","Architecture",entry.position+Vector3(side*4.58,4.55,0),Vector3(2.45,10.1,4.35),stone)
		pier.get_child(0).material_override=ruin_material()
	var shell:=SurfaceTool.new()
	shell.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS:=15
	for i in SEGMENTS:
		var a:=PI*float(i)/SEGMENTS
		var b:=PI*float(i+1)/SEGMENTS
		var wedge:=PackedVector3Array()
		for z in [-2.15,2.15]:
			for radius in [3.3,4.55]:
				for angle in [a,b]:
					wedge.append(Vector3(cos(angle)*radius,4.7+sin(angle)*radius,z))
		for face in [[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]:
			for corner in [0,2,1,0,3,2]:shell.add_vertex(wedge[face[corner]])
	shell.generate_normals()
	var vault:=MeshInstance3D.new()
	vault.name="DeepStoneGateVault"
	vault.mesh=shell.commit()
	vault.material_override=stone
	entry.add_child(vault)
	vault.create_trimesh_collision()
	# Fill the arch shoulders and crown so the opening reads as a passage
	# through an old gatehouse, with a broken upper parapet.
	var crown:=SurfaceTool.new()
	crown.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEGMENTS:
		var points:=PackedVector3Array()
		for z in [-2.15,2.15]:
			for step in [i,i+1]:
				var theta:=PI*float(step)/SEGMENTS
				var x:=cos(theta)*4.55
				points.append(Vector3(x,4.7+sin(theta)*4.55-.025,z))
				points.append(Vector3(x,10.3+.36*sin(float(step)*1.4)+.2*cos(float(step)*2.8),z))
		for face in [[0,2,3,1],[4,5,7,6],[1,3,7,5],[0,4,6,2]]:
			for index in [0,2,1,0,3,2]:crown.add_vertex(points[face[index]])
	crown.generate_normals()
	var spandrel:=MeshInstance3D.new()
	spandrel.name="BrokenGatehouseCrown"
	spandrel.mesh=crown.commit()
	spandrel.material_override=ruin_material()
	entry.add_child(spandrel)
	spandrel.create_trimesh_collision()

	# Retained timber leaves lie open against the deep passage cheeks.
	for side in [-1.0,1.0]:
		for plank in 6:
			_block("WeatheredGateLeaf","Architecture",entry.position+Vector3(side*3.22,1.65,-1.7+plank*.46),Vector3(.18,3.3,.45),wood,0,false)
		for y in [.55,2.6]:
			_block("GateLeafBrace","Architecture",entry.position+Vector3(side*3.1,y,-.55),Vector3(.11,.18,2.75),wood,0,false)
	# The inner screen prevents a view through the entrance into occupied rooms.
	# A wide western turn takes the player and vehicles around it.
	_wall(11.5,75.0,14.0,7.1,0,true,1.8)
	_wall(18.0,70.5,9.0,5.8,PI*.5,true,1.2)
	# A lower return conceals the ramp while keeping its mouth accessible.
	_wall(-59.1,75.5,13.0,5.0,PI*.5,true)
	_wall(-52.9,75.5,13.0,5.0,PI*.5,true)

func _build_entry_galleries() -> void:
	var plaster:=ruin_material()
	# Service route: repeated arches bridge the existing westward follow line.
	# The north and south room walls keep the gallery from reading as loose piers.
	for span in [Vector2(-36.85,5.3),Vector2(-26,7.6),Vector2(-14,7.6),Vector2(-3.15,5.3)]:
		_wall(span.x,69.4,span.y,5.2,0,true,1.0)
	for x in [-32.0,-20.0,-8.0]:
		_gallery_arch(Vector2(x,69.4),0.0,plaster)
	_wall(-20,77.6,39,4.9,0,true,1.0)
	for x in [-5.0,-11.0,-17.0,-23.0,-29.0,-35.0]:
		_gallery_arch(Vector2(x,73.0),PI*.5,plaster)
	for x in [-32.0,-20.0,-8.0]:
		_wall(x,64.7,8,4.4,0,true,1.0)
		_wall(x-4.0,67.0,4.6,4.1,PI*.5,true,1.0)
	# Surviving timber pockets and short beam ends explain the missing upper floor.
	for room_x in [-32.0,-20.0,-8.0]:
		for offset in [-2.5,-.6,1.6]:
			var x:float=room_x+offset
			var y:float=entrance_ground(x,64.7)+3.15
			_block("OldJoistPocket","Props",Vector3(x,y,65.211),Vector3(.38,.34,.035),dark_stone,0,false)
			if offset<0:
				_block("BrokenJoistEnd","Props",Vector3(x,y-.035,65.42),Vector3(.24,.23,.56),wood,.035,false)
	for point in [Vector2(-34.0,66.0),Vector2(-21.5,66.0)]:
		var crate:Node3D=load("res://objects/household/storage/crate.tscn").instantiate()
		crate.position=Vector3(point.x,entrance_ground(point.x,point.y),point.y)
		crate.rotation.y=.23
		nodes.Props.add_child(crate)
	# A covered remnant and neighbouring roofless spans preserve the ruined silhouette.
	for x in [-35.3,-28.8]:
		for z in [69.4,77.6]:
			var pier_y:=entrance_ground(x,z)
			var prop:=_block("GalleryRoofPier","Architecture",Vector3(x,pier_y+2.46,z),Vector3(.71,4.96,.73),stone)
			prop.get_child(0).material_override=plaster
	for z in [69.4,77.6]:
		_block("GalleryWallPlate","Architecture",Vector3(-32.05,entrance_ground(-32.05,73.0)+4.94,z),Vector3(7.1,.28,.33),wood)
	for x in [-34.5,-33.6,-32.7,-31.8,-30.9,-30.0,-29.1]:
		var roof_y:=entrance_ground(x,73.0)+5.05
		_block("GalleryRoofRafter","Architecture",Vector3(x,roof_y,73.5),Vector3(.23,.24,8.4),wood)
	for x in [-34.5,-33.9,-33.3,-32.7]:
		var roof_y:=entrance_ground(x,73.0)+5.23
		_block("BrokenGalleryRoof","Architecture",Vector3(x,roof_y,73.5),Vector3(.59,.14,7.9),wood)
	# Inner ward: a second offset wall breaks the sightline from the forecourt.
	# Its west end opens onto the inner gate; the east end leaves the delivery yard clear.
	_wall(0,56.0,16.0,6.2,0,true,1.15)
	_wall(8.1,52.4,7.2,5.2,PI*.5,true,1.05)
	_gallery_arch(Vector2(-11.5,56.0),0.0,plaster)
	_wall(-18.6,56.0,9.1,5.4,0,true,1.05)
	_wall(-22.9,52.3,7.4,4.8,PI*.5,true,1.05)
	# Just inside the older gate, a short return directs foot traffic past a room bay.
	_wall(1.7,37.0,13.0,5.4,0,true,1.12)
	_wall(8.0,33.9,6.2,4.6,PI*.5,true,1.0)
	_gallery_arch(Vector2(-8.6,37.0),0.0,plaster)
	_wall(-15.2,37.0,8.1,4.7,0,true,1.0)
	_wall(-18.9,34.1,5.8,4.3,PI*.5,true,1.0)
	for point in [Vector2(-25,66),Vector2(-13,66),Vector2(5.1,52),Vector2(4.9,34)]:
		var debris:=Vector3(point.x,entrance_ground(point.x,point.y)+.16,point.y)
		_block("FallenMasonry","Props",debris,Vector3(.95,.38,.75),rubble_mat,.31,false)

	var gallery_path:Array[Vector2]=[Vector2(0,73),Vector2(-39,73)]
	var ward_path:Array[Vector2]=[Vector2(0,66),Vector2(0,62.5),Vector2(-11.5,62.5),Vector2(-11.5,50),Vector2(0,50),Vector2(0,42),Vector2(-8.6,42),Vector2(-8.6,33)]
	_worn_fort_path(gallery_path)
	_worn_fort_path(ward_path)

func _worn_fort_path(points:Array[Vector2]) -> void:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(points.size()-1):
		var start:=points[segment]
		var end:=points[segment+1]
		var tangent:=(end-start).normalized()
		var side:=Vector2(-tangent.y,tangent.x)
		var steps:=ceili(start.distance_to(end))
		for step in steps:
			for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var t:=float(step+corner.y)/steps
				var at:=start.lerp(end,t)+side*(float(corner.x)-.5)*3.1
				surface.set_uv(Vector2(corner.x,t))
				surface.add_vertex(Vector3(at.x,entrance_ground(at.x,at.y)+.055,at.y))
	surface.generate_normals()
	var path:=MeshInstance3D.new()
	path.name="WornFortPassage"
	path.mesh=surface.commit()
	var finish:=ShaderMaterial.new()
	finish.shader=preload("res://world/suryagarh/shaders/mountain_trail.gdshader")
	finish.set_shader_parameter("grain",preload("res://environment/forest/assets/textures/rock_albedo.jpg"))
	path.material_override=finish
	path.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nodes.Props.add_child(path)

func _gallery_arch(point:Vector2,yaw:float,plaster:Material) -> void:
	var frame:=Node3D.new()
	frame.name="RuinedPointedPassage"
	frame.position=Vector3(point.x,entrance_ground(point.x,point.y),point.y)
	frame.rotation.y=yaw
	nodes.Architecture.add_child(frame)
	for side in [-1.0,1.0]:
		# Individual bed courses retain the full opening but break the monolithic pier.
		for course in 7:
			var wear:float=.025*sin(point.x*.71+point.y*.33+course*2.1+side)
			var local:=Vector3(side*(2.66+wear*.5),-.24+(course+.5)*.48,0)
			var pier:=_block("GalleryPierCourse","Architecture",frame.position+local.rotated(Vector3.UP,yaw),Vector3(.95+wear,.465,1.3+wear),stone,yaw)
			pier.get_child(0).material_override=plaster
		var base:=Vector3(side*2.66,.14,0)
		var plinth:=_block("GalleryPierFoot","Architecture",frame.position+base.rotated(Vector3.UP,yaw),Vector3(1.10,.42,1.45),stone,yaw)
		plinth.get_child(0).material_override=plaster
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Segmented two-centre arch with a visible intrados and masonry depth.
	const STEPS:=16
	for i in STEPS:
		var points:=PackedVector3Array()
		for z in [-.65,.65]:
			for row in [0,1]:
				for j in [i,i+1]:
					# A narrow recessed bed joint separates each wedge. Only the
					# extrados is eroded, leaving the passage envelope unchanged.
					var joint:float=.018 if j==i else -.018
					var t:float=(float(j)+joint)/STEPS*2.0-1.0
					var x:float=t*(2.22+.47*row)
					var erosion:float=(.045*sin(float(j)*2.7+point.x)+.026*cos(float(j)*4.1+point.y))*row
					var y:float=2.68+1.62*sqrt(maxf(0.0,1.0-absf(t)))+.43*row+erosion
					points.append(Vector3(x,y,z))
		for face in [[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]:
			for index in [0,1,2,0,2,3]:
				surface.add_vertex(points[face[index]])
	surface.generate_normals()
	var vault:=MeshInstance3D.new()
	vault.name="PointedStoneVault"
	vault.mesh=surface.commit()
	vault.material_override=stone
	frame.add_child(vault)
	vault.create_trimesh_collision()
	# Continuous recessed masonry closes the bed joints behind the face stones.
	# Its intrados sits inside the stone, preserving the original clear opening.
	var bedding:=SurfaceTool.new()
	bedding.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in STEPS:
		var points:=PackedVector3Array()
		for z in [-.60,.60]:
			for row in [0,1]:
				for j in [i,i+1]:
					var t:float=float(j)/STEPS*2.0-1.0
					var x:float=t*(2.22+.47*row)
					var erosion:float=(.045*sin(float(j)*2.7+point.x)+.026*cos(float(j)*4.1+point.y))*row
					var y:float=2.68+1.62*sqrt(maxf(0.0,1.0-absf(t)))+.43*row+erosion
					points.append(Vector3(x,y+(.012 if row==0 else -.012),z))
		for face in [[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]:
			for index in [0,1,2,0,2,3]:bedding.add_vertex(points[face[index]])
	bedding.generate_normals()
	var mortar:=MeshInstance3D.new()
	mortar.name="RecessedArchBedding"
	mortar.mesh=bedding.commit()
	mortar.material_override=dark_stone
	frame.add_child(mortar)
	mortar.create_trimesh_collision()

func _build_rebel_courtyard() -> void:
	# Leave a broad open range between the room fronts. The rear wall catches shots.
	_wall(0,-17,24,5.8,0,true)
	for side in [-1.0,1.0]:
		var x:float=side*15.0
		for z in [-10.0,0.0,10.0]:
			_arch(x,z,PI*.5,0)
		for z in [-15.0,-5.0,5.0,15.0]:
			_wall(x,z,4.4,5.4,PI*.5,true)
		_wall(side*24.0,0,27,5.7,PI*.5,true)
		for z in [-15.0,-5.0,5.0]:
			_wall(side*19.5,z,8.0,3.8,0,true)
		# Roof fragments shelter the rear of each middle room, with open sky over the yard.
		var floor_y:=height_at(side*20.0,0)
		for z in [-2.8,-1.8,-.8,.3,1.5]:
			_block("SurvivingRoomBeam","Architecture",Vector3(side*19.5,floor_y+2.9,z),Vector3(8.6,.19,.2),wood)
		for z in [-2.8,-2.35,-1.9,-1.45]:
			_block("BrokenRoofBoard","Architecture",Vector3(side*20.7,floor_y+3.03,z),Vector3(6.2,.1,.42),wood)
		var cache:Node3D=load("res://objects/household/storage/crate.tscn").instantiate()
		cache.position=Vector3(side*22.0,height_at(side*22.0,-2.0),-2.0)
		nodes.Props.add_child(cache)
	# The southern ends of both galleries are open to the existing flank routes.

func _cover_piece(x: float, z: float, kind: String, yaw: float) -> void:
	var h: float = height_at(x,z)
	var size := Vector3(3.2,1.05,0.9)
	var mat: Material = stone
	if kind == "full": size = Vector3(3.8,2.3,1.3)
	if kind == "rock":
		size = Vector3(3.2,2.1,2.8)
		mat = dark_stone
	if kind == "crate":
		size = Vector3(1.7,1.1,1.7)
		mat = wood
	var body := _block(kind.capitalize() + "Cover", "Cover", Vector3(x,h+size.y*0.5,z), size, mat, yaw)
	if kind == "crate":
		# Boards and projecting corner straps give the reusable crate readable construction.
		for side in [-1.0,1.0]:
			for course in range(5):
				var board := MeshInstance3D.new()
				var board_mesh := BoxMesh.new()
				board_mesh.size = Vector3(1.72,0.18,0.07)
				board.mesh = board_mesh
				board.material_override = wood
				board.position = Vector3(0,-0.43+course*0.21,side*0.87)
				body.add_child(board)
			for corner in [-1.0,1.0]:
				var strap := MeshInstance3D.new()
				var strap_mesh := BoxMesh.new()
				strap_mesh.size = Vector3(0.12,1.16,0.09)
				strap.mesh = strap_mesh
				strap.material_override = rubble_mat
				strap.position = Vector3(corner*0.65,0,side*0.91)
				body.add_child(strap)
	if kind in ["full","low"]:
		body.get_child(0).hide()
		_stone_section(Vector3(x,0,z),h,size.x,size.y,yaw,size.z)
	body.set_meta("cover_type", "full" if kind in ["full","rock"] else "low")
	for side in [-1.0,1.0]:
		var marker := Marker3D.new()
		marker.name = "PeekLeft" if side < 0 else "PeekRight"
		marker.position = Vector3(side*(size.x*0.5+0.45),-size.y*0.5,-size.z*0.5-0.6)
		marker.set_meta("cover_type", body.get_meta("cover_type"))
		body.add_child(marker)
	var point := Marker3D.new()
	point.name = "CoverPoint"
	point.position = Vector3(0,-size.y*0.5,-size.z*0.5-0.85)
	point.add_to_group("fort_cover_points")
	point.set_meta("cover_normal", body.basis * Vector3.FORWARD)
	point.set_meta("cover_type", body.get_meta("cover_type"))
	body.add_child(point)

func _build_cover() -> void:
	# Off-axis positions average 6-8 m between useful cover through combat spaces.
	var layout := [
		[-14,43,"rock",0.2],[9,39,"low",-0.4],[-5,34,"crate",0.2],[18,27,"rock",0.5],[-18,25,"low",-0.3],[2,23,"full",0.3],
		[-4,17,"low",0.8],[13,15,"crate",-0.5],[-22,13,"rock",0.1],[3,10,"rock",-0.6],[-12,7,"crate",0.3],[20,4,"low",0.4],
		[-3,1,"low",-0.2],[-27,-2,"full",0.4],[12,-4,"rock",0.3],[-11,-8,"rock",-0.4],[1,-11,"crate",0.6],[25,-13,"low",-0.3],
		[-18,-17,"low",0.2],[9,-19,"full",-0.4],[-2,-23,"rock",0.5],[-31,-24,"crate",0.1],[23,-27,"rock",-0.5],
		[-13,-30,"crate",0.5],[3,-33,"low",-0.3],[-27,-36,"rock",0.2],[18,-37,"low",0.5],[-5,-42,"full",-0.2],
		[-36,35,"full",-.4],[-38,27,"low",.15],[-34,18,"rock",.7],[-38,9,"crate",.2],[-36,-1,"low",-.4],[-38,-10,"rock",.3],[-35,-20,"low",-.4],[-37,-29,"low",.2],
		[34,35,"low",.2],[36,26,"rock",-.5],[33,17,"crate",.25],[35,8,"low",-.3],[37,-1,"rock",.1],[33,-10,"low",-.3],[36,-19,"crate",.2],[36,-32,"low",.3]
	]
	for p in layout:
		if embedded_in_world and absf(p[0])<15 and p[1]>=-17 and p[1]<=19:continue
		var z:float=13.0 if embedded_in_world and p[0]==-38 and p[1]==9 else p[1]
		_cover_piece(p[0],z,p[2],p[3])

func _build_props() -> void:
	for site in [Vector2(-28,35),Vector2(28,-18)]:
		var cart := preload("res://world/ruined_fort/fort_abandoned_cart.gd").new()
		cart.show_horse = false
		cart.variant = 1
		cart.name = "AbandonedGoodsCart"
		cart.position = Vector3(site.x,height_at(site.x,site.y),site.y)
		cart.rotation.y = -.45
		nodes.Props.add_child(cart)
	var assets := ["storage/crate","grain_sack","storage/basket","water_pot_visual","storage/barrel","storage/bench"]
	for index in range(18):
		var site: Vector2 = [Vector2(-24,23),Vector2(25,8),Vector2(-26,-5),Vector2(24,-25),Vector2(-19,-30),Vector2(18,-40)][index/3]
		var x: float = site.x-2.5+(index%3)*1.1
		var z: float = site.y+1.4
		var prop: Node3D = load("res://objects/household/"+assets[index%assets.size()]+".tscn").instantiate()
		prop.name = "Salvaged"+str(index)
		prop.position = Vector3(x,height_at(x,z),z)
		prop.rotation.y = rng.randf_range(-.4,.4)
		nodes.Props.add_child(prop)
	for site in [Vector2(-24,23),Vector2(25,8),Vector2(-26,-5),Vector2(24,-25),Vector2(-19,-30),Vector2(18,-40)]:
		for tile in range(5):
			var x: float = site.x-2+tile*0.85
			var z: float = site.y-1.8
			_block("BrokenFloorSlab","Props",Vector3(x,height_at(x,z)+.05,z),Vector3(.8,.1,1.7),pale,rng.randf_range(-.08,.08),false)
	for i in range(45):
		var x: float = rng.randf_range(-47,47)
		var z: float = rng.randf_range(-47,40)
		if absf(x) < 4.0: x += 6.0 * signf(x+0.01)
		var kind: int = i % 5
		var size := Vector3(0.8,0.5,0.65) if kind < 3 else Vector3(1.8,0.18,0.32)
		_block("Rubble" if kind < 3 else "FallenPlank", "Props", Vector3(x,height_at(x,z)+size.y*0.5,z), size, rubble_mat if kind < 3 else wood, rng.randf_range(-PI,PI), false)
	for p in [Vector2(-20,20),Vector2(14,11),Vector2(-9,-16),Vector2(22,-34)]:
		_block("ClothCoveredCrate", "Props", Vector3(p.x,height_at(p.x,p.y)+0.55,p.y),Vector3(1.6,1.1,1.5),cloth,0.2)

func _build_climb_route() -> void:
	# Optional west shortcut with visible hand/boot stones and a supported landing.
	var base: float = height_at(-34,-18)
	var wall := _block("WestClimbWall", "Architecture",Vector3(-34,base+1.8,-18),Vector3(1.2,3.6,4.0),stone)
	wall.add_to_group("climbable_walls")
	wall.set_meta("top_y",to_global(Vector3(0,base+3.6,0)).y)
	wall.set_meta("climb_center_z",wall.global_position.z)
	wall.set_meta("climb_hold_center_z",wall.global_position.z)
	wall.set_meta("climb_hold_base_y",to_global(Vector3(0,base+0.4,0)).y)
	wall.set_meta("climb_hold_spacing",0.4)
	wall.set_meta("climb_hold_rows",8)
	wall.set_meta("climb_lane_half_width",0.55)
	_block("WestWallWalk", "Architecture",Vector3(-32.1,base+3.42,-18),Vector3(3.0,0.36,4.0),pale)
	for row in range(8):
		for side in [-1.0,1.0]:
			_block("ClimbingStone", "Architecture",Vector3(-34.66,base+0.4+row*0.4,-18+side*0.24),Vector3(0.22,0.14,0.38),pale,0,false)

func _build_vegetation() -> void:
	# Shared tuft mesh, one instanced draw for clustered dry grass.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(7):
		var angle: float = blade*2.399
		var base := Vector3(cos(angle),0,sin(angle))*0.12
		var width := Vector3(cos(angle+PI/2),0,sin(angle+PI/2))*0.035
		var tip := base+Vector3(cos(angle)*0.13,0.45+blade*0.025,sin(angle)*0.13)
		for vertex in [base-width,tip,base+width,base+width,tip,base-width]: surface.add_vertex(vertex)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0,grass)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = 240
	var index := 0
	for center in [Vector2(-34,37),Vector2(35,23),Vector2(-39,7),Vector2(34,-15),Vector2(-29,-34),Vector2(32,-42)]:
		for i in range(40):
			var x: float = center.x+rng.randf_range(-5,5)
			var z: float = center.y+rng.randf_range(-4,4)
			var scale_factor: float = rng.randf_range(0.7,1.6)
			var transform := Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3.ONE*scale_factor),Vector3(x,height_at(x,z),z))
			batch.set_instance_transform(index,transform)
			index += 1
	var visual := MultiMeshInstance3D.new()
	visual.name = "ClusteredDryGrass"
	visual.multimesh = batch
	nodes.Vegetation.add_child(visual)

func _build_navigation() -> void:
	var region := NavigationRegion3D.new()
	region.name = "FortWalkableRoutes"
	nodes.Navigation.add_child(region)
	if embedded_in_world and not force_navigation_rebake and ResourceLoader.exists(NAV_FILE):
		region.navigation_mesh = load(NAV_FILE)
		print("FORT NAVIGATION POLYGONS: ", region.navigation_mesh.get_polygon_count(), " (saved)")
		return
	var nav := NavigationMesh.new()
	nav.agent_height = 2.0
	nav.agent_radius = 0.5
	nav.agent_max_climb = 0.25
	nav.agent_max_slope = 44.0
	nav.cell_size = 0.25
	nav.cell_height = 0.25
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	nav.filter_baking_aabb = AABB(Vector3(-59,-2,-49),Vector3(118,18,98))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav, source, self)
	if embedded_in_world: source.add_faces(nav_ground_faces, Transform3D.IDENTITY)
	NavigationServer3D.bake_from_source_geometry_data(nav, source)
	region.navigation_mesh = nav
	print("FORT NAVIGATION POLYGONS: ", nav.get_polygon_count())

func _stone_section(site: Vector3, ground: float, width: float, tall: float, yaw: float, thickness: float = .82) -> void:
	var rows: int = maxi(1,ceili(tall/0.43))
	var columns: int = maxi(2,ceili(width/0.85))
	var course: float = tall/rows
	var brick: float = width/columns
	for row in range(rows):
		for column in range(columns):
			var x: float = -width*0.5+(column+0.5)*brick
			var stagger: float = 0.12 if row%2 else -0.12
			x = clampf(x+stagger,-width*0.5+brick*0.45,width*0.5-brick*0.45)
			var center := site+Vector3(x,0,0).rotated(Vector3.UP,yaw)
			center.y = ground+(row+0.5)*course
			var basis := Basis(Vector3.UP,yaw+rng.randf_range(-.018,.018)).scaled(Vector3(brick*1.03,course*1.03,thickness*rng.randf_range(1.03,1.13)))
			masonry_transforms.append(Transform3D(basis,center))

func ruin_material() -> ShaderMaterial:
	var result:=ShaderMaterial.new()
	result.shader=preload("res://world/ruined_fort/fort_ruin_wall.gdshader")
	result.set_shader_parameter("stone_grain",preload("res://assets/nature/materials/rock_boulder_dry_diff_1k.jpg"))
	return result

func _finish_masonry() -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = BoxMesh.new() if embedded_in_world else stone_mesh_shared
	batch.instance_count = masonry_transforms.size()
	for i in range(masonry_transforms.size()):
		batch.set_instance_transform(i,masonry_transforms[i])
		var tint: float = rng.randf_range(.85,1.12)
		batch.set_instance_color(i,Color(tint,tint*.99,tint*.96,1))
	var visual := MultiMeshInstance3D.new()
	visual.name = "ModularChippedMasonry"
	visual.multimesh = batch
	var material := _weathered_stone(Color("d5c6a9"),.38)
	material.vertex_color_use_as_albedo = true
	material.roughness = 1
	if embedded_in_world:
		visual.material_override=ruin_material()
	else:
		visual.material_override=material
	nodes.Architecture.add_child(visual)
	masonry_transforms.clear()
