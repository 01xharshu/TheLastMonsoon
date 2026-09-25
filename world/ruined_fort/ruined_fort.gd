extends Node3D
## Isolated 120 x 100 m playable blockout. Z+ is the approach; Z- climbs to the keep.
const WIDTH := 120.0
const DEPTH := 100.0
const SCENERY_MARGIN := 25.0
const GRID := 2.0
const Shape = preload("res://world/ruined_fort/fort_shape.gd")
@export var embedded_in_world := false
var stone := _mat(Color("a79b84"))
var pale := _mat(Color("c1b49a"))
var dark_stone := _mat(Color("817e72"))
var soil := _mat(Color("968875"))
var rubble_mat := _mat(Color("918b7d"))
var wood := _mat(Color("715940"))
var cloth := _mat(Color("aaa08a"))
var grass := _mat(Color("777b54"))
var shrub := _mat(Color("68715a"))
var nodes := {}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 1857
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
	_build_navigation()
	if not embedded_in_world: $Gameplay/Player.position = Vector3(0, height_at(0, 47) + 1.1, 47)
	print("RUINED FORT BLOCKOUT READY | 120 x 100 m | three routes | 8 m ascent")

func _mat(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 1.0
	return result

func height_at(x: float, z: float) -> float:
	return Shape.height_at(x,z)

func _build_terrain() -> void:
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
			for vertex in [a,b,c,b,d,c]: surface.add_vertex(vertex)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, soil)
	var body := StaticBody3D.new()
	body.name = "IrregularGround"
	nodes.Terrain.add_child(body)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
	# Broken cliff chains constrain play while retaining an open entrance.
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
	for i in range(36):
		var side: int = i % 4
		var x: float = rng.randf_range(-82,82) if side < 2 else (-70.0 if side == 2 else 70.0)
		var z: float = (-62.0 if side == 0 else 62.0) if side < 2 else rng.randf_range(-64,64)
		_block("SceneryRidge", "Terrain", Vector3(x,height_at(x,z)+2.8,z), Vector3(rng.randf_range(7,15),rng.randf_range(4,10),rng.randf_range(5,11)), dark_stone, rng.randf_range(-0.45,0.45), false)

func _block(label: String, group: String, at: Vector3, size: Vector3, material: Material, yaw: float = 0.0, collides: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.rotation.y = yaw
	nodes[group].add_child(body)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	if collides:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
	return body

func _wall(x: float, z: float, length: float, tall: float, yaw: float = 0.0, damaged: bool = false) -> void:
	var h: float = height_at(x,z)
	_block("DamagedWall" if damaged else "Wall", "Architecture", Vector3(x,h+tall*0.5,z), Vector3(length,tall,0.75), stone, yaw)
	if damaged:
		_block("BrokenCoping", "Architecture", Vector3(x+length*0.28,h+tall+0.12,z), Vector3(length*0.3,0.25,0.9), pale, yaw+0.09)

func _arch(x: float, z: float, yaw: float, variant: int) -> void:
	var h: float = height_at(x,z)
	var root := Node3D.new()
	root.name = ["IntactArch", "DamagedArch", "CollapsedArch"][variant]
	root.position = Vector3(x,h,z)
	root.rotation.y = yaw
	nodes.Architecture.add_child(root)
	for side in [-1.0,1.0]:
		var pillar := _block("ArchPier", "Architecture", root.position + Vector3(side*2.5,1.75,0).rotated(Vector3.UP,yaw), Vector3(1.0,3.5,1.25), pale, yaw)
		pillar.reparent(root, true)
	if variant < 2:
		var crown := _block("ArchLintel", "Architecture", root.position + Vector3(0,3.75,0), Vector3(6.0,0.65,1.25), stone, yaw)
		crown.reparent(root, true)
	if variant == 1:
		_block("FallenVoussoir", "Props", root.position + Vector3(2.0,0.35,1.9), Vector3(1.3,0.7,1.0), rubble_mat, 0.4)
	if variant == 2:
		_block("CollapsedSpan", "Architecture", root.position + Vector3(3.4,0.55,1.7), Vector3(3.0,1.1,2.2), dark_stone, 0.3)

func _stairs(x: float, z: float, count: int, direction: float = -1.0) -> void:
	for i in range(count):
		var zz: float = z + direction * i * 1.15
		var y: float = height_at(x,zz)
		_block("StoneStep", "Architecture", Vector3(x,y+0.1,zz), Vector3(4.3,0.2,1.3), pale)

func _build_architecture() -> void:
	# Outer gate and fragmented eastern/western curtains leave broad silhouette openings.
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
	for column_x in [-5.0,5.0]:
		_block("WatchtowerPier", "Architecture", Vector3(column_x,height_at(column_x,-47)+4.1,-47),Vector3(1.5,8.2,1.5),stone)
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
	body.set_meta("cover_type", "full" if kind in ["full","rock"] else "low")
	for side in [-1.0,1.0]:
		var marker := Marker3D.new()
		marker.name = "PeekLeft" if side < 0 else "PeekRight"
		marker.position = Vector3(side*(size.x*0.5+0.45),0.0,-size.z*0.5-0.6)
		marker.set_meta("cover_type", body.get_meta("cover_type"))
		body.add_child(marker)
	var point := Marker3D.new()
	point.name = "CoverPoint"
	point.position = Vector3(0,0,-size.z*0.5-0.85)
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
	for i in range(45):
		var x: float = rng.randf_range(-47,47)
		var z: float = rng.randf_range(-47,40)
		if absf(x) < 4.0: x += 6.0 * signf(x+0.01)
		var kind: int = i % 5
		var size := Vector3(0.8,0.5,0.65) if kind < 3 else Vector3(1.8,0.18,0.32)
		_block("Rubble" if kind < 3 else "FallenPlank", "Props", Vector3(x,height_at(x,z)+size.y*0.5,z), size, rubble_mat if kind < 3 else wood, rng.randf_range(-PI,PI), false)
	for p in [Vector2(-20,20),Vector2(14,11),Vector2(-9,-16),Vector2(22,-34)]:
		_block("ClothCoveredCrate", "Props", Vector3(p.x,height_at(p.x,p.y)+0.55,p.y),Vector3(1.6,1.1,1.5),cloth,0.2)

func _build_vegetation() -> void:
	for center in [Vector2(-34,37),Vector2(35,23),Vector2(-39,7),Vector2(34,-15),Vector2(-29,-34),Vector2(32,-42)]:
		for i in range(13):
			var x: float = center.x+rng.randf_range(-7,7)
			var z: float = center.y+rng.randf_range(-6,6)
			var size := Vector3(rng.randf_range(0.4,1.2),rng.randf_range(0.3,0.8),rng.randf_range(0.4,1.1))
			_block("DryGrass" if i % 3 else "Shrub", "Vegetation", Vector3(x,height_at(x,z)+size.y*0.5,z),size,grass if i % 3 else shrub,rng.randf_range(-PI,PI),false)

func _build_navigation() -> void:
	var region := NavigationRegion3D.new()
	region.name = "FortWalkableRoutes"
	nodes.Navigation.add_child(region)
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
	NavigationServer3D.bake_from_source_geometry_data(nav, source)
	region.navigation_mesh = nav
	print("FORT NAVIGATION POLYGONS: ", nav.get_polygon_count())
