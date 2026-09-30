extends RefCounted
## Fictional expanded thana blockout. Underground detention is not historically approved.
const CELLAR_Y := -4.0
const PIT := Rect2(-5, -16, 22, 26)

static func slab(b: Node3D, label: String, x0: float, x1: float, z0: float, z1: float, y: float, thickness: float) -> void:
	b.piece(b, label, Vector3((x0+x1)*0.5, y-thickness*0.5, (z0+z1)*0.5), Vector3(x1-x0, thickness, z1-z0), b.stone)

static func foundation(b: Node3D) -> void:
	# The basement has open interior space, rather than intersecting a solid plinth.
	slab(b, "FoundationWest", -19.5, -5, -18.5, 18.5, 0, 2)
	slab(b, "FoundationEast", 17, 19.5, -18.5, 18.5, 0, 2)
	slab(b, "FoundationNorth", -5, 17, -18.5, -16, 0, 2)
	slab(b, "FoundationSouth", -5, 17, 10, 18.5, 0, 2)
	# Ground slab with an actual opening above the descending staircase.
	slab(b, "CellarCeilingWest", -5, 10, -16, 10, 0, 0.3)
	slab(b, "CellarCeilingEast", 14, 17, -16, 10, 0, 0.3)
	slab(b, "CellarCeilingNorth", 10, 14, -16, -8, 0, 0.3)
	slab(b, "CellarCeilingSouth", 10, 14, 7.5, 10, 0, 0.3)
	slab(b, "CellarFloor", -5, 17, -16, 10, CELLAR_Y, 0.35)
	for x in [-5.0, 17.0]:
		b.piece(b, "CellarRetainingWall", Vector3(x, -2, -3), Vector3(0.5, 4, 26), b.stone)
	for z in [-16.0, 10.0]:
		b.piece(b, "CellarRetainingWall", Vector3(6, -2, z), Vector3(22, 4, 0.5), b.stone)
	excavate(b)

static func excavate(b: Node3D) -> void:
	# Copy only affected resident terrain surfaces/collision maps. Other tiles and
	# saved landscape resources retain their existing data and LODs.
	var terrain := b.get_tree().root.find_child("TerrainTiles", true, false)
	if terrain == null: return
	var lowered_vertices := 0
	for tile in terrain.get_children():
		if not tile is MeshInstance3D: continue
		var source: Mesh = tile.mesh
		var bounds: AABB = source.get_aabb()
		var center: Vector3 = b.to_local(tile.to_global(bounds.get_center()))
		if absf(center.x-6) > bounds.size.x*0.5+15 or absf(center.z+3) > bounds.size.z*0.5+18: continue
		var replacement := ArrayMesh.new()
		var modified := false
		for surface in source.get_surface_count():
			var arrays: Array = source.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in points.size():
				var local: Vector3 = b.to_local(tile.to_global(points[i]))
				if PIT.grow(2.0).has_point(Vector2(local.x, local.z)):
					points[i].y = b.global_position.y + CELLAR_Y - 0.4
					modified = true
					lowered_vertices += 1
			arrays[Mesh.ARRAY_VERTEX] = points
			replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			replacement.surface_set_material(surface, source.surface_get_material(surface))
		if not modified: continue
		tile.mesh = replacement
		for node in tile.find_children("*", "CollisionShape3D", true, false):
			if not node.shape is HeightMapShape3D: continue
			var heightmap: HeightMapShape3D = node.shape.duplicate()
			var data := heightmap.map_data
			for z in heightmap.map_depth:
				for x in heightmap.map_width:
					var sample := Vector3(x-(heightmap.map_width-1)*0.5, 0, z-(heightmap.map_depth-1)*0.5)
					var local: Vector3 = b.to_local(node.to_global(sample))
					if PIT.grow(2.0).has_point(Vector2(local.x, local.z)):
						data[z*heightmap.map_width+x] = node.to_local(b.to_global(Vector3(local.x, CELLAR_Y-0.4, local.z))).y
			heightmap.map_data = data
			node.shape = heightmap
	b.set_meta("cellar_excavated_vertices", lowered_vertices)

static func doorway(b: Node3D, label: String, center: Vector3, width: float, height: float = 4.8) -> void:
	for sign_side in [-1, 1]:
		b.piece(b, label+"Pier", center+Vector3(sign_side*(width*0.25+0.7), height*0.5, 0), Vector3(width*0.5-1.4, height, 0.3), b.plaster)
	b.piece(b,label+"Lintel",center+Vector3(0,2.75,0),Vector3(2.8,0.30,0.3),b.plaster)
	b.piece(b,label+"VentHeader",center+Vector3(0,height-0.15,0),Vector3(2.8,0.30,0.3),b.plaster)
	preload("res://world/suryagarh/settlements/police_refinement.gd").vent(b,label+"Transom",center+Vector3(0,3.70,0),2.7)

