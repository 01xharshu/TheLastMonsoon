extends RefCounted
## Sparse roadside finds with stable names for SaveManager's opened-cache state.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const Ground = preload("res://world/suryagarh/tree_trunk_collision.gd")
const Cache = preload("res://world/suryagarh/abandoned_cart_cache.gd")
const Props = preload("res://world/suryagarh/settlements/activity_props.gd")
# The western lower roads are grade-separated from the public coach network.
# The northern trunk is beyond the public coach service's northern endpoint.
const SITES := {
	"NorthTrunk": Vector2(0, -778),
	"WoodedVerge": Vector2(-745, 385),
	"VillageSouth": Vector2(-602, 385),
}
const MIN_PLOT_DISTANCE := 120.0
const MIN_LANDMARK_DISTANCE := 180.0

static func isolated(layout: RefCounted, point: Vector2) -> bool:
	if layout.plot_clearance(point.x, point.y) < MIN_PLOT_DISTANCE or Ground.consignment_road_reserved(point):
		return false
	for landmark: Vector2 in Layout.SITES.values():
		if point.distance_to(landmark) < MIN_LANDMARK_DISTANCE: return false
	return true

static func install(world: Node3D) -> Node3D:
	var existing := world.get_node_or_null("AbandonedCarts") as Node3D
	if existing != null: return existing
	var group := Node3D.new()
	group.name = "AbandonedCarts"
	world.add_child(group)
	var layout := Layout.new()
	var space := world.get_world_3d().direct_space_state
	var probe := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 4.5
	probe.shape = sphere
	probe.collision_mask = 1
	probe.exclude = Ground.terrain_exclusions(world)
	var index := 0
	for site: String in SITES:
		var main := site == "NorthTrunk"
		for along in [0.0, 9.0, -9.0, 18.0, -18.0, 27.0, -27.0, 36.0]:
			var center: Vector2 = SITES[site]
			if main:
				center.y += along
				center.x = layout.road_x(center.y)
			else:
				center.x += along
			var placed := false
			for side in [1.0, -1.0]:
				for verge in [3.2, 3.6, 4.0]:
					var point := center + (Vector2.RIGHT if main else Vector2.DOWN) * float(side * verge)
					if layout.road_distance(point.x, point.y) < 2.95 or not isolated(layout, point): continue
					var at := support(space, Vector3(point.x, layout.height(point.x, point.y), point.y))
					if at.is_empty() or at.position.y < 1.5 or at.normal.y < .94: continue
					var lane := support(space, Vector3(center.x, layout.height(center.x, center.y), center.y))
					if lane.is_empty() or absf(lane.position.y - at.position.y) > .55: continue
					probe.transform = Transform3D(Basis.IDENTITY, at.position + Vector3.UP * 1.1)
					if not space.intersect_shape(probe, 1).is_empty(): continue
					var yaw := (0.0 if main else PI * .5) + float(side) * .12
					build(group, space, site, at.position, yaw, index)
					group.get_node(site).set_meta("road_center", lane.position)
					placed = true
					break
				if placed: break
			if placed: break
		index += 1
	return group

static func support(space: PhysicsDirectSpaceState3D, around: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(around + Vector3.UP * 6, around - Vector3.UP * 6, Ground.TERRAIN_SUPPORT_LAYER))

static func ground_child(node: Node3D, space: PhysicsDirectSpaceState3D, parent: Node3D, at: Vector3, lift: float) -> void:
	var world_at := parent.to_global(at)
	var hit := support(space, world_at)
	node.position = parent.to_local(hit.position + Vector3.UP * lift) if not hit.is_empty() else at + Vector3.UP * lift

