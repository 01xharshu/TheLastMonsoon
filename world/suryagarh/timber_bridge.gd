extends Node3D
## Fictional 1850s rural timber crossing: plank deck, driven piles and braced rails.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const CROSSING_Z := 165.0
const HALF_SPAN := 64.0
const RAMP := 24.0
const WIDTH := 4.2
var deck_height: float
var layout := Layout.new()
var timber: StandardMaterial3D
var dark: StandardMaterial3D

func _ready() -> void:
	position = Vector3(layout.river_x(CROSSING_Z), 0, CROSSING_Z)
	clear_crossing_vegetation()
	timber = StandardMaterial3D.new()
	timber.albedo_color = Color(0.32, 0.22, 0.13)
	timber.roughness = 0.95
	dark = timber.duplicate()
	dark.albedo_color = Color(0.19, 0.13, 0.08)
	deck_height = maxf(layout.height(position.x-HALF_SPAN,CROSSING_Z), layout.height(position.x+HALF_SPAN,CROSSING_Z)) + 0.6
	# One continuous collision slab prevents catches between visual planks.
	piece("Deck", Vector3(0,deck_height-0.15,0), Vector3(HALF_SPAN*2,0.3,WIDTH), dark, true)
	for i in 256:
		piece("Plank",Vector3(-HALF_SPAN+0.25+i*0.5,deck_height+0.025,0),Vector3(0.48,0.05,WIDTH+0.16),timber)
	for side in [-1.0,1.0]:
		for i in 33:
			var x: float = -HALF_SPAN+i*4.0
			var bottom: float = layout.height(position.x+x,CROSSING_Z+side*1.9)-0.5
			piece("Pile",Vector3(x,(bottom+deck_height+1.2)*0.5,side*1.9),Vector3(0.24,deck_height+1.2-bottom,0.24),dark)
			if i < 32:
				beam(Vector3(x,deck_height+0.2,side*1.9),Vector3(x+4,deck_height+1.08,side*1.9),0.12)
		piece("Handrail",Vector3(0,deck_height+1.15,side*1.9),Vector3(128,0.16,0.2),timber)
		piece("RailCollision",Vector3(0,deck_height+0.6,side*2.04),Vector3(128,1.3,0.15),dark,true,false)
		piece("Stringer",Vector3(0,deck_height-0.42,side*1.5),Vector3(128,0.5,0.28),dark)
	# Ramps follow a smooth bank-to-deck profile and overlap the ground at their ends.
	for side in [-1.0,1.0]:
		for i in 48:
			var a := ramp_point(side,float(i)/48.0)
			var b := ramp_point(side,float(i+1)/48.0)
			var center := (a+b)*0.5-Vector3(0,0.1,0)
			var segment := piece("Approach",center,Vector3(a.distance_to(b)+0.03,0.2,WIDTH),timber,true)
			segment.rotation.z = atan2(b.y-a.y,b.x-a.x)

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
	var nature := get_parent().get_node("Landscape/NatureTiles")
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
