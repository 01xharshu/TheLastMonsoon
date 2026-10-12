extends RefCounted
## Oudh 1895 descriptions inform this reversible 1857 production candidate.
func furnish(village, home: Node3D) -> void:
	var b = village.settlement
	var detail = village.house_detail
	var earth: Material = village.earth
	home.set_meta("livelihood","pottery")
	home.set_meta("production_flow",["clay and water","preparation board","single hand wheel","shaded drying","cold firing yard","finished store"])
	home.set_meta("firing_site","House30FiringYard")
	for label in ["HouseholdProp","PotterFlywheel","WheelAxle","WheelHead","WheelVessel"]:
		var old := home.get_node_or_null(label)
		if old: old.free()
	var kit := Node3D.new()
	kit.name = "PotteryKit"
	home.add_child(kit)
	detail._cylinder(kit,"WheelGroundBearing",Vector3(2.25,.04,4.5),.14,.08,b.stone,true)
	detail._cylinder(kit,"SingleWheelAxis",Vector3(2.25,.355,4.5),.045,.63,b.wood,true)
	detail._cylinder(kit,"SingleClayWheel",Vector3(2.25,.70,4.5),.46,.075,detail.clay,true)
	_pot(detail,kit,"WheelWorkpiece",Vector3(2.25,.7375,4.5),.75)
	kit.set_meta("wheel_basis","single hand-spun clay wheel; Dobbs 1895 p7; 1857 dimensions provisional")
	# Clay preparation stays outside domestic cooking/sleeping circulation.
	b.piece(kit,"PreparationBoard",Vector3(3.6,.09,5.55),Vector3(1.1,.18,.70),b.wood)
	for i in 3:
		detail._cylinder(kit,"PreparedClay",Vector3(3.30+i*.28,.24,5.55),.11,.12,earth,false)
	_pot(detail,kit,"WorkingWaterJar",Vector3(3.5,0,4.45),1.0)
	# Existing three drying vessels are retained beneath the left shade.
	b.piece(kit,"DryingBoard",Vector3(-3.0,.04,4.5),Vector3(2.2,.08,.75),b.wood)
	for node in home.get_children():
		if node is Node3D and node.get_meta("earthen_vessel",false) and is_equal_approx(node.position.y,0.0) and is_equal_approx(node.position.z,4.5):
			node.position.y = .08
			node.set_meta("pottery_role", "drying")
			detail._cylinder(node,"DryingVesselFoot",Vector3.UP*.009,.099,.018,detail.clay,false)
			var foot: MeshInstance3D = node.get_node("DryingVesselFoot").get_child(0)
			foot.name = "DryingVesselFoot"
			foot.set_surface_override_material(0,detail.clay)
			foot.material_override = null
	# Finished fired wares are indoors on an independently supported deck.
	b.piece(kit,"FinishedStore",Vector3(3.4,.485,1.1),Vector3(1.5,.09,.85),b.wood)
	for x in [2.8,4.0]:
		for z in [.80,1.4]:
			b.piece(kit,"StoreLeg",Vector3(x,.34,z),Vector3(.10,.20,.10),b.wood)
	for i in 3: _pot(detail,kit,"FinishedPot",Vector3(2.9+i*.5,.53,1.1),.82)
	for x in [3.63,3.97]:
		b.piece(kit,"LampShelfCorbel",Vector3(x,1.22,3.3),Vector3(.15,.20,.24),b.wood,false)
	# Cold covered clamp candidate, away from roofs and daily frontage.
	var yard: Node3D = village._root("House30FiringYard",Vector2(-356,153))
	yard.set_meta("household_id","BhairavpurHouse30")
	yard.set_meta("state","cold; no active fire or weather-independent firing simulation")
	yard.set_meta("basis","Dobbs 1895 p11; cover above pit represented, terrain not excavated")
	b.piece(yard,"ClearedWorkingGround",Vector3(0,.008,0),Vector3(6,.016,6),earth,false)
	var cone := CylinderMesh.new()
	cone.top_radius = .17
	cone.bottom_radius = 1.28
	cone.height = 1.05
	cone.radial_segments = 24
	cone.cap_top = false
	cone.cap_bottom = false
	var cover := MeshInstance3D.new()
	cover.name = "ColdEarthCover"
	cover.mesh = cone
	cover.material_override = earth
	cover.position.y = .535
	yard.add_child(cover)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.28
	shape.height = 1.05
	collision.shape = shape
	collision.position.y = .535
	body.add_child(collision)
	yard.add_child(body)
	# Open-neck pot sections indicate the central flue, without a modern chimney.
	var flue_mesh := CylinderMesh.new()
	flue_mesh.top_radius = .13
	flue_mesh.bottom_radius = .13
	flue_mesh.height = .31
	flue_mesh.radial_segments = 16
	flue_mesh.cap_top = false
	flue_mesh.cap_bottom = false
	for i in 2:
		var flue := MeshInstance3D.new()
		flue.name = "OpenFlueSection"
		flue.mesh = flue_mesh
		flue.material_override = detail.clay
		flue.position.y = 1.215+i*.31
		yard.add_child(flue)
	for i in 9:
		var chip = b.piece(yard,"SpentSherd",Vector3(-1.8+float(i%3)*.19,.027,1.3+float(i/3)*.16),Vector3(.15,.03,.11),detail.clay,false)
		chip.rotation.y = float(i)*.62
	kit.set_meta("actions","decorative; no pot throwing or firing action")

func _pot(detail,parent: Node3D,label: String,at: Vector3,size: float) -> void:
	var vessel: Node3D = detail._pot(parent,label,at,size)
	vessel.set_meta("pottery_role", label)
	# Flat earthen foot completes the shared profile's pointed lower envelope.
	detail._cylinder(vessel,label+"Foot",Vector3.UP*.01*size,.11*size,.02*size,detail.clay,false)
	var foot: MeshInstance3D = vessel.get_node(label+"Foot").get_child(0)
	foot.name = label+"Foot"
	foot.set_surface_override_material(0,detail.clay)
	foot.material_override = null