static func build(group: Node3D, space: PhysicsDirectSpaceState3D, site: String, at: Vector3, yaw: float, index: int) -> void:
	var scene := Node3D.new()
	scene.name = site
	group.add_child(scene)
	scene.global_position = at
	scene.rotation.y = yaw
	build_ruts(scene, space)
	var old_oak := Props.material(Color("574534"))
	var split_wood := Props.material(Color("947450"))
	var iron := Props.material(Color("403b32"))
	var bed := StaticBody3D.new()
	bed.name = "CollapsedCartBed"
	scene.add_child(bed)
	bed.position.y = .43
	bed.rotation = Vector3(.10, 0, -.24)
	for plank in 7:
		Props.box(bed, "DeckBoard", Vector3((plank - 3) * .23, 0, 0), Vector3(.216, .085, 2.04 - (plank % 3) * .15), old_oak)
	for side in [-1.0, 1.0]:
		var rail_length := 1.49 if side < 0 else .77
		var rail_z := -.25 if side < 0 else -.61
		Props.box(bed, "Rail", Vector3(side * .76, .44, rail_z), Vector3(.10, .12, rail_length), old_oak)
		if side > 0:
			Props.box(bed, "FracturedRailEnd", Vector3(.76, .44, -.21), Vector3(.10, .12, .05), split_wood)
		for z in [-.90, .26]:
			Props.box(bed, "Stake", Vector3(side * .76, .23, z), Vector3(.09, .55, .095), old_oak)
	Props.box(bed, "Axle", Vector3(0, -.16, .28), Vector3(2.08, .12, .12), iron)
	Props.box(bed, "BrokenDrawshaft", Vector3(-.55, -.08, 1.40), Vector3(.13, .11, 1.22), old_oak)
	Props.box(bed, "SplitEnd", Vector3(-.55, -.08, 2.02), Vector3(.12, .10, .055), split_wood)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, .65, 2.02)
	collider.shape = shape
	collider.position.y = .24
	bed.add_child(collider)
	for z in [-.77, .66]:
		var upper := bed.to_global(Vector3(.68, -.04, z))
		var hit := support(space, upper)
		if hit.is_empty() or upper.y - hit.position.y < .05: continue
		var contact: Vector3 = hit.position
		var span := upper - contact
		var brace := Props.box(scene, "BrokenUnderframe", scene.to_local((upper + contact) * .5), Vector3(.13, span.length(), .12), old_oak)
		brace.basis = Basis(Quaternion(Vector3.UP, scene.global_basis.inverse() * span.normalized()))
	var surviving := wheel(scene, Vector3(-.97, 0, .28), Vector3(0, 0, PI * .5 - .17), old_oak, iron)
	ground_child(surviving, space, scene, Vector3(-.97, 0, .28), .54)
	if index % 2 == 1:
		var rag := Props.material(Color("78624a"))
		for z in [-.86, -.22]:
			Props.box(bed, "HoodPost", Vector3(-.72, .74, z), Vector3(.07, 1.23, .075), old_oak)
		Props.box(bed, "RemainingHoodRib", Vector3(-.29, 1.36, -.86), Vector3(.94, .055, .065), old_oak)
		var canvas := Props.box(bed, "TornCanvas", Vector3(-.55, 1.21, -.58), Vector3(.54, .025, .58), rag)
		canvas.rotation.z = -.46
		Props.box(bed, "SnappedHoodPost", Vector3(.48, .27, -.60), Vector3(.07, .08, .95), split_wood)

	var fallen := wheel(scene, Vector3(1.51, 0, .40), Vector3(.19, .24, -.15), old_oak, iron)
	ground_child(fallen, space, scene, Vector3(1.51, 0, .40), .18)
	var minimum_clearance := INF
	for sample in 16:
		var angle := float(sample) * TAU / 16.0
		var rim := fallen.to_global(Vector3(cos(angle) * .52, -.038, sin(angle) * .52))
		var hit := support(space, rim)
		if not hit.is_empty(): minimum_clearance = minf(minimum_clearance, rim.y - hit.position.y)
	if minimum_clearance < INF: fallen.global_position.y += .008 - minimum_clearance
	var debris := Props.box(scene, "DiscardedRail", Vector3.ZERO, Vector3(.09, .10, .74), split_wood)
	debris.rotation.y = .60 + index * .21
	ground_child(debris, space, scene, Vector3(-1.12, 0, -1.72), .06)
	var scatter := preload("res://objects/household/grain_sack.tscn").instantiate() as Node3D
	scene.add_child(scatter)
	ground_child(scatter, space, scene, Vector3(-1.45, 0, .75), .03)
	scatter.rotation.y = .9 + index
	var crock := preload("res://objects/household/storage/brass_pot.tscn").instantiate() as Node3D
	scene.add_child(crock)
	ground_child(crock, space, scene, Vector3(1.42, 0, -1.15), .12)
	crock.rotation.z = 1.12
	var cache := Cache.new()
	cache.name = "CargoBox"
	scene.add_child(cache)
	ground_child(cache, space, scene, Vector3(.58, 0, -1.76), .02)
	Props.box(cache, "CargoBase", Vector3(0, .07, 0), Vector3(.69, .12, .48), old_oak)
	for side in [-1.0, 1.0]:
		Props.box(cache, "LongWall", Vector3(0, .23, side * .22), Vector3(.69, .31, .045), old_oak)
		Props.box(cache, "EndWall", Vector3(side * .32, .23, 0), Vector3(.045, .31, .45), old_oak)
	cache.lid = Node3D.new()
	cache.lid.position = Vector3(0, .38, .23)
	cache.add_child(cache.lid)
	for plank in 3:
		Props.box(cache.lid, "LidBoard", Vector3((plank - 1) * .234, .014, -.23),
			Vector3(.225, .055, .49 - .015 * (plank % 2)), old_oak if plank == 1 else split_wood)
	for x in [-.28, .28]:
		Props.box(cache.lid, "IronLidStrap", Vector3(x, .047, -.23), Vector3(.036, .014, .48), iron)
		Props.box(cache, "IronCorner", Vector3(x, .23, -.247), Vector3(.043, .32, .018), iron)
	for y in [.13, .25]:
		Props.box(cache, "FrontBoardSeam", Vector3(0, y, -.244), Vector3(.63, .010, .013), split_wood)
	Props.box(cache, "BentLatch", Vector3(0, .34, -.263), Vector3(.076, .090, .024), iron)
	var cache_collision := CollisionShape3D.new()
	var cache_shape := BoxShape3D.new()
	cache_shape.size = Vector3(.72, .42, .51)
	cache_collision.shape = cache_shape
	cache_collision.position.y = .21
	cache.add_child(cache_collision)

