extends Node3D
## Original modular architecture for fictional 1857 Suryagarh. Shared materials and merged visible geometry.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const Gate = preload("res://world/suryagarh/settlements/compound_gate.gd")
const Pickup = preload("res://world/suryagarh/settlements/weapon_pickup.gd")
const SupplyChest = preload("res://interaction/treasure_chest.gd")
var layout := Layout.new()
var plaster: Material
var ochre: Material
var brick: Material
var wood: Material
var tile: Material
var stone: Material
var iron: Material

func material(color: Color, masonry := false) -> Material:
	var m := ShaderMaterial.new()
	m.shader = preload("res://world/suryagarh/settlements/period_surface.gdshader")
	m.set_shader_parameter("tint",color)
	m.set_shader_parameter("courses",1.0 if masonry else 0.0)
	return m

func _ready() -> void:
	plaster = material(Color(.76,.70,.56))
	ochre = material(Color(.55,.40,.24))
	brick = material(Color(.44,.24,.16),true)
	wood = material(Color(.23,.13,.07))
	tile = material(Color(.43,.19,.105),true)
	stone = material(Color(.42,.40,.33),true)
	iron = material(Color(.13,.14,.13))
	preload("res://world/suryagarh/settlements/bhairavpur_village.gd").new().build(self)
	add_civic("TownHall",Layout.PLOTS["TownHall"].center,false)
	add_civic("DistrictPolice",Layout.PLOTS["DistrictPolice"].center,true)
	var compound_center: Vector2 = Layout.PLOTS["CompanyCompound"].center
	make_building("DistrictJail",compound_center+Vector2(2,13),Vector2(21,18),true,true,true)
	make_building("CompanyArmoury",compound_center+Vector2(31,8),Vector2(17,13),true,true)
	compound()
	place_new_props()
	place_period_props()
	landing()
	var residence: Node3D = load("res://world/suryagarh/settlements/government_house.gd").new()
	add_child(residence)

func place_new_props() -> void:
	# One artillery display in the open west court, clear of the jail and stores.
	var court: Vector2 = Layout.PLOTS["CompanyCompound"].center
	var cannon := StaticBody3D.new()
	cannon.name = "CompanyCourtyardCannon"
	cannon.position = Vector3(court.x-29.0,Layout.PLOTS["CompanyCompound"].grade+.04,court.y+13.0)
	add_child(cannon)
	cannon.add_child(preload("res://environment/props/new_assets/wooden_gun_carriage_v1.glb").instantiate())
	var cannon_shape := BoxShape3D.new()
	cannon_shape.size = Vector3(4.5,1.45,4.7)
	var cannon_collision := CollisionShape3D.new()
	cannon_collision.shape = cannon_shape
	cannon_collision.position.y = .73
	cannon.add_child(cannon_collision)
	# Set the road marker beside the main northbound track, off its walking strip.
	var sign_z := 180.0
	var sign_x := layout.road_x(sign_z)-7.0
	var sign := StaticBody3D.new()
	sign.name = "SuryagarhRoadSign"
	sign.position = Vector3(sign_x,layout.height(sign_x,sign_z),sign_z)
	sign.rotation.y = PI
	add_child(sign)
	sign.add_child(preload("res://environment/props/new_assets/wooden_signboard.glb").instantiate())
	var sign_shape := BoxShape3D.new()
	sign_shape.size = Vector3(2.15,2.42,.3)
	var sign_collision := CollisionShape3D.new()
	sign_collision.shape = sign_shape
	sign_collision.position.y = 1.21
	sign.add_child(sign_collision)

