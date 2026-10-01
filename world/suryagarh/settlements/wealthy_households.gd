extends "res://world/suryagarh/settlements/settlement_builder.gd"
## Fictional household prototypes on existing surveyed flat plots.
const Actor = preload("res://characters/npcs/households/household_npc_actor.gd")
const Coach = preload("res://vehicles/family_carriage_candidate.gd")
const Travel = preload("res://world/suryagarh/settlements/household_coach_travel.gd")
var homes: Dictionary = {}

func _ready() -> void:
	plaster=material(Color(.83,.77,.64)); wood=material(Color(.25,.14,.08))
	stone=material(Color(.52,.47,.38)); tile=material(Color(.47,.24,.14))
	iron=material(Color(.15,.15,.14)); ochre=material(Color(.61,.42,.24))
	call_deferred("_build_households")

func _anchor(label: String, at: Vector3, kind: String) -> Node3D:
	var home:=Node3D.new()
	home.name=label; home.position=at; add_child(home)
	home.add_to_group("wealthy_household")
	home.set_meta("household_kind",kind)
	home.set_meta("residence_status","inhabited candidate")
	homes[label]=home
	return home

func _build_households() -> void:
	# Preserve twelve village crop beds while clearing the new house/drive footprint.
	var moved:=0
	for garden in get_tree().get_nodes_in_group("bhairavpur_garden"):
		if garden.global_position.z>=260.0:
			garden.global_position=Vector3(-430,7.2,162+moved*14)
			moved+=1
	var landlord:=_anchor("LandownerHousehold",Vector3(-321,7.2,344),"landowner")
	landlord.set_meta("existing_building","Settlement/BhairavpurLandownerEstate")
	_furniture(landlord,Vector3(-13,.24,4),false)
	_furniture(landlord,Vector3(13,.24,6),true)
	_service(landlord,Vector3(28,0,-21))
	_shelter(landlord,Vector3(39,0,-21),"CoachHouse",Vector2(9,7))
	var merchant:=_anchor("MerchantHousehold",Vector3(-413,7.2,282),"wealthy_indian")
	_house(merchant,false)
	_service(merchant,Vector3(-11,0,-16))
	_shelter(merchant,Vector3(-9,0,24),"CoachHouse",Vector2(9,7))
	piece(merchant,"DriveCourt",Vector3(3,.025,20),Vector3(27,.05,10),stone,false)
	piece(merchant,"LaneConnection",Vector3(23,.025,30),Vector3(33,.05,6),stone,false)
	var british:=_anchor("BritishHousehold",Vector3(-455,8.5,-184),"british")
	_house(british,true)
	_service(british,Vector3(130,0,4))
	_shelter(british,Vector3(-20,0,-10),"CoachHouse",Vector2(9,6))
	piece(british,"CarriageSideAvenue",Vector3(-20,.03,36),Vector3(8,.06,58),stone,false)
	piece(british,"VerandaCoachWalk",Vector3(-10,.03,10),Vector3(24,.06,3),stone,false)
	for home in homes.values():
		var kitchen:Vector3=home.get_meta("kitchen_position")
		_staff(home,"Cook",kitchen+Vector3(1,.12,-1.9),"village_woman",Vector3.BACK)
		_staff(home,"WaterBearer",kitchen+Vector3(3,0,4),"village_farmer",Vector3.FORWARD)
		merge_visuals(home)
	var landowner:=_person(landlord,"Landowner",Vector3(-12,.24,1),"res://characters/npcs/households/landowner.glb")
	var trader:=_person(merchant,"Merchant",Vector3(3,.24,1),"res://characters/npcs/households/merchant.glb")
	var roster:=get_parent().get_node("BritishNpcRosterCandidate")
	var couple:Array[Node3D]=[]
	for label in ["OfficialMan","OfficialWoman"]:
		var actor:=roster.get_node(label) as Node3D
		actor.global_position=british.to_global(Vector3(-1 if label=="OfficialMan" else 2,.24,2))
		actor.set("_home",actor.position); actor.set("movement_enabled",false)
		actor.set_meta("household","BritishHousehold"); couple.append(actor)
	_coach(landlord,[landowner],[Vector3(-316,7.24,344),Vector3(-321,7.24,337),Vector3(-321,7.24,315)])
	_coach(merchant,[trader],[Vector3(-410,7.24,303),Vector3(-410,7.24,330),Vector3(-379,7.24,330)])
	_coach(british,couple,[Vector3(-475,8.56,-173),Vector3(-475,8.56,-124)])
	print("WEALTHY HOUSEHOLDS READY | 3 homes, 9 staff, 4 residents, 3 household coaches")

