extends "res://world/suryagarh/settlements/settlement_builder.gd"
## Reuses the settlement masonry kit. All interiors are real world-space geometry.
@export var police := false
var floor_y := 5.4
var width := 40.0
var depth := 28.0
var stair_x := -16.5
var stair_front := 9.0
var stair_back := -9.0

func _ready() -> void:
	plaster = surface("clay_plaster",Color(.95,.91,.80),.45)
	ochre = material(Color(.37,.18,.13))
	stone = material(Color(.46,.43,.35),true)
	wood = preload("res://world/suryagarh/settlements/building_realism.gd").wood(Color(.38,.28,.19))
	tile = material(Color(.48,.23,.14),true)
	iron = material(Color(.12,.13,.12))
	if police:
		width = 38
		depth = 36
		stair_x = -15.0
	# Raised foundations are above the highest sampled terrain under the footprint.
	var ground := -1000.0
	for x in range(-int(width*.5)-2,int(width*.5)+3,2):
		for z in range(-int(depth*.5)-2,int(depth*.5)+3,2):
			ground = maxf(ground,layout.height(position.x+x,position.z+z))
	position.y = ground+.45
	plaster = preload("res://world/suryagarh/settlements/building_realism.gd").finish(Color(.79,.75,.63),position.y)
	if police:
		stone = preload("res://world/suryagarh/settlements/police_refinement.gd").masonry(position.y)
		preload("res://world/suryagarh/settlements/police_interior.gd").foundation(self)
	else:
		piece(self,"Foundation",Vector3(0,-1,0),Vector3(width+1,2,depth+1),stone)
	for level in 2:
		var y: float = level*floor_y
		facade(y,depth*.5,true)
		facade(y,-depth*.5,false)
		for side in [-1,1]:
			piece(self,"SideSill",Vector3(side*width*.5,y+.65,0),Vector3(.5,1.3,depth),plaster)
			if police:
				piece(self,"VentLowerBand",Vector3(side*width*.5,y+3.35,0),Vector3(.5,.3,depth),plaster)
				piece(self,"VentUpperBand",Vector3(side*width*.5,y+4.95,0),Vector3(.5,.9,depth),plaster)
				for z in range(-int(depth*.5),int(depth*.5)+1,4):
					piece(self,"HighVentPier",Vector3(side*width*.5,y+4.0,z),Vector3(.5,1.0,1.6),plaster)
			else:
				piece(self,"SideLintel",Vector3(side*width*.5,y+4.3,0),Vector3(.5,2.2,depth),plaster)
			for z in range(-int(depth*.5),int(depth*.5)+1,4):
				piece(self,"SidePier",Vector3(side*width*.5,y+2.3,z),Vector3(.5,2,1.6),plaster)
		# Cornices and deep shaded colonnade.
		piece(self,"Cornice",Vector3(0,y+5.15,depth*.5+1.9),Vector3(width+2,.45,4.4),plaster)
		for i in 8:
			var x := -width*.5+1+i*(width-2)/7
			column(self,Vector3(x,y+2.5,depth*.5+3.1),5)
		if level == 1:
			piece(self,"Balcony",Vector3(0,y-.13,depth*.5+1.6),Vector3(width+1,.26,3.8),stone)
			for side in [-1,1]:
				piece(self,"BalconyRail",Vector3(side*(width*.25+1),y+.65,depth*.5+3.2),Vector3(width*.5-2,1.3,.25),plaster)
	# Upper floor opening is the full stair run; no invisible ceiling blocks the ascent.
	var cut_right := stair_x+2.0
	var cut_left := stair_x-2.0
	piece(self,"UpperMainFloor",Vector3((cut_right+width*.5)*.5,floor_y-.15,0),Vector3(width*.5-cut_right,.3,depth),wood)
	piece(self,"UpperOuterStrip",Vector3((-width*.5+cut_left)*.5,floor_y-.15,0),Vector3(cut_left+width*.5,.3,depth),wood)
	for sign_side in [-1,1]:
		piece(self,"UpperLanding",Vector3(stair_x,floor_y-.15,sign_side*(depth*.25+4.5)),Vector3(4,.3,depth*.5-9),wood)
	for i in 36:
		var height: float = floor_y*(i+1)/36
		piece(self,"StairTread",Vector3(stair_x,height-.075,stair_front-(i+.5)*.5),Vector3(3.5,.15,.51),wood,false)
	# Smooth, matching physics ramp lets the capsule walk the staircase without jumping.
	var ramp := piece(self,"StairRamp",Vector3(stair_x,floor_y*.5-.14,0),Vector3(3.5,.28,sqrt(18*18+floor_y*floor_y)),stone,true)
	ramp.rotation.x = atan2(floor_y,18.0)
	ramp.get_child(0).hide()
	stair_guard(self,stair_x,0,18.0,floor_y,true,3.4)
	piece(self,"GalleryGuard",Vector3(cut_right,floor_y+.55,0),Vector3(.14,1.1,17.5),wood)
	# Low clay-tile pitch sheds monsoon rain behind a plain masonry parapet.
	for side in [-1,1]:
		var slope := piece(self,"RoofPitch",Vector3(side*width*.25,11.2,0),Vector3(width*.5+1,.24,depth+2),tile)
		slope.rotation.z = -side*.04
		piece(self,"Parapet",Vector3(side*width*.5,11.3,0),Vector3(.5,.7,depth+2),plaster)
		piece(self,"EaveTimber",Vector3(side*(width*.5+.25),10.82,0),Vector3(.35,.18,depth+2),wood,false)
	piece(self,"RidgeCap",Vector3(0,11.62,0),Vector3(.32,.18,depth+2),tile,false)
	for end in [-1,1]:
		piece(self,"RoofEndCoping",Vector3(0,11.3,end*depth*.5),Vector3(width,.7,.5),plaster,false)
	# Wide front entrance: outside ground connects directly to the hall floor.
	var start := Vector3(0,-.04,depth*.5+4)
	var approach_length := 24.0 if not police else 18.0
	var end := Vector3(0,layout.height(position.x,position.z+depth*.5+approach_length)-position.y,depth*.5+approach_length)
	piece(self,"EntryPorch",Vector3(0,-.12,depth*.5+1.75),Vector3(width+1,.24,4),stone)
	if police:
		# The 21.75 m porch edge and 22 m ramp start left a 25 cm support gap.
		piece(self,"EntryRampPorchJoin",Vector3(0,-.15,depth*.5+3.88),Vector3(5,.30,.55),stone)
	# Follow the surveyed ground between the porch and road. A single straight
	# slab was buried by the town hall's shallow rise, leaving two visible ends.
	var segments := int(end.z-start.z)
	for i in segments:
		var a := entrance_point(start,end,float(i)/segments)
		var b := entrance_point(start,end,float(i+1)/segments)
		var midpoint := (a+b)*.5
		var ground_y: float = layout.height(position.x,position.z+midpoint.z)-position.y
		var thickness := maxf(.24,midpoint.y-ground_y+.25)
		var approach := piece(self,"EntryRamp",midpoint-Vector3.UP*thickness*.5,Vector3(5,thickness,a.distance_to(b)+.03),stone)
		approach.rotation.x = -atan2(b.y-a.y,b.z-a.z)
	for level in 2:
		for row in 3:
			if police and (level != 1 or row != 2): continue
			piece(self,"MeetingTable",Vector3(3,level*floor_y+.82,-6+row*5),Vector3(8,.18,1.5),wood)
			for side in [-1,1]:
				piece(self,"Bench",Vector3(3,level*floor_y+.45,-6+row*5+side*1.4),Vector3(8,.18,.45),wood)
	# Accessible rear rooms; open door gaps connect the armoury and record office.
	for level in 2:
		piece(self,"RecordsPartition",Vector3(width*.5-6,level*floor_y+2.5,-depth*.5+4),Vector3(.3,5,8),plaster)
		for offset in [-1,1]:
			piece(self,"RecordsDoorPier",Vector3(width*.5-3+offset*2.15,level*floor_y+2.5,-depth*.5+8),Vector3(1.7,5,.3),plaster)
		piece(self,"RecordsLintel",Vector3(width*.5-3,level*floor_y+4,-depth*.5+8),Vector3(2.6,2,.3),plaster)
		var light := OmniLight3D.new()
		light.name = "StationAmbientFill" if police else "HallLight"
		light.position = Vector3(0,level*floor_y+3,0)
		light.light_color = Color(1,.82,.58)
		light.light_energy = .16 if police else .7
		light.omni_range = 15 if police else 24
		add_child(light)
	preload("res://world/suryagarh/settlements/civic_details.gd").furnish(self)
	armoury()
	sidearm_display()
	if police:
		preload("res://world/suryagarh/settlements/police_interior.gd").furnish(self)
		preload("res://world/suryagarh/settlements/ammunition_display.gd").furnish(self, self, Vector3(width * 0.5 - 3, 0, -depth * 0.5 + 7), "district_police/ammunition")
		preload("res://world/suryagarh/settlements/medical_supply.gd").furnish(self, self, Vector3(width*0.5-4.7,0,-depth*0.5+7), "district_police/bandage")
		preload("res://world/suryagarh/settlements/police_refinement.gd").furnish(self)
	preload("res://world/suryagarh/settlements/building_realism.gd").civic(self)
	merge_visuals(self)
	if police:
		var staff := Node3D.new()
		staff.name = "ThanaStaff"
		staff.set_script(preload("res://world/suryagarh/settlements/thana_staff.gd"))
		add_child(staff)

