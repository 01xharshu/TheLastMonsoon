extends RefCounted
## Timber-and-thatch market granary: static dressing on the existing village store.
## Its open south loading face keeps the existing market and gate circulation.
const Sack = preload("res://objects/household/grain_sack.tscn")

func build(village, shed: Node3D) -> void:
	var b = village.settlement
	var old_shade := shed.get_node_or_null("StoreShade")
	if old_shade != null: old_shade.free()
	var boards: Material = b.material(Color(.43,.34,.25))
	var roof := ShaderMaterial.new()
	roof.shader = preload("res://world/suryagarh/settlements/village_surface.gdshader")
	roof.set_shader_parameter("surface_kind",1)
	roof.set_shader_parameter("tint",Color(.48,.39,.26))
	# Thin seams make the raised timber deck read as boards.
	for i in range(-5,6):
		village._piece(shed,"FloorPlankSeam",Vector3(0,.162,float(i)*.42),Vector3(6.7,.004,.018),b.wood,false)
	# Shallow timber loading ramp joins the ground to the existing raised floor.
	var ramp: Node3D = village._piece(shed,"LoadingRamp",Vector3(0,.08,-3.10),Vector3(3.35,.10,1.45),b.wood)
	ramp.rotation.x = -atan2(.16,1.45)
	# Three supported timber walls; the loading face remains a broad open bay.
	village._piece(shed,"TimberRearWall",Vector3(0,1.69,2.43),Vector3(6.75,3.12,.14),boards)
	for side in [-1.0,1.0]:
		village._piece(shed,"TimberSideWall",Vector3(side*3.38,1.69,0),Vector3(.14,3.12,4.8),boards)
		village._piece(shed,"LoadingBayPier",Vector3(side*2.66,1.69,-2.43),Vector3(1.45,3.12,.14),boards)
		var pitch: Node3D = village._piece(shed,"ThatchedRoof",Vector3(side*1.78,3.45,0),Vector3(3.85,.16,5.7),roof,false)
		pitch.rotation.z = -side*.23
		village._piece(shed,"RoofBearer",Vector3(side*3.25,3.08,0),Vector3(.16,.15,5.2),b.wood,false)
	for x in range(-6,7):
		village._piece(shed,"RearPlankBatten",Vector3(float(x)*.5,1.68,2.53),Vector3(.035,3.05,.035),b.wood,false)
	for side in [-1.0,1.0]:
		for i in range(-4,5):
			village._piece(shed,"SidePlankBatten",Vector3(side*3.48,1.68,float(i)*.5),Vector3(.035,3.05,.035),b.wood,false)
	village._piece(shed,"LoadingLintel",Vector3(0,2.90,-2.43),Vector3(4.0,.38,.16),b.wood,false)
	# Low timber receiving platform keeps sacks off the damp floor.
	village._piece(shed,"SackReceivingPlatform",Vector3(-1.25,.58,-.30),Vector3(.75,.84,1.70),b.wood)
	# Reusable collision-bearing sacks sit outside the clear central opening.
	for i in 3:
		var sack: Node3D = Sack.instantiate()
		sack.name = "OutdoorGrainSack%d" % i
		sack.position = Vector3(2.75 + float(i%2)*.34, 0, -2.80 - float(i/2)*.38)
		var ground := shed.to_global(sack.position)
		sack.position.y = b.layout.height(ground.x,ground.z) - shed.global_position.y
		sack.scale = Vector3.ONE*.72
		sack.set_meta("contents","bagged grain awaiting storage")
		shed.add_child(sack)
	shed.set_meta("grain_storehouse",true)
	shed.set_meta("construction","timber walls, thatch, raised market floor")