func _house(home:Node3D,british:bool) -> void:
	var wall:Material=plaster if british else material(Color(.72,.57,.39))
	piece(home,"HouseFloor",Vector3(0,.12,0),Vector3(20,.24,12),stone)
	piece(home,"RearWall",Vector3(0,1.85,-6),Vector3(20,3.7,.35),wall)
	for side in [-1.0,1.0]:
		# Side windows: sill, lintel and piers leave actual openings.
		piece(home,"WindowSill",Vector3(side*10,.55,0),Vector3(.35,1.1,12),wall)
		piece(home,"WindowLintel",Vector3(side*10,3.2,0),Vector3(.35,1.0,12),wall)
		for z in [-5.0,0.0,5.0]:
			piece(home,"WindowPier",Vector3(side*10,1.9,z),Vector3(.35,1.6,2),wall)
		for z in [-2.5,2.5]:
			var openings := preload("res://world/suryagarh/settlements/bhairavpur_house_detail.gd").new()
			openings.settlement=self
			openings._window_frame(home,Vector3(side*10,1.1,z),Vector2(3.0,1.6),side*PI*.5,false,not british)
			if british:
				for bar in 12: piece(home,"IronWindowBar",Vector3(side*10,1.9,z-1.375+bar*.25),Vector3(.055,1.6,.04),iron,false)
				openings._window_barrier(home,Vector3(side*10,1.9,z),Vector3(.10,1.6,3.0))
		piece(home,"EntranceWall",Vector3(side*5.7,1.85,6),Vector3(8.6,3.7,.35),wall)
		piece(home,"PrivateRoomPartition",Vector3(side*5.8,1.65,-1),Vector3(8.4,2.8,.18),wall)
		piece(home,"RoofSlope",Vector3(side*5,4.35,0),Vector3(10.8,.22,14),tile).rotation.z=-side*.16
		_furniture(home,Vector3(side*5,.24,-3.5),side>0)
	piece(home,"DoorHeader",Vector3(0,3.25,6),Vector3(3,1,.4),wall)
	var entrance := preload("res://objects/hinged_door.gd").new()
	entrance.name="EntranceDoor"
	entrance.width=2.8
	entrance.height=2.6
	entrance.position=Vector3(-1.4,.24,6.22)
	entrance.build(wood)
	home.add_child(entrance)
	piece(home,"VerandaFloor",Vector3(0,.12,8.5),Vector3(23,.24,5),stone)
	piece(home,"VerandaRoof",Vector3(0,3.6,8.5),Vector3(24,.25,6),tile)
	for x in [-10.0,-5.0,5.0,10.0]: column(home,Vector3(x,1.95,10.5),3.5)
	piece(home,"ThresholdRamp",Vector3(0,.07,11.7),Vector3(3,.14,1.5),stone)
	home.set_meta("entrance",home.to_global(Vector3(0,.24,11)))

func _furniture(home:Node3D,at:Vector3,bed:bool) -> void:
	if bed:
		piece(home,"ResidentBed",at+Vector3(0,.45,0),Vector3(2.4,.18,1.4),wood)
		piece(home,"BedMattress",at+Vector3(0,.60,0),Vector3(2.3,.15,1.3),plaster,false)
		for x in [-1.0,1.0]:
			for z in [-.5,.5]:piece(home,"BedLeg",at+Vector3(x,.21,z),Vector3(.13,.42,.13),wood)
	else:
		piece(home,"ReceptionTable",at+Vector3(0,.83,0),Vector3(2.1,.14,1.1),wood)
		for x in [-.9,.9]:piece(home,"TableLeg",at+Vector3(x,.41,0),Vector3(.14,.82,.85),wood)
		piece(home,"AccountLedger",at+Vector3(.3,.94,0),Vector3(.42,.07,.3),ochre,false)
		piece(home,"GuestBench",at+Vector3(0,.45,2),Vector3(2,.2,.55),wood)
	piece(home,"StorageChest",at+Vector3(2,.43,-1),Vector3(.9,.7,.55),wood)