func place_period_props() -> void:
	# Shared wrappers retain original materials, normalized bases and matching collision.
	var court: Vector2 = Layout.PLOTS["CompanyCompound"].center
	var grade: float = Layout.PLOTS["CompanyCompound"].grade+.08
	var placements := [
		["crate","CompanyStoresWoodenCrate",Vector3(court.x+20.0,grade,court.y+16.5)],
		["bucket","BhairavpurWoodenBucket",Vector3(-346,layout.height(-346,219),219)],
		["brass_pot","BhairavpurBrassPot",Vector3(-345.25,layout.height(-345.25,218.9),218.9)],
		["basket","BhairavpurWickerBasket",Vector3(-324,layout.height(-324,219),219)],
		["stool","BhairavpurWoodenStool",Vector3(-302,layout.height(-302,219),219)],
		["bench","CompanyGuardBench",Vector3(court.x-15.0,grade,court.y-43.5)],
		["barrel","CompanyStoresWineBarrel",Vector3(court.x+22.2,grade,court.y+16.5)]
	]
	for placement in placements:
		var prop: StaticBody3D = load("res://objects/household/storage/"+str(placement[0])+".tscn").instantiate()
		prop.name = placement[1]
		prop.position = placement[2]
		add_child(prop)

func piece(parent: Node3D, label: String, center: Vector3, size: Vector3, mat: Material, solid := true) -> Node3D:
	var node := Node3D.new()
	node.name = label
	parent.add_child(node)
	node.position = center
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	node.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		node.add_child(body)
	return node

func column(parent: Node3D, center: Vector3, height: float) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = .22
	mesh.bottom_radius = .29
	mesh.height = height
	mesh.radial_segments = 12
	node.mesh = mesh
	node.position = center
	node.material_override = plaster
	parent.add_child(node)
	piece(parent,"ColumnBase",center-Vector3.UP*(height*.5-.12),Vector3(.75,.24,.75),stone)
	piece(parent,"ColumnCapital",center+Vector3.UP*(height*.5-.1),Vector3(.7,.2,.7),plaster,false)
	var body := StaticBody3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = .29
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.position = center
	body.add_child(collision)
	parent.add_child(body)