func entrance_point(start: Vector3, end: Vector3, t: float) -> Vector3:
	var point := start.lerp(end,t)
	point.y = maxf(point.y,layout.height(position.x,position.z+point.z)-position.y+.06)
	return point

func facade(y: float,z: float,front: bool) -> void:
	for side in [-1,1]:
		piece(self,"FacadeWing",Vector3(side*(width*.25+1.1),y+.55,z),Vector3(width*.5-2.2,1.1,.5),plaster)
		for i in range(1,int(width*.5),4):
			piece(self,"FacadePier",Vector3(side*(i+2),y+2.25,z),Vector3(1.6,2.3,.5),plaster)
	piece(self,"FacadeLintel",Vector3(0,y+4.15,z),Vector3(width,2.5,.5),plaster)
	if not front: piece(self,"RearCentre",Vector3(0,y+1.6,z),Vector3(4.4,3.2,.5),plaster)

func armoury() -> void:
	var rack_x := width*.5-3
	var rack_z := -depth*.5+3.5
	piece(self,"ArmouryShelf",Vector3(rack_x,1.02,rack_z),Vector3(2.4,.16,5),wood)
	for x in [-1.12,1.12]:
		for z in [-2.35,2.35]:
			piece(self,"ArmouryPost",Vector3(rack_x+x,.56,rack_z+z),Vector3(.16,.96,.16),wood)
	for i in 3:
		var pickup := Pickup.new()
		pickup.weapon_id = "enfield" if i<2 else "talwar"
		pickup.name = "CivicWeapon%d" % i
		# Preserve the existing persistence identity when replacing the furniture.
		pickup.store_id = "%s/%s/%s" % [name,pickup.weapon_id,Vector3(rack_x,1.2,-depth*.5+2+i*1.5)]
		pickup.position = Vector3(rack_x,1.25,-depth*.5+2+i*1.5)
		add_child(pickup)
		var source := "res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb" if i<2 else "res://environment/weapons/Talwar/weapon_talwar_01.glb"
		var model: Node3D = load(source).instantiate()
		pickup.add_child(model)
		model.basis = Basis(Vector3.RIGHT,PI/2)
		model.scale = Vector3.ONE * stored_weapon_scale(pickup.weapon_id)
		for animation in model.find_children("*","AnimationPlayer",true,false): animation.stop()
		var bounds := weapon_bounds(model,pickup)
		model.position += Vector3(-bounds.get_center().x,1.115-pickup.position.y-bounds.position.y,-bounds.get_center().z)
		pickup.set_meta("shelf_top",1.10)
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(maxf(.4,bounds.size.x),.25,maxf(.4,bounds.size.z))
		collider.shape = shape
		pickup.add_child(collider)

