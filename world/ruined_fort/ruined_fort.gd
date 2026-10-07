extends Node3D
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
var rubble_mat := _mat(Color("918b7d"))
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
	_build_architecture()
	_build_cover()
	_build_props()
	_build_vegetation()
	_finish_masonry()
	_build_navigation()
	if not force_navigation_rebake:
		var encounter := preload("res://world/ruined_fort/fort_encounter.gd").new()
		encounter.name = "FortEncounter"
		nodes.Gameplay.add_child(encounter)
	if not embedded_in_world: $Gameplay/Player.position = Vector3(0, height_at(0, 47) + 1.1, 47)
	print("RUINED FORT BLOCKOUT READY | 120 x 100 m | three routes | 8 m ascent")

func _masonry(color: Color) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = preload("res://world/ruined_fort/fort_masonry.gdshader")
	result.set_shader_parameter("stone_color", color)
	return result

func _rock_material(color: Color) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = preload("res://world/ruined_fort/fort_rock.gdshader")
	result.set_shader_parameter("rock_color", color)
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
func _block(label: String, group: String, at: Vector3, size: Vector3, material: Material, yaw: float = 0.0, collides: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.rotation.y = yaw
	nodes[group].add_child(body)
	var visual := MeshInstance3D.new()
	var is_rock: bool = label in ["BoundaryCliff", "SceneryRidge", "RockyRidge", "RockCover"]
	if is_rock:
		visual.mesh = rock_mesh_shared
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

func _wall(x: float, z: float, length: float, tall: float, yaw: float = 0.0, damaged: bool = false) -> void:
	var count: int = maxi(2, ceili(length / 2.8))
	var section: float = length / count
	for i in range(count):
		var offset: float = -length * 0.5 + (i + 0.5) * section
		var site: Vector3 = Vector3(x,0,z) + Vector3(offset,0,0).rotated(Vector3.UP,yaw)
		var ground: float = height_at(site.x,site.z)
		var section_height: float = tall
		if damaged:
			section_height *= [0.91,0.58,0.76,0.98,0.67][i % 5]
		var width: float = section - (0.08 if damaged else 0.025)
		var body := _block("DamagedWallStone" if damaged else "WallStone", "Architecture", Vector3(site.x,ground+section_height*0.5,site.z), Vector3(width,section_height,0.82),stone,yaw)
		body.get_child(0).hide()
		_stone_section(site,ground,width,section_height,yaw)
		if damaged and i % 3 == 1:
			_block("FallenMasonry", "Props", Vector3(site.x+0.8,ground+0.18,site.z+1.1),Vector3(0.7,0.36,0.8),rubble_mat,yaw+0.33,false)

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
	# Fragmented front curtain gives the fort a readable south entrance.
	_arch(0,45,0,0)
	for front in [[-20,45,22,3.2,0.05],[20,45,22,3.6,-0.08],[-42,41,13,2.8,0.12],[43,40,12,3.1,-0.16]]:
		_wall(front[0],front[1],front[2],front[3],front[4],true)
	_arch(0,30,0,1)
	_arch(-7,4,0,0)
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
		_wall(fragment[0],fragment[1],fragment[2],fragment[3],fragment[4],true)
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
	for step in range(4):
		var zz: float = -40.8-step*0.6
		var top: float = height_at(0,-47)+0.175*(step+1)
		_block("KeepAccessStep", "Architecture",Vector3(0,top-0.15,zz),Vector3(4.0,0.3,0.65),pale)
	_block("WatchtowerBase", "Architecture", Vector3(0,height_at(0,-47)+0.35,-47), Vector3(13,0.7,8), pale)

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
		[-13,-30,"crate",0.5],[3,-33,"low",-0.3],[-27,-36,"rock",0.2],[18,-37,"low",0.5],[-5,-42,"full",-0.2]
	]
	for p in layout: _cover_piece(p[0],p[1],p[2],p[3])

func _build_props() -> void:
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
	nav.agent_max_climb = 0.5
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

func _stone_section(site: Vector3, ground: float, width: float, tall: float, yaw: float) -> void:
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
			var basis := Basis(Vector3.UP,yaw+rng.randf_range(-.018,.018)).scaled(Vector3(brick*1.03,course*1.03,rng.randf_range(.85,.95)))
			masonry_transforms.append(Transform3D(basis,center))

func _finish_masonry() -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = stone_mesh_shared
	batch.instance_count = masonry_transforms.size()
	for i in range(masonry_transforms.size()):
		batch.set_instance_transform(i,masonry_transforms[i])
		var tint: float = rng.randf_range(.85,1.12)
		batch.set_instance_color(i,Color(tint,tint*.99,tint*.96,1))
	var visual := MultiMeshInstance3D.new()
	visual.name = "ModularChippedMasonry"
	visual.multimesh = batch
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b2a68e")
	material.vertex_color_use_as_albedo = true
	material.roughness = 1
	visual.material_override = material
	nodes.Architecture.add_child(visual)
	masonry_transforms.clear()
