extends Node3D
## Connected western city: market arrival, inhabited lanes, civilian care and college.
const Layout=preload("res://world/suryagarh/landscape_layout.gd")
const Builder=preload("res://world/suryagarh/settlements/settlement_builder.gd")
const Door=preload("res://objects/hinged_door.gd")
const Startup=preload("res://systems/world_startup.gd")
var b=Builder.new()
var layout=Layout.new()
var homes:Array[Node3D]=[]
var community:Node3D
var classified:=false
var setup_age:=0.0
var startup_task:=-1

func _ready() -> void:
	name="UrbanWest"
	startup_task=Startup.begin("Western city")
	var surfaces:=preload("res://world/suryagarh/settlements/civil_lines.gd").new()
	b.plaster=surfaces.surface("clay_plaster",Color(.76,.69,.56),false);surfaces.free()
	b.wood=b.material(Color(.26,.16,.09));b.stone=b.material(Color(.49,.43,.34));b.tile=b.material(Color(.43,.24,.15));b.ochre=b.material(Color(.67,.48,.29))
	call_deferred("build_city")

func site(label:String,point:Vector2,map_label:String="") -> Node3D:
	var node:=Node3D.new();node.name=label;node.position=Vector3(point.x,8,point.y);add_child(node)
	if not map_label.is_empty():node.set_meta("parking_label",map_label)
	return node

func build_city() -> void:
	for row in 2:
		for index in 6:
			var home:=site("CityHome%d"%(row*6+index),Vector2(-280-index*12,-350-row*32))
			home.add_to_group("city_through_house");home.set_meta("district","city_residential");homes.append(home)
			house(home,index%2==0)
			b.merge_visuals(home)
			await Startup.checkpoint(self,"Preparing connected city homes…")
	for row in 2:
		for pair in 3:
			var at:=Vector2(-286-pair*24,-349-row*32)
			var connector:=site("SharedHousePassage%d"%(row*3+pair),at)
			b.piece(connector,"PassageFloor",Vector3(0,.12,0),Vector3(2,.24,2.4),b.stone)
			b.piece(connector,"PassageCanopy",Vector3(0,2.8,0),Vector3(2.2,.16,2.6),b.tile)
	market()
	await Startup.checkpoint(self,"Preparing city market…")
	hospital()
	await Startup.checkpoint(self,"Preparing civilian hospital…")
	campus()
	for label in Layout.ROUTES:
		if label.begins_with("city_") or label=="merchant_city_drive":lane(label,Layout.ROUTES[label],5.0 if label.contains("street") or label.contains("road") else 3.2)
	# Connect the rural approach to the city without building over the farm buffer.
	var approach:Array[Vector2]=[]
	for z in range(180,-321,-20):approach.append(Vector2(layout.road_x(z),z))
	approach.append(Vector2(-250,-310));lane("VillageCityApproach",approach,6.0)
	for pair in [[-350,-338,-394],[-250,-310,-400]]:lane("CityCrossConnection",[Vector2(pair[0],pair[1]),Vector2(pair[0],pair[2])],4.0)
	community=get_parent().get_node_or_null("StoryCommunity")
	get_parent().get_node("Player/UI/WorldMap").refresh_sites()
	Startup.finish(startup_task)
	print("WESTERN CITY READY | 12 through houses, 6 paired passages, market, civilian hospital, college/café")

func door(parent:Node3D,label:String,at:Vector3,yaw:float=0.0,width:float=2.0) -> Node3D:
	var jamb:=Node3D.new();jamb.position=at;jamb.rotation.y=yaw;parent.add_child(jamb)
	var entrance:=Door.new();entrance.name=label;entrance.width=width;entrance.height=2.5
	entrance.night_lock=false;entrance.auto_open_at_dawn=false;entrance.auto_close_delay=12;entrance.outside_latch_access=true
	entrance.label_name=label.capitalize();entrance.position=Vector3(-width*.5,.24,0);entrance.build(b.wood);jamb.add_child(entrance)
	return entrance