static func track_sections(scene: Node3D, space: PhysicsDirectSpaceState3D, half_length: float) -> Array[PackedVector3Array]:
	var sections: Array[PackedVector3Array] = []
	for step in 15:
		var distance := (float(step) / 7.0 - 1.0) * half_length
		var width := maxf(.035, 1.18 * smoothstep(0.0, 2.0, half_length - absf(distance)))
		var center := sin(distance * .3) * .28
		var section := PackedVector3Array()
		for sign in [-1.0, 1.0]:
			var point := scene.to_global(Vector3(center + sign * width, 0, distance))
			var hit := support(space, point)
			if hit.is_empty(): return []
			var previous := sections.size() - 1
			if previous >= 0 and absf(hit.position.y - scene.to_global(sections[previous][section.size()]).y) > .65:
				return []
			section.append(scene.to_local(hit.position + Vector3.UP * .045))
		sections.append(section)
	return sections

static func build_ruts(scene: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections: Array[PackedVector3Array] = []
	for extent in [7.0, 5.0, 3.5, 2.5]:
		sections = track_sections(scene, space, extent)
		if not sections.is_empty(): break
	if sections.is_empty(): return
	for i in range(sections.size() - 1):
		var points := [sections[i][0], sections[i][1], sections[i+1][0], sections[i+1][1]]
		for corner in [0, 2, 1, 1, 2, 3]:
			surface.set_uv(Vector2(float(corner % 2), float(i + int(corner >= 2))))
			surface.add_vertex(points[corner])
	surface.generate_normals()
	var visual := MeshInstance3D.new()
	visual.name = "DisusedCartTrack"
	visual.mesh = surface.commit()
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dirt := ShaderMaterial.new()
	dirt.shader = preload("res://world/suryagarh/shaders/farm_track.gdshader")
	dirt.set_shader_parameter("earth_texture", preload("res://assets/nature/materials/brown_mud_dry_diff_1k.jpg"))
	dirt.set_shader_parameter("earth_normal", preload("res://assets/nature/materials/brown_mud_dry_nor_gl_1k.jpg"))
	visual.material_override = dirt
	scene.add_child(visual)

static func wheel(parent: Node3D, at: Vector3, rotation: Vector3, wood: Material, iron: Material) -> Node3D:
	var hub := StaticBody3D.new()
	parent.add_child(hub)
	var solid := CollisionShape3D.new()
	var disc := CylinderShape3D.new()
	disc.radius = .53
	disc.height = .085
	solid.shape = disc
	hub.add_child(solid)
	hub.position = at
	hub.rotation = rotation
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = .48
	torus.outer_radius = .55
	torus.rings = 20
	torus.ring_segments = 6
	rim.mesh = torus
	rim.material_override = iron
	hub.add_child(rim)
	for spoke in 5:
		var beam := Props.box(hub, "Spoke", Vector3.ZERO, Vector3(.058, .06, 1.02), wood)
		beam.rotation.y = spoke * PI / 6.0
	Props.cylinder(hub, "Hub", Vector3.ZERO, .115, .23, wood)
	return hub