func surface(asset: String,tint: Color,scale_value: float) -> Material:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.albedo_texture = load("res://assets/architecture/materials/"+asset+"_Diffuse.jpg")
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/architecture/materials/"+asset+"_nor_gl.jpg")
	mat.normal_scale = .45
	mat.roughness_texture = load("res://assets/architecture/materials/"+asset+"_Rough.jpg")
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE*scale_value
	return mat

func sidearm_display() -> void:
	var supplies = load("res://world/suryagarh/settlements/supply_pickup.gd")
	var entries := [
		["pistol","Adams revolver","res://environment/weapons/adams_1851/adams_1851.glb"],
		["utility_knife","Utility knife","res://environment/weapons/period_utility_knife/period_utility_knife.glb"],
		["paper_cartridges","Paper cartridges · lead bullets","res://environment/props/new_assets/enfield_ammo_packet.glb"]]
	for i in entries.size():
		var pickup := StaticBody3D.new()
		pickup.set_script(supplies)
		pickup.name = "SidearmSupply_"+entries[i][0]
		pickup.set("item_id",entries[i][0])
		pickup.set("display_name",entries[i][1])
		pickup.set("count",6 if i==2 else 1)
		pickup.position = Vector3(4+i*.75,floor_y+1.06,4)
		pickup.set_meta("support_top",floor_y+.91)
		add_child(pickup)
		if entries[i][2] != "":
			var prop: Node3D = load(entries[i][2]).instantiate()
			pickup.add_child(prop)
			prop.scale = Vector3.ONE * stored_weapon_scale(entries[i][0])
			if i < 2:
				prop.rotation.x = PI*.5
			var bounds := weapon_bounds(prop,pickup)
			prop.position += Vector3(-bounds.get_center().x,-.135-bounds.position.y,-bounds.get_center().z)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(.42,.12,.22)
		collision.shape = shape
		pickup.add_child(collision)