func house(home:Node3D,left_connection:bool) -> void:
	b.piece(home,"Floor",Vector3(0,.12,0),Vector3(10,.24,14),b.stone)
	for z in [-7.0,7.0]:
		for side in [-1.0,1.0]:b.piece(home,"DoorWall",Vector3(side*3,1.7,z),Vector3(4,2.92,.24),b.plaster)
		b.piece(home,"DoorHeader",Vector3(0,2.95,z),Vector3(2, .42,.24),b.plaster)
		var entrance:=door(home,"RearEscapeDoor" if z<0 else "FrontDoor",Vector3(0,0,z),PI if z<0 else 0)
		entrance.set_meta("exit_road",("city_rear_lane" if home.position.z>-370 else "city_back_street") if z<0 else ("city_front_street" if home.position.z>-370 else "city_courtyard_lane"))
	for side in [-1.0,1.0]:
		if (side<0)==left_connection:
			b.piece(home,"SideDoorNorthWall",Vector3(side*5,1.7,-3.5),Vector3(.24,2.92,7),b.plaster)
			b.piece(home,"SideDoorSouthWall",Vector3(side*5,1.7,4.5),Vector3(.24,2.92,5),b.plaster)
			b.piece(home,"SideDoorHeader",Vector3(side*5,2.95,1),Vector3(.24,.42,2),b.plaster)
			door(home,"NeighbourDoor",Vector3(side*5,0,1),side*PI*.5)
		else:
			b.piece(home,"WindowSill",Vector3(side*5,.72,0),Vector3(.24,.96,14),b.plaster)
			b.piece(home,"WindowLintel",Vector3(side*5,2.65,0),Vector3(.24,1.02,14),b.plaster)
			for z in [-5.0,0.0,5.0]:b.piece(home,"WindowPier",Vector3(side*5,1.67,z),Vector3(.24,1,3),b.plaster)
		b.piece(home,"RoofSlope",Vector3(side*2.5,3.38,0),Vector3(5.4,.18,14.7),b.tile).rotation.z=-side*.17
	for side in [-1.0,1.0]:
		b.piece(home,"RoomPartition",Vector3(side*3.1,1.55,0),Vector3(3.8,2.62,.16),b.plaster)
		b.piece(home,"LowCot",Vector3(side*3,.52,-4.7),Vector3(1.6,.25,2.3),b.wood)
		b.piece(home,"CotLeg",Vector3(side*3,.26,-4.7),Vector3(1.2,.5,1.8),b.wood)
		b.piece(home,"HouseholdChest",Vector3(side*3,.55,4.6),Vector3(1,.62,.62),b.wood)
	for z in [-9.5,9.5]:b.piece(home,"DoorApproach",Vector3(0,.10,z),Vector3(2.4,.20,5),b.stone)

func market() -> void:
	var district:=site("CityTradingMarket",Vector2(-340,-310),"City market · Grain, cloth and books")
	for i in 7:
		var stall:=Node3D.new();stall.position=Vector3(-36+i*12,0,-8);district.add_child(stall)
		b.piece(stall,"Counter",Vector3(0,.94,0),Vector3(7,.14,1),b.wood)
		for x in [-3.0,3.0]:b.piece(stall,"Post",Vector3(x,1.65,-1.5),Vector3(.16,3.3,.16),b.wood)
		b.piece(stall,"Canopy",Vector3(0,3.1,-1.5),Vector3(8,.14,5),b.tile,false)
		var supply:Node3D=load("res://objects/household/sets/market_supply.tscn").instantiate();supply.position=Vector3(0,.24,-2);stall.add_child(supply)
	b.merge_visuals(district)

func hospital() -> void:
	var ward:=site("CivilianHospital",Vector2(-205,-388),"Civilian hospital · Treatment")
	shell(ward,Vector2(18,14))
	for x in [-5.0,5.0]:
		for z in [-3.0,1.0]:
			b.piece(ward,"WardBed",Vector3(x,.57,z),Vector3(2.6,.35,1.2),b.wood)
			b.piece(ward,"WardMattress",Vector3(x,.78,z),Vector3(2.5,.12,1.1),b.plaster,false)
	b.piece(ward,"DressingTable",Vector3(-4,.96,4.6),Vector3(2,.12,1),b.wood)
	var actor:=preload("res://characters/npcs/households/household_npc_actor.gd").new()
	actor.name="CivilianAttendant";actor.movement_enabled=false;actor.add_child(preload("res://characters/human_scene.gd").instantiate("res://characters/npcs/households/staff_farmer.glb"));actor.position=Vector3(3,.24,4);ward.add_child(actor)
	actor.set_meta("world_role","civilian_hospital_attendant")
	var operations:=preload("res://world/suryagarh/settlements/civil_hospital_operations.gd").new();operations.name="Operations";ward.add_child(operations);operations.configure(ward)
	operations.station("hospital",ward,Vector3(1.5,.24,4),actor)
	ward.get_node("HospitalService").set_meta("parking_label","Civilian hospital reception")
	ward.add_to_group("civilian_hospital")
	for z in [10,13]:b.piece(ward,"AmbulanceApproach",Vector3(0,.1,z),Vector3(5,.2,6),b.stone)
	b.merge_visuals(ward)

