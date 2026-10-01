extends "res://tools/assets/build_activity_sets.gd"
func save_obstacle(node: Node3D, filename: String) -> void:
	marker(node,"Approach",Vector3(0,0,.85))
	own_set(node,node)
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	assert(ResourceSaver.save(packed,"res://objects/obstacles/"+filename+".tscn") == OK)
	node.free()
func build() -> void:
	var wood := material(Color(.32,.22,.12))
	var iron := material(Color(.10,.11,.105))
	var stone := material(Color(.40,.38,.32))
	var fence := Node3D.new()
	fence.name = "TimberFencePanel"
	for x in [-1.0,1.0]: part(fence,"Post",Vector3(.12,1.25,.12),Vector3(x,.625,0),wood)
	for y in [.38,.95]: part(fence,"Rail",Vector3(2.0,.10,.07),Vector3(0,y,0),wood)
	for i in 9: part(fence,"Paling",Vector3(.08,1.05,.045),Vector3(-.88+i*.22,.62,.058),wood)
	marker(fence,"JoinLeft",Vector3(-1,0,0))
	marker(fence,"JoinRight",Vector3(1,0,0))
	save_obstacle(fence,"timber_fence")
	var barricade := Node3D.new()
	barricade.name = "TimberBarricade"
	for x in [-.8,.8]:
		part(barricade,"Foot",Vector3(.15,.12,.8),Vector3(x,.06,0),wood)
		part(barricade,"Upright",Vector3(.12,1.12,.12),Vector3(x,.62,0),wood)
	for y in [.45,.72,.99]: part(barricade,"Plank",Vector3(1.95,.18,.08),Vector3(0,y,.09),wood)
	marker(barricade,"HandholdLeft",Vector3(-.6,1.08,.13))
	marker(barricade,"HandholdRight",Vector3(.6,1.08,.13))
	save_obstacle(barricade,"timber_barricade")
	var cover := Node3D.new()
	cover.name = "LowMasonryCover"
	for row in 4:
		for i in 5:
			part(cover,"Stone",Vector3(.394,.225,.46),Vector3(-.8+i*.4,.1125+row*.23,0),stone)
	marker(cover,"CoverLeft",Vector3(-.72,0,.58))
	marker(cover,"CoverRight",Vector3(.72,0,.58))
	marker(cover,"TopContact",Vector3(0,.915,.23))
	save_obstacle(cover,"low_masonry_cover")
	var gate := Node3D.new()
	gate.name = "TimberGateComponent"
	for x in [-.9,.9]: part(gate,"GatePost",Vector3(.16,1.55,.16),Vector3(x,.775,0),wood)
	var hinge := Node3D.new()
	hinge.name = "HingePivot"
	hinge.position = Vector3(-.8,0,0)
	gate.add_child(hinge)
	for i in 8: part(hinge,"LeafBoard",Vector3(.185,1.15,.055),Vector3(.10+i*.20,.70,0),wood)
	for y in [.32,1.08]:
		part(hinge,"BackRail",Vector3(1.59,.10,.07),Vector3(.8,y,-.055),wood)
		box(hinge,"HingeStrap",Vector3(.36,.055,.014),Vector3(.18,y,.037),iron)
	box(hinge,"Latch",Vector3(.20,.035,.035),Vector3(1.50,.77,.055),iron)
	marker(hinge,"HandleContact",Vector3(1.50,.77,.08))
	marker(gate,"OpeningCenter",Vector3(0,0,0))
	gate.set_meta("swing_range_degrees",Vector2(0,-95))
	gate.set_meta("interaction_status","hinge component; controller and hero animation deferred")
	save_obstacle(gate,"timber_gate")
	print("OBSTACLES: four components built")
	quit()