func _shelter(home:Node3D,at:Vector3,label:String,size:Vector2) -> void:
	var shed:=Node3D.new();shed.name=label; shed.position=at;home.add_child(shed)
	piece(shed,"Floor",Vector3(0,.06,0),Vector3(size.x,.12,size.y),stone)
	piece(shed,"RearWall",Vector3(0,1.6,-size.y*.5),Vector3(size.x,3.2,.25),plaster)
	piece(shed,"Roof",Vector3(0,3.35,0),Vector3(size.x+.5,.22,size.y+.5),tile)
	for side in [-1.0,1.0]:piece(shed,"SideWall",Vector3(side*size.x*.5,1.6,0),Vector3(.22,3.2,size.y),plaster)
	if label=="ServantQuarters":
		for side in [-1.0,1.0]:piece(shed,"DoorWall",Vector3(side*(size.x*.25+.35),1.6,size.y*.5),Vector3(size.x*.5-.7,3.2,.22),plaster)
		piece(shed,"DoorHead",Vector3(0,2.85,size.y*.5),Vector3(1.4,.7,.22),plaster)
	for x in [-size.x*.5,size.x*.5]:piece(shed,"Support",Vector3(x,1.6,size.y*.5),Vector3(.25,3.2,.25),wood)
	if label=="CoachHouse":
		piece(shed,"HarnessRack",Vector3(0,1.3,-size.y*.5+.3),Vector3(3,.12,.16),wood,false)
		piece(shed,"HorseTrough",Vector3(size.x*.5-1,.45,0),Vector3(.7,.7,2),wood)

func _service(home:Node3D,at:Vector3) -> void:
	_shelter(home,at,"Kitchen",Vector2(7,6))
	_shelter(home,at+Vector3(0,0,8),"ServantQuarters",Vector2(7,6))
	piece(home,"CookingHearth",at+Vector3(-2,.35,-1),Vector3(1.4,.6,1),stone)
	piece(home,"PreparationTable",at+Vector3(1,.85,-1),Vector3(2,.18,1),wood)
	for x in [.15,1.85]:piece(home,"PreparationTableLeg",at+Vector3(x,.4,-1),Vector3(.13,.8,.8),wood)
	piece(home,"CookingPan",at+Vector3(-2,.71,-1),Vector3(.8,.10,.6),iron,false)
	piece(home,"WaterStorage",at+Vector3(3,.55,3),Vector3(.65,1.1,.65),ochre)
	for x in [-2.0,1.0]:
		piece(home,"ServantCot",at+Vector3(x,.35,8),Vector3(1.8,.2,.75),wood)
	piece(home,"ServiceWalk",at+Vector3(0,.02,4),Vector3(4,.04,8),stone,false)
	home.set_meta("kitchen_position",at)

func _person(home:Node3D,label:String,at:Vector3,path:String) -> Node3D:
	var actor:=Actor.new() as Node3D
	actor.name=home.name+label; actor.position=home.to_global(at)
	actor.set("patrol_distance",0.0);actor.set("movement_enabled",false)
	actor.set_meta("household",str(home.name));actor.add_to_group("household_resident")
	actor.add_child(load(path).instantiate());add_child(actor)
	return actor

func _staff(home:Node3D,job:String,at:Vector3,slug:String,axis:Vector3) -> Node3D:
	var actor:=Actor.new() as Node3D
	actor.name=home.name+job;actor.position=home.to_global(at)
	actor.set("household_job",job)
	if job=="Cook" or job=="Coachman":actor.set("movement_enabled",false)
	actor.set("patrol_distance",.45);actor.set("patrol_axis",axis)
	actor.set("cycle_offset",float(get_tree().get_nodes_in_group("household_staff").size()))
	actor.set("movement_profile",&"female" if slug=="village_woman" else &"male")
	actor.set_meta("household",str(home.name));actor.set_meta("job",job)
	actor.add_to_group("household_staff")
	var document:=GLTFDocument.new();var state:=GLTFState.new()
	var path:="res://WorkingAssets/NPCs/%s/%s_rigged_candidate.glb"%[slug,slug]
	if document.append_from_file(ProjectSettings.globalize_path(path),state)!=OK:return null
	actor.add_child(document.generate_scene(state));add_child(actor)
	if job=="WaterBearer":
		var pot:=MeshInstance3D.new();pot.name="CarriedWaterPot"
		var mesh:=_carried_pot_mesh()
		pot.mesh=mesh;pot.material_override=ochre;pot.position=Vector3(0,.76,.27)
		actor.add_child(pot)
	return actor

