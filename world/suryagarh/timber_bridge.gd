extends Node3D
## Fictional 1850s rural timber crossing: plank deck, driven piles and braced rails.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const CROSSING_Z := 165.0
const HALF_SPAN := 104.0
const RAMP := 72.0
const NAVIGATION_HALF_WIDTH := 16.0
const BOAT_CLEARANCE := 8.0
const WIDTH := 10.0
const LANE_OFFSET := 2.35
var deck_height: float
var layout := Layout.new()
var timber: ShaderMaterial
var dark: ShaderMaterial
var iron: StandardMaterial3D

func _ready() -> void:
	position = Vector3(layout.river_x(CROSSING_Z), 0, CROSSING_Z)
	clear_crossing_vegetation()
	timber = ShaderMaterial.new()
	timber.shader = preload("res://world/suryagarh/shaders/bridge_timber.gdshader")
	timber.set_shader_parameter("wood_color",Color(.34,.25,.16))
	dark = timber.duplicate()
	dark.set_shader_parameter("wood_color",Color(.22,.17,.12))
	iron = StandardMaterial3D.new()
	iron.albedo_color = Color(.16,.14,.12)
	iron.metallic = .65
	iron.roughness = .8
	deck_height = maxf(Layout.WATER_LEVEL+BOAT_CLEARANCE+1.0, maxf(layout.height(position.x-HALF_SPAN,CROSSING_Z), layout.height(position.x+HALF_SPAN,CROSSING_Z)) + 1.0)
	# One continuous collision slab prevents catches between visual planks.
	piece("Deck", Vector3(0,deck_height-0.15,0), Vector3(HALF_SPAN*2,0.3,WIDTH), dark, true)
	for i in int(HALF_SPAN*4):
		piece("Plank",Vector3(-HALF_SPAN+0.25+i*0.5,deck_height+0.025,0),Vector3(0.48,0.05,WIDTH+0.16),timber)
	# Cross-bearers and triangulated trestles carry the widened deck.
	for x in range(-104,105,8):
		if absf(x) < NAVIGATION_HALF_WIDTH: continue
		piece("PileCap",Vector3(x,deck_height-.56,0),Vector3(.38,.42,WIDTH+.5),dark)
		var bottom := minf(layout.height(position.x+x,CROSSING_Z),deck_height-2.0)
		for side in [-1.0,1.0]:
			var foot := Vector3(x,bottom,side*(WIDTH*.5-.15))
			var head := Vector3(x,deck_height-.75,-side*(WIDTH*.5-.15))
			brace_3d(foot,head,.18)
			piece("IronStrap",Vector3(x,deck_height-.54,side*(WIDTH*.5-.15)),Vector3(.42,.5,.035),iron)
	for side in [-1.0,1.0]:
		for i in int(HALF_SPAN*0.5)+1:
			var x: float = -HALF_SPAN+i*4.0
			var bottom: float = layout.height(position.x+x,CROSSING_Z+side*(WIDTH/2-0.15))-0.5
			if absf(x) >= NAVIGATION_HALF_WIDTH:
				piece("Pile",Vector3(x,(bottom+deck_height+1.2)*0.5,side*(WIDTH/2-0.15)),Vector3(0.38,deck_height+1.2-bottom,0.38),dark,true)
			if i < int(HALF_SPAN*0.5):
				beam(Vector3(x,deck_height+0.2,side*(WIDTH/2-0.15)),Vector3(x+4,deck_height+1.08,side*(WIDTH/2-0.15)),0.12)
		piece("Handrail",Vector3(0,deck_height+1.15,side*(WIDTH/2-0.15)),Vector3(HALF_SPAN*2,0.16,0.2),timber)
		piece("RailCollision",Vector3(0,deck_height+0.6,side*(WIDTH/2-0.06)),Vector3(HALF_SPAN*2,1.3,0.15),dark,true,false)
		piece("Stringer",Vector3(0,deck_height-0.42,side*WIDTH*.31),Vector3(HALF_SPAN*2,0.5,0.28),dark)
	# Side trusses carry the central navigation span without piles in the boat lane.
	for side in [-1.0,1.0]:
		var z: float = side*(WIDTH*.5+.12)
		piece("NavigationTopChord",Vector3(0,deck_height+3.5,z),Vector3(NAVIGATION_HALF_WIDTH*2.0,.32,.32),dark)
		for x in range(-16,17,4):
			piece("NavigationTrussPost",Vector3(x,deck_height+1.75,z),Vector3(.3,3.5,.3),dark)
			if x < 16:
				beam(Vector3(x,deck_height+.1,z),Vector3(x+4,deck_height+3.5,z),.24)
	# Ramps follow a smooth bank-to-deck profile and overlap the ground at their ends.
	for side in [-1.0,1.0]:
		for i in 48:
			var a := ramp_point(side,float(i)/48.0)
			var b := ramp_point(side,float(i+1)/48.0)
			var center := (a+b)*0.5-Vector3(0,0.1,0)
			var segment := piece("Approach",center,Vector3(a.distance_to(b)+0.03,0.2,lerpf(WIDTH,WIDTH+2.0,float(i)/48.0)),timber,true)
			segment.rotation.z = atan2(b.y-a.y,b.x-a.x)
		for i in 9:
			var t := float(i)/8.0
			var at := ramp_point(side,t)
			for edge in [-1.0,1.0]:
				var offset: float = edge*(WIDTH*.5+t)
				piece("ApproachPost",at+Vector3(0,.6,offset),Vector3(.22,1.2,.22),dark)
				if i < 8:
					var next := ramp_point(side,float(i+1)/8.0)
					brace_3d(at+Vector3(0,1.15,offset),next+Vector3(0,1.15,edge*(WIDTH*.5+float(i+1)/8.0)),.16)
	batch_repeated_meshes()

