extends RefCounted
## Selected modest households: timber walls retain the existing physical openings.
const TIMBER_HOMES := [9,13,15,17,21,23]
const FENCED_HOMES := [9,15,21,24]
const COOKING_HOMES := [1,5,9,13,17,21,26,30]
var builder: Node3D
var timber: Material

func configure(settlement: Node3D) -> void:
	builder = settlement
	var material := ShaderMaterial.new()
	material.shader = preload("res://world/suryagarh/settlements/building_wood.gdshader")
	material.set_shader_parameter("tint",Color(.34,.25,.16))
	timber = material

func house(home: Node3D, extent: Vector2, index: int) -> void:
	home.set_meta("wall_construction","timber" if index in TIMBER_HOMES else "earth plaster")
	home.set_meta("boundary_construction","wooden fence" if index in FENCED_HOMES else "existing")
	if index in TIMBER_HOMES:
		# Replace each wall's visible slab with individual fitted boards. The original
		# collision pieces and window/door voids remain authoritative.
		for piece: Node3D in home.get_children():
			if not (str(piece.name).begins_with("DoorPier") or str(piece.name).begins_with("DoorLintel") or str(piece.name).begins_with("WindowSillWall") or str(piece.name).begins_with("WindowHeadWall") or str(piece.name).begins_with("WindowPier") or str(piece.name).begins_with("RearSillWall") or str(piece.name).begins_with("RearHeadWall") or str(piece.name).begins_with("RearWindowPier")): continue
			for mesh: MeshInstance3D in piece.find_children("*","MeshInstance3D",true,false):
				var size: Vector3 = mesh.mesh.size
				var axis := 0 if size.x > size.z else 2
				var count := maxi(1,ceili(size[axis]/.24))
				for board in count:
					var dimensions := size
					dimensions[axis] = size[axis]/count-.006
					var at := Vector3.ZERO
					at[axis] = -size[axis]*.5+(board+.5)*size[axis]/count
					builder.piece(piece,"WallBoard",at,dimensions,timber,false)
				mesh.free()
		for gable: Node in home.get_children():
			if str(gable.name).begins_with("ClosedGable"):
				for mesh: MeshInstance3D in gable.find_children("*","MeshInstance3D",true,false): mesh.material_override=timber
		for side in [-1.0,1.0]:
			for z in [-extent.y*.5,extent.y*.5]:
				builder.piece(home,"TimberCornerPost",Vector3(side*(extent.x*.5+.04),1.64,z),Vector3(.18,2.8,.18),timber,false)
		# Modest houses have packed-earth platforms rather than a dressed stone slab.
		for mesh: MeshInstance3D in home.get_node("Plinth").find_children("*","MeshInstance3D",true,false): mesh.material_override=builder.ochre
	if index in FENCED_HOMES:
		for piece: Node in home.get_children():
			if str(piece.name).begins_with("CourtyardSide") or str(piece.name).begins_with("CourtyardFront") or str(piece.name).begins_with("CourtyardGate"): piece.free()
		var x := extent.x*.5+.4
		var rear := extent.y*.5+1.55
		var front := extent.y*.5+4.6
		for side in [-1.0,1.0]:
			_fence(home,Vector3(side*x,0,rear),Vector3(side*x,0,front),index)
			_fence(home,Vector3(side*x,0,front),Vector3(side*1.5,0,front),index)
		home.set_meta("fence_entry_width",3.0)
	if index in COOKING_HOMES:
		_cooking(home,extent,index)