func _coach(home:Node3D,people:Array[Node3D],route:Array[Vector3]) -> void:
	var coach:=Coach.new();coach.name=home.name+"Coach"
	coach.position=route[0];add_child(coach)
	coach.add_to_group("household_coach")
	coach.set_meta("household",str(home.name))
	# Household traffic has occupied seats; public playable carts remain separate.
	for child in coach.get_children():
		if child.name.ends_with("Boarding"):child.queue_free()
	var driver:=_staff(home,"Coachman",home.to_local(route[0]),"village_farmer",Vector3.FORWARD)
	var travel:=Travel.new();travel.name="HouseholdTravel";travel.configure(coach,people,route,driver)
	coach.add_child(travel)
	var office_center:=route[-1]+Vector3(12,-.04,-18 if home.name=="MerchantHousehold" else 0)
	var office:=_workplace(home,office_center)
	var home_path:Array[Vector3]=[]
	if str(home.name)=="LandownerHousehold":
		home_path=[home.to_global(Vector3(-8,.24,1)),home.to_global(Vector3(0,.24,1))]
	else:
		home_path=[home.to_global(Vector3(0,.24,4)),home.to_global(Vector3(0,.24,10.6)),home.to_global(Vector3(0,.0,15))]
	travel.configure_journeys(home_path,office)

func _carried_pot_mesh() -> ArrayMesh:
	# Rounded vessel with a recessed inner rim; radius at hand height is .135 m.
	var profile:=[Vector2(.075,-.15),Vector2(.12,-.12),Vector2(.15,-.045),Vector2(.135,.035),Vector2(.085,.12),Vector2(.095,.145),Vector2(.082,.145),Vector2(.074,.105)]
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in profile.size()-1:
		for segment in 48:
			var points:Array[Vector3]=[]
			for entry in [[row,segment],[row,(segment+1)%48],[row+1,segment],[row+1,(segment+1)%48]]:
				var ring:Vector2=profile[entry[0]];var angle:=TAU*float(entry[1])/48.0
				points.append(Vector3(cos(angle)*ring.x,ring.y,sin(angle)*ring.x))
			for index in [0,1,2,1,3,2]:surface.add_vertex(points[index])
	surface.index();surface.generate_normals()
	return surface.commit()

func _workplace(home:Node3D,at:Vector3) -> Node3D:
	var office:=Node3D.new();office.name=str(home.name)+"Office";office.position=at;add_child(office)
	office.add_to_group("household_office")
	piece(office,"Floor",Vector3(0,.12,0),Vector3(8,.24,6),stone)
	piece(office,"RearWall",Vector3(0,1.7,-3),Vector3(8,3.4,.25),plaster)
	for side in [-1.0,1.0]:
		piece(office,"SideWall",Vector3(side*4,1.7,0),Vector3(.25,3.4,6),plaster)
		piece(office,"DoorPier",Vector3(side*2.65,1.7,3),Vector3(2.7,3.4,.25),plaster)
		piece(office,"Desk",Vector3(side*1.6,.99,-.45),Vector3(1.7,.14,.8),wood)
		for x in [-.65,.65]:piece(office,"DeskLeg",Vector3(side*1.6+x,.59,-.45),Vector3(.12,.94,.65),wood)
		piece(office,"Ledger",Vector3(side*1.6,1.09,-.10),Vector3(.4,.04,.3),ochre,false)
		piece(office,"ChairSeat",Vector3(side*1.6,.69,.35),Vector3(.6,.12,.55),wood)
		piece(office,"ChairBack",Vector3(side*1.6,1.1,.6),Vector3(.6,.8,.1),wood)
		for dx in [-.23,.23]:
			for z in [.12,.57]:piece(office,"ChairLeg",Vector3(side*1.6+dx,.46,z),Vector3(.07,.46,.07),wood)
	piece(office,"DoorLintel",Vector3(0,3,3),Vector3(2.6,.8,.3),plaster)
	piece(office,"Roof",Vector3(0,3.48,0),Vector3(8.6,.2,6.6),tile)
	piece(office,"EntranceRamp",Vector3(0,.06,3.75),Vector3(2.6,.12,1.5),stone)
	merge_visuals(office)
	return office