func ramp_point(side: float, t: float) -> Vector3:
	var x := side*(HALF_SPAN+RAMP*t)
	var ground := layout.height(position.x+x,CROSSING_Z)
	var bank := layout.height(position.x+side*(HALF_SPAN+RAMP),CROSSING_Z)
	return Vector3(x,maxf(ground+0.04,lerpf(deck_height,bank+0.04,t)),0)

func piece(label: String, center: Vector3, extent: Vector3, material: Material, solid := false, shown := true) -> Node3D:
	var node := Node3D.new()
	node.name = label
	add_child(node)
	node.position = center
	if shown:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = extent
		mesh.mesh = box
		mesh.material_override = material
		node.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = extent
		collision.shape = shape
		body.add_child(collision)
		node.add_child(body)
	return node

func beam(a: Vector3, b: Vector3, thickness: float) -> void:
	var node := piece("Brace",(a+b)*0.5,Vector3(a.distance_to(b),thickness,thickness),dark)
	node.rotation.z = atan2(b.y-a.y,b.x-a.x)

func clear_crossing_vegetation() -> void:
	var nature := get_parent().get_node_or_null("Landscape/NatureTiles")
	if nature == null: return
	for batch in nature.find_children("*", "MultiMeshInstance3D", true, false):
		var source: MultiMesh = batch.multimesh
		var retained: Array[Transform3D] = []
		for i in source.instance_count:
			var transform: Transform3D = source.get_instance_transform(i)
			if not in_crossing(batch.to_global(transform.origin)):
				retained.append(transform)
		if retained.size() == source.instance_count: continue
		var clean := MultiMesh.new()
		clean.transform_format = MultiMesh.TRANSFORM_3D
		clean.mesh = source.mesh
		clean.instance_count = retained.size()
		for i in retained.size(): clean.set_instance_transform(i,retained[i])
		batch.multimesh = clean
	for body in nature.find_children("*", "StaticBody3D", true, false):
		if in_crossing(body.global_position): body.queue_free()

func in_crossing(p: Vector3) -> bool:
	return absf(p.x-position.x)<HALF_SPAN+RAMP+6 and absf(p.z-CROSSING_Z)<9.0

func brace_3d(a: Vector3,b: Vector3,thickness: float) -> void:
	var node := piece("TrestleBrace",(a+b)*.5,Vector3(thickness,thickness,a.distance_to(b)),dark)
	node.basis = Basis.looking_at(b-a,Vector3.UP)

func batch_repeated_meshes() -> void:
	# Keep collision nodes; consolidate repeated timber into instanced draw batches.
	var groups: Dictionary = {}
	for node in get_children():
		for child in node.get_children():
			if child is MeshInstance3D:
				var key := str(child.mesh.size)+str(child.material_override.get_instance_id())
				if not groups.has(key): groups[key] = []
				groups[key].append(child)
	for members in groups.values():
		if members.size() < 2: continue
		var batch := MultiMeshInstance3D.new()
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = members[0].mesh
		instances.instance_count = members.size()
		batch.multimesh = instances
		batch.material_override = members[0].material_override
		add_child(batch)
		for i in members.size():
			instances.set_instance_transform(i,members[i].get_parent().transform*members[i].transform)
			members[i].queue_free()