func shell(node:Node3D,size:Vector2) -> void:
	b.piece(node,"Floor",Vector3(0,.12,0),Vector3(size.x,.24,size.y),b.stone)
	b.piece(node,"BackWall",Vector3(0,1.7,-size.y*.5),Vector3(size.x,2.92,.24),b.plaster)
	for side in [-1.0,1.0]:
		b.piece(node,"SideWall",Vector3(side*size.x*.5,1.7,0),Vector3(.24,2.92,size.y),b.plaster)
		b.piece(node,"FrontWall",Vector3(side*(size.x*.25+.6),1.7,size.y*.5),Vector3(size.x*.5-1.2,2.92,.24),b.plaster)
		b.piece(node,"Roof",Vector3(side*size.x*.25,3.6,0),Vector3(size.x*.5+.6,.18,size.y+1),b.tile).rotation.z=-side*.13
	b.piece(node,"EntranceHeader",Vector3(0,2.98,size.y*.5),Vector3(2.4,.5,.24),b.plaster)
	door(node,"EntranceDoor",Vector3(0,0,size.y*.5),0,2.4)

func campus() -> void:
	var lecture:=site("CollegeLectureHall",Vector2(-418,-520),"College · Lecture hall")
	shell(lecture,Vector2(24,16))
	for row in 4:
		for side in [-1.0,1.0]:b.piece(lecture,"StudentBench",Vector3(side*5,.65,-5+row*3),Vector3(6,.18,.75),b.wood)
	b.piece(lecture,"Lectern",Vector3(0,1.1,-6),Vector3(1.1,.9,.65),b.wood)
	b.merge_visuals(lecture)
	lane("CollegeArcade",[Vector2(-418,-508),Vector2(-375,-508)],4)
	lane("CampusCafeWalk",[Vector2(-358,-495),Vector2(-375,-495)],3)
	var gateway:=site("CollegeGateway",Vector2(-375,-450))
	for x in [-4.0,4.0]:b.piece(gateway,"EntrancePier",Vector3(x,1.5,0),Vector3(.75,3,.75),b.plaster)
	var sign:=Label3D.new();sign.text="COLLEGE · READING & LECTURES";sign.position=Vector3(0,3.3,0);sign.font_size=48;sign.pixel_size=.007;gateway.add_child(sign)

func lane(label:String,points:Array,width:float) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size()-1:
		var a:Vector2=points[i];var end:Vector2=points[i+1];var span:=a.distance_to(end);var steps:=maxi(1,ceili(span/2))
		var side:=Vector2(-(end-a).y,(end-a).x).normalized()*width*.5
		for step in steps:
			var p:=a.lerp(end,float(step)/steps);var q:=a.lerp(end,float(step+1)/steps)
			var vertices:Array[Vector2]=[p-side,p+side,q-side,q+side]
			for index in [0,2,1,1,2,3]:
				var at:=vertices[index];st.set_normal(Vector3.UP);st.set_uv(at*.2);st.add_vertex(Vector3(at.x,layout.height(at.x,at.y)+.025,at.y))
	var visual:=MeshInstance3D.new();visual.name=label;visual.mesh=st.commit();visual.material_override=b.stone;visual.visibility_range_end=750;visual.visibility_range_end_margin=60;add_child(visual)

func _process(delta:float) -> void:
	if classified:return
	setup_age+=delta
	if setup_age<1:return
	setup_age=0
	if not is_instance_valid(community):community=get_parent().get_node_or_null("StoryCommunity")
	if community==null or community.residents.size()<16:return
	var count:=0
	for actor in community.residents:
		var venue:String=str(actor.get_parent().name)
		if venue not in ["CollegeReadingRoom","RefreshmentCourtyard"]:continue
		actor.set_meta("district","college_neighbourhood")
		var role:String="student" if count%8<6 else ("lecturer" if count%8==6 else "printer")
		actor.set_meta("world_role",role)
		if venue=="RefreshmentCourtyard" and count%8 in [2,5]:actor.set_meta("political_role","educated_rebel")
		count+=1
	if count==16:
		for talk in community.courtyard.get_children():
			if talk.get_script()==preload("res://story/community_conversation.gd"):
				talk.lines.assign(["Student: The lecture notes are ready. Sit with us; the café is full today.","Printer: Among the students we can compare news without drawing every guard's attention.","Reader: Some of us oppose the Company's rule. Speak quietly; a careless name puts a household at risk.","Patron: Anyone asking about Dev should listen here and at the college reading room."])
	classified=count==16
	if classified:set_process(false)

func _exit_tree() -> void:b.free()