static func cell(b: Node3D, center: Vector3, label: String) -> void:
	# An open gate leaves a 1.5 m portal, while solid bars retain the other bays.
	for side in [-1, 1]:
		b.piece(b, label+"Side", center+Vector3(side*2.4, 1.6, -1.8), Vector3(0.25, 3.2, 3.6), b.stone)
	b.piece(b, label+"Back", center+Vector3(0, 1.6, -3.5), Vector3(4.8, 3.2, 0.25), b.stone)
	for x in [-2.25, -1.95, -1.65, -1.35, -1.05, 1.05, 1.35, 1.65, 1.95, 2.25]:
		b.piece(b, label+"IronBar", center+Vector3(x, 1.45, 0), Vector3(0.045, 2.9, 0.045), b.iron, false)
	for side in [-1, 1]:
		b.piece(b, label+"BarCollision", center+Vector3(side*1.6, 1.5, 0), Vector3(1.6, 3, 0.12), b.iron, true).get_child(0).hide()
	var gate: Node3D = b.piece(b, label+"OpenGateCollision", center+Vector3(0.82, 1.35, -0.7), Vector3(0.08, 2.7, 1.4), b.iron)
	gate.get_child(0).hide()
	for z in [-1.3,-1.05,-0.8,-0.55,-0.3,-0.05]:
		b.piece(b,label+"OpenGateBar",center+Vector3(0.82,1.35,z),Vector3(0.045,2.7,0.045),b.iron,false)
	for y in [0.10,1.3,2.6]:
		b.piece(b,label+"OpenGateRail",center+Vector3(0.82,y,-0.7),Vector3(0.06,0.07,1.4),b.iron,false)
	b.piece(b, label+"SleepingPlatform", center+Vector3(-0.8, 0.18, -2.5), Vector3(2.4, 0.36, 1.1), b.stone)
	b.piece(b, label+"SleepingMat", center+Vector3(-0.8, 0.375, -2.5), Vector3(2.2, 0.03, 1), b.ochre, false)

static func furnish(b: Node3D) -> void:
	for level in 2:
		var y: float = level*b.floor_y
		# West offices open to the main corridor; rear room is separate from armoury.
		for segment in [Vector2(-12,-8.5), Vector2(-5.5,2.5), Vector2(5.5,14)]:
			b.piece(b, "OfficeSidePartition", Vector3(-6,y+1.7,(segment.x+segment.y)*0.5), Vector3(0.3,3.4,segment.y-segment.x), b.plaster)
			b.piece(b,"OfficeVentHeader",Vector3(-6,y+4.575,(segment.x+segment.y)*0.5),Vector3(0.3,0.45,segment.y-segment.x),b.plaster)
			preload("res://world/suryagarh/settlements/police_refinement.gd").vent(b,"OfficeHighAirPath",Vector3(-6,y+3.88,(segment.x+segment.y)*0.5),segment.y-segment.x-0.10,true)
		for z in [-7.0,4.0]:
			b.piece(b, "OfficeSideDoorLintel", Vector3(-6,y+2.75,z), Vector3(0.3,0.3,3), b.plaster)
			b.piece(b,"OfficeSideVentHeader",Vector3(-6,y+4.65,z),Vector3(0.3,0.3,3),b.plaster)
			preload("res://world/suryagarh/settlements/police_refinement.gd").vent(b,"OfficeDoorTransom",Vector3(-6,y+3.7,z),2.9,true)
		for z in [-12.0, -2.0, 9.0]:
			doorway(b, "OfficeCrossPartition", Vector3(-9.5, y, z), 7)
		for z in [-7.0, 4.0]:
			b.piece(b, "OfficeDesk", Vector3(-9.5, y+0.85, z), Vector3(2.2, 0.12, 1), b.wood)
			for x in [-10.4, -8.6]:
				b.piece(b, "OfficeDeskLeg", Vector3(x, y+0.4, z), Vector3(0.12, 0.8, 0.85), b.wood)
	# Ground cells placed at the front east side, clear of basement descent.
	for i in 2:
		cell(b, Vector3(8+i*5.1, 0, 16.5), "GroundCell%d" % i)
	for z in [-11.0, -5.0, 1.0]:
		cell(b, Vector3(0, CELLAR_Y, z), "LowerCell")
	# Basement staircase descends from z=8 to z=-8, with full upper aperture.
	for x in [10.0,14.0]:
		b.piece(b,"CellarStairwellWall",Vector3(x,-2,0.85),Vector3(0.25,4,13.3),b.stone)
	for i in 30:
		var height := CELLAR_Y * (i+1)/30.0
		b.piece(b, "CellarStairTread", Vector3(12, height-0.065, 7.5-(i+0.5)*0.5), Vector3(3, 0.13, 0.51), b.stone, false)
	var ramp: Node3D = b.piece(b, "CellarStairRamp", Vector3(12, -2.12, 0), Vector3(3, 0.28, sqrt(15*15+4*4)), b.stone)
	ramp.rotation.x = -atan2(4.0,15.0)
	ramp.get_child(0).hide()
	for x in [10.25, 13.75]:
		var rail: Node3D = b.piece(b, "CellarStairRail", Vector3(x, -1.05, 0), Vector3(0.1, 0.1, sqrt(15*15+4*4)), b.wood)
		rail.rotation.x = -atan2(4.0,15.0)
	b.set_meta("police_room_count", 10)
	b.set_meta("lower_detention_floor", CELLAR_Y)