func make_building(label: String, p: Vector2, extent: Vector2, civic: bool, north := false, jail := false, defer_visual_merge := false) -> Node3D:
	var b := Node3D.new()
	b.name = label
	add_child(b)
	b.position = Vector3(p.x,layout.height(p.x,p.y),p.y)
	if north: b.rotation.y = PI
	var w: float = extent.x
	var d: float = extent.y
	var h: float = 4.6 if civic else 2.8
	var m: Material = plaster if civic else ochre
	piece(b,"Plinth",Vector3(0,.12,0),Vector3(w+1,.24,d+1),stone)
	# Actual doorway and window openings; there is no collision filling the room.
	for side in [-1.0,1.0]:
		piece(b,"DoorPier",Vector3(side*(w*.25+.65),h*.5+.24,d*.5),Vector3(w*.5-1.3,h,.38),m)
	piece(b,"DoorLintel",Vector3(0,(h+2.35)*.5+.24,d*.5),Vector3(2.6,h-2.35,.38),m)
	piece(b,"BackWall",Vector3(0,h*.5+.24,-d*.5),Vector3(w,h,.38),m)
	for side in [-1.0,1.0]:
		piece(b,"WindowSillWall",Vector3(side*w*.5,.79,0),Vector3(.38,1.1,d),m)
		piece(b,"WindowHeadWall",Vector3(side*w*.5,(h+2.25)*.5+.24,0),Vector3(.38,h-2.25,d),m)
		for end in [-1.0,1.0]:
			piece(b,"WindowPier",Vector3(side*w*.5,1.915,end*(d*.25+.55)),Vector3(.38,1.15,d*.5-1.1),m)
		for edge in [-1.0,1.0]:
			piece(b,"Shutter",Vector3(side*(w*.5+.05),1.915,edge*1.0),Vector3(.14,1.15,.34),wood,false)
		piece(b,"RoofSlope",Vector3(side*w*.25,h+.65,0),Vector3(w*.55,.15,d+1.6),tile).rotation.z = side*-.25
	piece(b,"RoofRidge",Vector3(0,h+1.32,0),Vector3(.25,.26,d+1.7),tile,false)
	for step in 3:
		piece(b,"ThresholdStep",Vector3(0,.04+step*.07,d*.5+.9-step*.24),Vector3(3,.08,.55),stone)
	if civic:
		piece(b,"Veranda",Vector3(0,.12,d*.5+1.5),Vector3(w+1,.24,3.4),stone)
		piece(b,"PorticoEntablature",Vector3(0,h+.13,d*.5+2.5),Vector3(w+1,.4,1.0),plaster)
		piece(b,"VerandaRoof",Vector3(0,h+.42,d*.5+1.2),Vector3(w+1,.2,4.3),tile)
		for i in 7:
			column(b,Vector3(-w*.46+i*w*.92/6,h*.5+.24,d*.5+2.5),h)
		piece(b,"Desk",Vector3(0,1.02,-d*.2),Vector3(3,.16,1.0),wood)
		for side in [-1.0,1.0]:
			piece(b,"DeskLeg",Vector3(side*1.2,.55,-d*.2),Vector3(.15,.95,.7),wood)
	else:
		piece(b,"VerandaShade",Vector3(0,h-.1,d*.5+1.1),Vector3(w+.8,.13,2.6),wood,false)
		for side in [-1.0,1.0]:
			piece(b,"ShadePost",Vector3(side*(w*.5-.3),h*.5,d*.5+2),Vector3(.13,h,.13),wood)
		piece(b,"SleepingPlatform",Vector3(-2,.52,-1.4),Vector3(1.7,.16,2.5),wood)
	if jail:
		for x in [-7.0,0.0,7.0]:
			piece(b,"CellPartition",Vector3(x,1.75,-4.7),Vector3(.35,3,7),stone)
		for i in 49:
			var x: float = -10+i*.416
			if absf(x-3.5)<.7: continue
			piece(b,"CellBar",Vector3(x,1.8,-1.0),Vector3(.045,3.1,.045),iron,false)
		piece(b,"CellBarsCollision",Vector3(-4.05,1.8,-1),Vector3(12,3.1,.12),iron)
		piece(b,"CellBarsCollision",Vector3(7.1,1.8,-1),Vector3(5.8,3.1,.12),iron)
	if "Armoury" in label:
		# Timber shelf against the rear masonry, reached through the real doorway.
		# Keep its front clear of the room's desk and the player capsule.
		var rack_z: float = -d*.5+1.15
		piece(b,"WeaponRackShelf",Vector3(0,1.02,rack_z),Vector3(4.8,.16,1.0),wood)
		piece(b,"WeaponRackUpperShelf",Vector3(0,1.70,rack_z),Vector3(4.8,.13,1.0),wood)
		piece(b,"WeaponRackBack",Vector3(0,1.05,rack_z-.46),Vector3(4.8,1.62,.08),wood)
		for side in [-1.0,1.0]:
			piece(b,"WeaponRackPost",Vector3(side*2.34,1.03,rack_z),Vector3(.12,1.58,1.0),wood)
		var rack_weapons := [
			["enfield","res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb"],
			["talwar","res://environment/weapons/Talwar/weapon_talwar_01.glb"],
			["double_gun","res://environment/weapons/double_percussion_gun/double_percussion_gun.glb"],
			["bow","res://environment/weapons/period_bow/period_bow.glb"],
			["pistol","res://environment/weapons/adams_1851/adams_1851.glb"],
		]
		for i in rack_weapons.size():
			var pickup := Pickup.new()
			pickup.weapon_id = rack_weapons[i][0]
			var upper: bool = i in [1,3,4]
			var shelf_top: float = 1.765 if upper else 1.10
			var slot_x: float = [-1.12,.45,1.12,-1.3,1.65][i]
			pickup.name = "StoreWeapon_"+pickup.weapon_id
			pickup.store_id = "company_armoury/"+pickup.weapon_id
			pickup.position = Vector3(slot_x,shelf_top+.15,rack_z+.30)
			b.add_child(pickup)
			var source: String = rack_weapons[i][1]
			var model: Node3D = load(source).instantiate()
			pickup.add_child(model)
			model.basis = Basis(Vector3.RIGHT,PI/2)
			if pickup.weapon_id == "bow": model.basis = Basis(Vector3.UP,PI/2)*model.basis
			model.scale = Vector3.ONE * stored_weapon_scale(pickup.weapon_id)
			for animation in model.find_children("*","AnimationPlayer",true,false): animation.stop()
			var bounds := weapon_bounds(model,pickup)
			model.position += Vector3(-bounds.get_center().x,-.135-bounds.position.y,-.30-bounds.get_center().z)
			pickup.set_meta("shelf_top",shelf_top)
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(maxf(.4,bounds.size.x),.25,.5)
			collision.shape = shape
			pickup.add_child(collision)
	if label == "CompanyArmoury":
		preload("res://world/suryagarh/settlements/ammunition_display.gd").furnish(self, b, Vector3(5, 0, -3), "company_armoury/ammunition")
		preload("res://world/suryagarh/settlements/medical_supply.gd").furnish(self, b, Vector3(3.3,0,-3), "company_armoury/bandage")
	var sign := Label3D.new()
	sign.text = {"SuryagarhTownHall":"SURYAGARH · TOWN HALL","PoliceThana":"POLICE THANA","DistrictJail":"DISTRICT JAIL","CompanyArmoury":"COMPANY STORES"}.get(label,"")
	sign.font = preload("res://assets/ui/fonts/CormorantGaramond.ttf")
	sign.font_size = 48
	sign.pixel_size = .007
	sign.modulate = Color(.20,.13,.07)
	sign.position = Vector3(0,3.5,d*.5+.205)
	b.add_child(sign)
	if not defer_visual_merge: merge_visuals(b)
	return b

