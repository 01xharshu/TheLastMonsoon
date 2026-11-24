extends RefCounted
## Timber-and-thatch market granary: static dressing on the existing village store.
## Its open south loading face keeps the existing market and gate circulation.
const SIDE_SHED_ORIGIN := Vector3(-9,0,.1)
const Sack = preload("res://objects/household/grain_sack.tscn")

func build(village, shed: Node3D) -> void:
	var b = village.settlement
	var boards := ShaderMaterial.new()
	boards.shader = preload("res://world/suryagarh/settlements/village_surface.gdshader")
	boards.set_shader_parameter("surface_kind",3)
	boards.set_shader_parameter("tint",Color(.54,.43,.31))
	var roof := ShaderMaterial.new()
	roof.shader = preload("res://world/suryagarh/settlements/village_surface.gdshader")
	roof.set_shader_parameter("surface_kind",1)
	roof.set_shader_parameter("tint",Color(.48,.39,.26))
	# The front deck edge stays at -2.5, aligned with the existing ramp.
	village._piece(shed,"StoreFloor",Vector3(0,.08,1.5),Vector3(14,.16,8),b.wood)
	# Thin seams make the raised timber deck read as boards.
	for i in range(-5,13):
		village._piece(shed,"FloorPlankSeam",Vector3(0,.162,float(i)*.42),Vector3(13.8,.004,.018),b.wood,false)
	# Shallow timber loading ramp joins the ground to the existing raised floor.
	var ramp: Node3D = village._piece(shed,"LoadingRamp",Vector3(0,.08,-3.10),Vector3(3.35,.10,1.45),b.wood)
	ramp.rotation.x = -atan2(.16,1.45)
	# Three supported timber walls; the loading face remains a broad open bay.
	village._piece(shed,"TimberRearWall",Vector3(0,1.69,5.43),Vector3(13.8,3.12,.14),boards)
	for side in [-1.0,1.0]:
		village._piece(shed,"TimberSideWall",Vector3(side*6.89,1.69,1.5),Vector3(.14,3.12,7.86),boards)
		village._piece(shed,"LoadingBayPier",Vector3(side*4.62,1.69,-2.43),Vector3(4.55,3.12,.14),boards)
		var pitch: Node3D = village._piece(shed,"ThatchedRoof",Vector3(side*3.6,4.08,1.5),Vector3(7.5,.16,8.8),roof,false)
		pitch.rotation.z = -side*.23
		village._piece(shed,"RoofBearer",Vector3(side*6.73,3.21,1.5),Vector3(.16,.15,8.0),b.wood,false)
		for z in [-2.2,1.5,5.2]:
			village._piece(shed,"StorePost",Vector3(side*6.73,1.64,z),Vector3(.18,3.0,.18),b.wood)
	for x in range(-13,14):
		village._piece(shed,"RearPlankBatten",Vector3(float(x)*.5,1.68,5.51),Vector3(.035,3.05,.035),b.wood,false)
	for side in [-1.0,1.0]:
		for i in range(-4,11):
			village._piece(shed,"SidePlankBatten",Vector3(side*6.98,1.68,float(i)*.5),Vector3(.035,3.05,.035),b.wood,false)
		for x in [2.48,2.88,3.28,3.68,4.08,4.48,4.88,5.28,5.68,6.08,6.48,6.88]:
			village._piece(shed,"FrontPlankBatten",Vector3(side*x,1.68,-2.53),Vector3(.035,3.05,.035),b.wood,false)
	village._piece(shed,"LoadingLintel",Vector3(0,2.90,-2.43),Vector3(4.8,.38,.16),b.wood,false)
	# Low timber receiving platform keeps sacks off the damp floor.
	village._piece(shed,"SackReceivingPlatform",Vector3(-1.25,.58,-.30),Vector3(.75,.84,1.70),b.wood)
	# Reusable collision-bearing sacks sit outside the clear central opening.
	for i in 3:
		var sack: Node3D = Sack.instantiate()
		sack.name = "OutdoorGrainSack%d" % i
		sack.position = Vector3(3.65 + float(i%2)*.34, 0, -2.80 - float(i/2)*.38)
		var ground := shed.to_global(sack.position)
		sack.position.y = b.layout.height(ground.x,ground.z) - shed.global_position.y
		sack.scale = Vector3.ONE*.72
		sack.set_meta("contents","bagged grain awaiting storage")
		shed.add_child(sack)
	_build_lean_to(village,shed,boards,roof)
	shed.set_meta("grain_storehouse",true)
	shed.set_meta("construction","timber walls, thatch, raised market floor")

func _build_lean_to(village, store: Node3D, boards: Material, thatch: Material) -> void:
	var b = village.settlement
	var annex := Node3D.new()
	annex.name = "GrainSideShed"
	store.add_child(annex)
	annex.position = SIDE_SHED_ORIGIN
	# The store wall forms the high side. Keep the front and yard side open.
	village._piece(annex,"ShedDeck",Vector3(0,.06,0),Vector3(4,.12,5.2),b.wood)
	village._piece(annex,"ShedBack",Vector3(0,1.02,2.53),Vector3(4,1.8,.14),boards)
	var pitch: Node3D = village._piece(annex,"ShedThatch",Vector3(0,2.65,0),Vector3(4.4,.14,5.75),thatch,false)
	pitch.rotation.z = .22
	village._piece(annex,"ShedLedger",Vector3(1.94,2.98,0),Vector3(.18,.16,5.2),b.wood,false)
	village._piece(annex,"ShedEaveBeam",Vector3(-1.8,2.20,0),Vector3(.18,.16,5.2),b.wood,false)
	for z in [-2.42,.12,2.42]:
		village._piece(annex,"ShedPost",Vector3(-1.8,1.12,z),Vector3(.21,2.24,.21),b.wood)
		var brace: Node3D = village._piece(annex,"ShedBrace",Vector3(-1.54,1.94,z),Vector3(.12,.73,.12),b.wood,false)
		brace.rotation.z = -.75
	for i in 3:
		var sack: Node3D = Sack.instantiate()
		sack.name = "CoveredGrainSack%d" % i
		annex.add_child(sack)
		sack.position = Vector3(.38 + float(i)*.58,.12,1.74)
		sack.scale = Vector3.ONE * (1.0 - float(i)*.08)