func _fence(home: Node3D, start: Vector3, end: Vector3, seed_: int) -> void:
	var length := start.distance_to(end)
	var centre := (start+end)*.5
	var along := end-start
	var yaw := -atan2(along.z,along.x)
	var section := Node3D.new()
	section.name="WoodenYardFence"
	home.add_child(section)
	section.position=centre
	section.rotation.y=yaw
	for rail in [.36,.79]:
		builder.piece(section,"FenceRail",Vector3(0,rail,0),Vector3(length,.075,.075),timber,false)
	var count := maxi(2,ceili(length/.42))
	for i in range(count+1):
		var height := 1.0+float((i+seed_)%3)*.06
		builder.piece(section,"FenceStake",Vector3(-length*.5+length*i/count,height*.5,0),Vector3(.085,height,.10),timber,false).rotation.z=sin(float(i+seed_))*.025
	# One physical envelope per section keeps people from slipping between stakes.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(length,1.0,.12)
	shape.shape=box
	shape.position.y=.5
	body.add_child(shape)
	section.add_child(body)

func _cooking(home: Node3D, extent: Vector2, index: int) -> void:
	# Selected households vent through a permanently open rear window. Smoke does
	# not pass through intact thatch; no masonry chimney is imposed on timber huts.
	for label in ["CookingHearth","HearthOpening","CookingPot"]:
		var item := home.get_node_or_null(label) as Node3D
		if item != null: item.position.x=0.0
	var frame := home.get_node("TimberWindowFrameRear")
	var shutters := frame.get_node_or_null("PairedWoodShutters")
	if shutters != null: shutters.free()
	for item: Node3D in home.get_children():
		if str(item.name).begins_with("RearWindowIronBar") or (item is StaticBody3D and absf(item.position.z+extent.y*.5)<.01 and absf(item.position.x)<.01):item.free()
	for rail in frame.get_children():
		if str(rail.name).begins_with("IronGrilleCrossRail"):rail.free()
	var outlet := Vector3(0,1.9,-extent.y*.5-.28)
	if index in [26,30]:
		outlet=_chimney(home,extent)
		home.set_meta("cooking_vent","masonry flue")
	else:
		home.set_meta("cooking_vent","open rear window")
	var fire := preload("res://world/suryagarh/settlements/village_combustion.gd").new()
	fire.name="HouseCookingFire"
	fire.schedule_offset=index%4
	fire.smoke_outlet=outlet
	fire.position=Vector3(0,.42,-extent.y*.5+1.1)
	home.add_child(fire)
	fire.build(builder,true)

func _chimney(home: Node3D, extent: Vector2) -> Vector3:
	var z := -extent.y*.5+1.1
	var roof := home.get_node("TerraceRoof") as Node3D
	var centre_y := roof.position.y
	roof.free()
	var width := extent.x+.4
	var depth := extent.y+.4
	# Split both visible roof and collision around a real .40 m flue opening.
	for side in [-1.0,1.0]:
		builder.piece(home,"FlueRoofSide",Vector3(side*(width+.4)*.25,centre_y,0),Vector3((width-.4)*.5,.24,depth),builder.ochre)
	var front_length := depth*.5-z-.2
	var back_length := depth*.5+z-.2
	builder.piece(home,"FlueRoofFront",Vector3(0,centre_y,z+.2+front_length*.5),Vector3(.4,.24,front_length),builder.ochre)
	builder.piece(home,"FlueRoofBack",Vector3(0,centre_y,-depth*.5+back_length*.5),Vector3(.4,.24,back_length),builder.ochre)
	for side in [-1.0,1.0]:
		builder.piece(home,"ChimneySide",Vector3(side*.27,2.9,z),Vector3(.14,2.0,.68),builder.brick)
		builder.piece(home,"ChimneyEnd",Vector3(0,2.9,z+side*.27),Vector3(.4,2.0,.14),builder.brick)
		builder.piece(home,"FlueHoodSide",Vector3(side*.43,1.65,z),Vector3(.14,.5,.9),builder.brick)
	builder.piece(home,"FlueHoodRear",Vector3(0,1.65,z-.38),Vector3(.72,.5,.14),builder.brick)
	for side in [-1.0,1.0]:
		builder.piece(home,"HoodShoulder",Vector3(side*.4,1.97,z),Vector3(.26,.16,.9),builder.brick)
	return Vector3(0,4.02,z)
