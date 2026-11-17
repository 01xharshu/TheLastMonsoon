extends SceneTree
## Focused structural check; full-world navigation and rendering require separate review.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var builder: Node3D = load("res://tools/world/opening_house_builder.gd").new()
	root.add_child(builder)
	var village = load("res://world/suryagarh/settlements/bhairavpur_village.gd").new()
	village.settlement = builder
	var shed := Node3D.new()
	shed.name = "BhairavpurGrainStore"
	builder.add_child(shed)
	shed.position = Vector3(-280,builder.layout.height(-280,285),285)
	load("res://world/suryagarh/settlements/grain_storehouse_detail.gd").new().build(village,shed)
	for x in [-2.2,0.0,2.2]:
		village._piece(shed,"GrainBin",Vector3(x,.5,1.42),Vector3(1.6,.84,1.3),builder.wood)
	var counter: Node3D = load("res://objects/household/sets/market_supply.tscn").instantiate()
	counter.position = Vector3(2.45,.16,-1.65)
	shed.add_child(counter)
	await physics_frame
	var failures: Array[String] = []
	if not shed.get_meta("grain_storehouse",false): failures.append("storehouse metadata")
	if shed.find_children("OutdoorGrainSack*","Node3D",false,false).size()!=3: failures.append("three outside sacks")
	var ray := PhysicsRayQueryParameters3D.create(shed.to_global(Vector3(0,1.2,-4)),shed.to_global(Vector3(0,1.2,.4)),1)
	if not shed.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): failures.append("loading opening blocked")
	for sack in shed.find_children("OutdoorGrainSack*","Node3D",false,false):
		var at: Vector3 = sack.global_position
		if absf(at.y-builder.layout.height(at.x,at.z)) > .01: failures.append("sack ground support")
	print("GRAIN STOREHOUSE: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	preload("res://tools/test_audio_cleanup.gd").finish(self,0 if failures.is_empty() else 1)