func stored_weapon_scale(weapon_id: String) -> float:
	# Displayed and equipped instances must represent the same physical object.
	var equipment = preload("res://player/arjun_equipment.gd")
	return {"enfield":equipment.ENFIELD_SCALE,"double_gun":equipment.DOUBLE_GUN_SCALE,"pistol":equipment.PISTOL_SCALE}.get(weapon_id,1.0)

func weapon_bounds(model: Node3D, relative_to: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh == null or not mesh.visible or mesh.name.begins_with("tlm_smoke_preview"): continue
		var box: AABB = (relative_to.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds

func compound() -> void:
	var c := Node3D.new()
	c.name = "ColonialCompound"
	add_child(c)
	var surveyed: Vector2 = Layout.PLOTS["CompanyCompound"].center
	c.position = Vector3(surveyed.x,Layout.PLOTS["CompanyCompound"].grade,surveyed.y)
	piece(c,"Courtyard",Vector3(0,.04,0),Vector3(102,.08,94),ochre)
	for side in [-1.0,1.0]:
		var wall := piece(c,"ClimbableWall",Vector3(side*52,2.4,0),Vector3(1.4,4.8,96),brick)
		var body: StaticBody3D = wall.get_child(1)
		if side<0:
			body.add_to_group("climbable_walls")
			body.set_meta("top_y",16.8)
			body.set_meta("climb_center_z",300.0)
			body.set_meta("climb_hold_base_y",c.position.y+.42)
			body.set_meta("climb_hold_center_z",c.position.z)
			body.set_meta("climb_hold_spacing",.40)
			body.set_meta("climb_hold_rows",11)
		piece(c,"WallWalk",Vector3(side*50.3,4.62,0),Vector3(3.5,.36,96),stone)
		piece(c,"Coping",Vector3(side*52,4.8,0),Vector3(1.55,.14,96),stone,false)
		# Worn projecting masonry communicates the climb route.
		if side<0:
			for row in 11:
				for col in 4:
					piece(c,"ClimbingStone",Vector3(side*52.78,.42+row*.40,-.72+col*.48+(row%2)*.08),Vector3(.2,.14,.42),stone,false)
	piece(c,"SouthWall",Vector3(0,2.4,48),Vector3(104,4.8,1.4),brick)
	for side in [-1.0,1.0]:
		piece(c,"GateWall",Vector3(side*28,2.4,-48),Vector3(48,4.8,1.4),brick)
		piece(c,"GatePier",Vector3(side*4.25,2.7,-48),Vector3(1.3,5.4,1.8),stone)
	piece(c,"GateLintel",Vector3(0,5.15,-48),Vector3(8,.5,1.6),stone)
	var gate := Gate.new()
	gate.name = "BarredGate"
	gate.position = Vector3(0,1.9,-48)
	c.add_child(gate)
	var gate_visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(7.0,3.8,.3)
	gate_visual.mesh = box
	gate_visual.material_override = wood
	gate.add_child(gate_visual)
	var shape := BoxShape3D.new()
	shape.size = box.size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	gate.add_child(collision)
	# Walkway staircase gives the player a physical descent into the courtyard.
	for i in 24:
		piece(c,"WallWalkStair",Vector3(-47.2,.1+i*.1,-5+i*.38),Vector3(2,.2+i*.2,.4),stone)
	# A supported pause/turn at the top also accommodates the horse's length.
	piece(c,"WallWalkStairLanding",Vector3(-48.2,4.65,5.1),Vector3(4.4,.3,3.0),stone)
	var flag: Node3D = preload("res://assets/props/flags/eic/prop_eic_checkpoint_flag_01.glb").instantiate()
	flag.position = Vector3(8,.1,-41)
	c.add_child(flag)
	# Behind the west climb route, clear of the stair and court roadway.
	var chest := SupplyChest.new()
	chest.name = "SecludedSupplyChest"
	chest.position = Vector3(-42.5,.10,9.0)
	c.add_child(chest)
	merge_visuals(c)

func landing() -> void:
	var dock := Node3D.new()
	dock.name = "BhairavpurBoatLanding"
	add_child(dock)
	var z := 235.0
	var end: float = layout.river_x(z)-layout.river_width(z)+1.0
	var start: float = end-43
	var bank: float = layout.height(start,z)
	var points: Array[Vector3] = []
	for i in 64:
		var t: float = float(i)/63
		var x: float = lerpf(start,end,t)
		var y: float = maxf(.45,lerpf(bank+.1,.45,clampf(t/.8,0,1)))
		for dx in [-.35,0.0,.35]:
			for dz in [-1.5,0.0,1.5]:
				y = maxf(y,layout.height(x+dx,z+dz)+.08)
		points.append(Vector3(x,y,z))
	# Raise the deck envelope to clear the bank with a walkable maximum grade.
	var max_delta: float = (end-start)/63.0*.25
	for i in range(1,64): points[i].y = maxf(points[i].y,points[i-1].y-max_delta)
	for i in range(62,-1,-1): points[i].y = maxf(points[i].y,points[i+1].y-max_delta)
	for i in 63:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i+1]
		var angle: float = atan2(b.y-a.y,b.x-a.x)
		var normal := Vector3(-sin(angle),cos(angle),0)
		var plank := piece(dock,"JettyPlank%02d"%i,(a+b)*.5-normal*.09,Vector3(a.distance_to(b)+.025,.18,3),wood)
		# Small visible board joints; the matching collision overlaps underneath.
		var plank_mesh: BoxMesh = plank.get_child(0).mesh
		plank_mesh.size.x = a.distance_to(b)-.012
		plank.rotation.z = angle
		plank.set_meta("deck_a",a)
		plank.set_meta("deck_b",b)
	for i in range(0,64,7):
		var point: Vector3 = points[i]
		piece(dock,"JettyBeam%02d"%i,point-Vector3.UP*.27,Vector3(.22,.18,3.2),wood,false)
		for side in [-1.0,1.0]:
			var ground: float = layout.height(point.x,z+side*1.25)
			var bottom: float = ground-.35
			var top: float = point.y-.18
			var pile := piece(dock,"JettyPile%02d_%d"%[i,int(side)],Vector3(point.x,(bottom+top)*.5,z+side*1.25),Vector3(.18,maxf(.18,top-bottom),.18),wood)
			pile.set_meta("ground_y",ground)
	merge_visuals(dock)

func stair_guard(parent: Node3D, x: float, base_y: float, run: float, rise: float, up_toward_back: bool, rail_width: float) -> void:
	var angle := atan2(rise,run)*(1.0 if up_toward_back else -1.0)
	var length := sqrt(run*run+rise*rise)
	var count := int(ceil(run/.5))
	for side in [-1.0,1.0]:
		var edge_x: float = x+side*rail_width*.5
		var guard := StaticBody3D.new()
		guard.name = "StairGuard"
		parent.add_child(guard)
		guard.add_to_group("stair_guards")
		var rail_center := Vector3(edge_x,base_y+rise*.5+1,0)
		var rail := piece(parent,"StairHandrail",rail_center,Vector3(.1,.1,length),wood,false)
		rail.rotation.x = angle
		var rail_shape := CollisionShape3D.new()
		var rail_box := BoxShape3D.new()
		rail_box.size = Vector3(.1,.1,length)
		rail_shape.shape = rail_box
		rail_shape.position = rail_center
		rail_shape.rotation.x = angle
		guard.add_child(rail_shape)
		var stringer := piece(parent,"StairStringer",Vector3(edge_x-side*.10,base_y+rise*.5-.13,0),Vector3(.18,.26,length),wood,false)
		stringer.rotation.x = angle
		for i in count+1:
			var t: float = float(i)/count
			var z: float = run*.5-run*t if up_toward_back else -run*.5+run*t
			var floor_height: float = base_y+rise*t
			var thickness: float = .16 if i == 0 or i == count else .065
			var center := Vector3(edge_x,floor_height+.5,z)
			var size := Vector3(thickness,1.0,thickness)
			var post := piece(parent,"StairSupport",center,size,wood,false)
			post.set_meta("floor_y",floor_height)
			post.set_meta("rail_y",floor_height+1)
			var collision := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = size
			collision.shape = box
			collision.position = center
			guard.add_child(collision)

func merge_visuals(parent: Node3D) -> void:
	var groups: Dictionary = {}
	for node in parent.find_children("*","MeshInstance3D",true,false):
		# Keep interactable/vehicle model geometry separate; it can disappear or animate.
		var p: Node = node.get_parent()
		var dynamic := false
		while p!=parent:
			if p is Interactable: dynamic = true
			p=p.get_parent()
		if dynamic or node.material_override==null or not node.visible: continue
		var m: Material = node.material_override
		if not groups.has(m):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[m]=st
		var relative: Transform3D = parent.global_transform.affine_inverse()*node.global_transform
		groups[m].append_from(node.mesh,0,relative)
		node.queue_free()
	for m in groups:
		var mesh := MeshInstance3D.new()
		mesh.mesh = groups[m].commit()
		mesh.material_override=m
		mesh.visibility_range_end=750
		mesh.visibility_range_end_margin=60
		parent.add_child(mesh)

func add_civic(label: String,p: Vector2,police: bool) -> void:
	var building := Node3D.new()
	building.set_script(load("res://world/suryagarh/settlements/civic_building.gd"))
	building.name = label
	building.set("police",police)
	building.position = Vector3(p.x,0,p.y)
	add_child(building)
	var notice := preload("res://interaction/wall_notice.gd").new()
	notice.name = "PostedDistrictNotice"
	notice.headline = "ROAD WATCH" if police else "MARKET NEWS"
	notice.message = "Report unsafe roads and disturbances to the district office." if police else "Grain sellers and travellers: keep the entrance and water steps clear. Market enquiries are received here."
	notice.position = Vector3(7,1.50,18.27 if police else 14.27)
	building.add_child(notice)
