extends Node3D
## Permanent factory owner: architecture, collision, workstations and save ledger.
const Data=preload("res://world/suryagarh/settlements/indigo_factory_data.gd")
const Layout=preload("res://world/suryagarh/landscape_layout.gd")
const Ground=preload("res://world/suryagarh/tree_trunk_collision.gd")
const Startup=preload("res://systems/world_startup.gd")
var layout:=Layout.new()
var builder: Node3D
var geometry: Node3D
var operations: Node
var stations: Dictionary={}
var liquids: Array[MeshInstance3D]=[]
var materials: Dictionary={}
var support_bodies: Array[StaticBody3D]=[]
var configured:=false
var grass_removed:=0
var site_grade:=0.0
var crop_mesh:ArrayMesh
var drying_cakes:MultiMeshInstance3D
var raw_loads:Array[Node3D]=[]

func _ready() -> void:
	name="IndigoFactory"
	set_meta("entity_id","site.indigo_factory")
	set_meta("parking_label","Indigo Processing Factory")
	var task:=Startup.begin("Indigo factory")
	await Startup.wait_for(self,"Terrain collision")
	await build()
	Startup.finish(task)

func height_at(point: Vector2) -> float:
	# Match the existing three-metre terrain triangles, including tile edges.
	return preload("res://world/suryagarh/grass_blades.gd").surface_frame(layout,Vector2.ZERO,point,Layout.STEP).origin.y

func point(local: Vector2) -> Vector3:
	var p:=Data.CENTER+local
	return Vector3(p.x,height_at(p),p.y)

func build() -> void:
	position=Vector3(Data.CENTER.x,0,Data.CENTER.y)
	builder=preload("res://world/suryagarh/settlements/settlement_builder.gd").new()
	# Builder is a utility only: do not add its settlement-spawning script to tree.
	for spec in [["brick",Color(.43,.25,.17),true],["plaster",Color(.72,.65,.49),false],["wood",Color(.26,.16,.08),false],["tile",Color(.40,.20,.12),false],["earth",Color(.42,.35,.24),false],["iron",Color(.13,.15,.14),false],["dye",Color(.10,.17,.32),false]]:
		materials[spec[0]]=builder.material(spec[1],spec[2])
	var earth:=StandardMaterial3D.new();earth.albedo_texture=preload("res://assets/nature/materials/brown_mud_dry_diff_1k.jpg")
	earth.albedo_color=Color(.75,.66,.52);earth.roughness=1.0;materials.earth=earth
	var roofing:=ShaderMaterial.new();roofing.shader=preload("res://world/suryagarh/shaders/market_roof_tile.gdshader");materials.tile=roofing
	var leaf_material:=StandardMaterial3D.new();leaf_material.albedo_color=Color(.20,.35,.12);leaf_material.cull_mode=BaseMaterial3D.CULL_DISABLED;materials.leaves=leaf_material
	geometry=Node3D.new();geometry.name="FactoryArchitecture";add_child(geometry)
	crop_mesh=preload("res://world/suryagarh/settlements/indigo_factory_crop.gd").mesh()
	# Work courts follow the ground; buildings have individual masonry plinths.
	ground_strip([Data.CENTER+Vector2(-30,-22),Data.CENTER+Vector2(-30,21)],5.0,"WestCartCourt")
	ground_strip([Data.CENTER+Vector2(-20,0),Data.CENTER+Vector2(28,0)],8.0,"WorkingCourt")
	ground_strip(Data.ACCESS,5.0,"FarmLaneConnection")
	await Startup.checkpoint(self,"Preparing the indigo work yards…")
	var dry:=building("DryingHouse",Vector2(19,13),Vector2(20,13),4.4,true)
	var store:=building("PackingStore",Vector2(-19,15),Vector2(16,11),3.5,false)
	var office:=building("AccountOffice",Vector2(-21,-15),Vector2(13,10),3.6,false)
	station("accounts",office.to_global(Vector3(0,.95,2.3)),"Read the factory account")
	piece(office,"AccountDesk",Vector3(0,.88,0),Vector3(3,.12,1.3),"wood")
	for x in [-1.25,1.25]:
		for z in [-.45,.45]:piece(office,"DeskLeg",Vector3(x,.42,z),Vector3(.1,.84,.1),"wood")
	piece(office,"OpenAccountBook",Vector3(0,.96,0),Vector3(.56,.04,.4),"plaster",false)
	piece(office,"BookSpine",Vector3(0,.99,0),Vector3(.02,.025,.4),"wood",false)
	station("pack",store.to_global(Vector3(0,.95,2.1)),"Inspect the packed indigo")
	for x in [-6.2,-2.0,2.0,6.2]:
		piece(dry,"RackLeg",Vector3(x,.72,0),Vector3(.09,1.44,.10),"wood")
	for y in [.44,.92,1.4]:
		piece(dry,"DryingShelf",Vector3(0,y,0),Vector3(15,.045,1.6),"wood",false)
	drying_cakes=MultiMeshInstance3D.new();drying_cakes.name="DryingIndigoCakes"
	var cake:=BoxMesh.new();cake.size=Vector3(.24,.10,.32)
	var cake_batch:=MultiMesh.new();cake_batch.transform_format=MultiMesh.TRANSFORM_3D;cake_batch.mesh=cake;cake_batch.instance_count=75
	for i in 75:cake_batch.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(-7.2+(i%25)*.6,.515+(i/25)*.48,0)))
	drying_cakes.multimesh=cake_batch;drying_cakes.material_override=materials.dye;dry.add_child(drying_cakes)
	station("dry",dry.to_global(Vector3(-3,.85,2.4)),"Inspect the drying cakes")
	# Two stepped vat pairs: steeper above, beating vat below; no steam engines.
	var vat_floor:=0.0
	for z in [-21,-16,-11]:
		for x in [0,8,16,24]: vat_floor=maxf(vat_floor,point(Vector2(x,z)).y)
	var vats:=Node3D.new();vats.name="SteppedVats";vats.position=Vector3(12,vat_floor,-14);geometry.add_child(vats)
	for x in [-6.0,6.0]:
		vat(vats,Vector3(x,1.25,-3),Vector2(9,5),"Steeper",Color(.29,.37,.14))
		vat(vats,Vector3(x,0,3),Vector2(9,5),"Beater",Color(.12,.25,.33))
		piece(vats,"GravitySpout",Vector3(x,1.08,0),Vector3(.4,.3,1.0),"wood",false)
		piece(vats,"SteeperStopper",Vector3(x,1.18,-.43),Vector3(.5,.38,.09),"wood")
	ramp(vats,Vector3(-12,0,3),Vector3(-12,1.25,-5),2.2,"VatAccessRamp")
	station("vats",vats.to_global(Vector3(-12,1.0,1.6)),"Ask about steeping and beating")
	var settling:=Node3D.new();settling.name="SettlingAndFilterBay";settling.position=point(Vector2(4,-3))-position;geometry.add_child(settling)
	vat(settling,Vector3.ZERO,Vector2(3.4,2.4),"Settling",Color(.22,.28,.25))
	for x in [-1.1,1.1]:piece(settling,"FilterBearer",Vector3(x,1.2,0),Vector3(.08,.1,2.0),"wood",false)
	piece(settling,"StrainingCloth",Vector3(0,1.25,0),Vector3(2.3,.025,1.8),"plaster",false)
	station("settle",settling.to_global(Vector3(-2.4,.9,0)),"Inspect the settling and cloth filter")
	var press:=Node3D.new();press.name="PressHouse";press.position=point(Vector2(16,1))-position;geometry.add_child(press)
	for x in [-2.4,2.4]:piece(press,"PressFrame",Vector3(x,1.65,0),Vector3(.28,3.3,.28),"wood")
	piece(press,"PressHeadBeam",Vector3(0,3.25,0),Vector3(5.3,.35,.4),"wood")
	piece(press,"PerforatedPressBox",Vector3(0,.88,0),Vector3(1.65,.48,1.3),"wood")
	piece(press,"PressPlate",Vector3(0,1.24,0),Vector3(1.7,.15,1.35),"wood")
	piece(press,"ManualScrew",Vector3(0,2.28,0),Vector3(.18,1.95,.18),"iron")
	station("press",press.to_global(Vector3(-1.3,.9,1.6)),"Inspect the hand press")
	for i in 5:
		var crate:Node3D=preload("res://objects/household/storage/crate.tscn").instantiate()
		crate.name="ExportCrate%d"%i;store.add_child(crate);crate.position=Vector3(-5+i*1.8,.04,-3.4)
	for i in 3:
		var pile:=Node3D.new();pile.name="FreshLeafBundles%d"%i;geometry.add_child(pile)
		pile.set_meta("factory_dynamic_group",true)
		pile.position=point(Vector2(-11+i*2.0,-4))-position
		raw_loads.append(pile)
		piece(pile,"LeafLoad",Vector3(0,.3,0),Vector3(1.4,.45,1),"earth",false)
		var leaves:=MultiMeshInstance3D.new();leaves.name="FreshGreenLeaves"
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=crop_mesh;mm.instance_count=16
		for row in 16:
			var basis:=Basis(Vector3.RIGHT,PI*.5).scaled(Vector3.ONE*.8)
			mm.set_instance_transform(row,Transform3D(basis,Vector3(-.6+(row%8)*.17,.5+(row/8)*.08,-.30)))
		leaves.multimesh=mm
		var green:=StandardMaterial3D.new();green.albedo_color=Color(.20,.35,.12);green.cull_mode=BaseMaterial3D.CULL_DISABLED;leaves.material_override=green
		pile.add_child(leaves)
	station("load",point(Vector2(-12,-1))+Vector3.UP,"Inspect the incoming plant bundles")
	# Two entrances and low perimeter walls leave the central cart lane open.
	for x in [-33.0,33.0]:
		for z in [-18,-6,6,18]:
			var base:=point(Vector2(x,z))-position
			piece(geometry,"EstateBoundary",base+Vector3.UP*.55,Vector3(.45,1.1,11.8),"brick")
	for z in [-24.0,24.0]:
		for x in [-21.0,18.0]:
			piece(geometry,"BoundaryReturn",point(Vector2(x,z))-position+Vector3.UP*.55,Vector3(24,1.1,.45),"brick")
	leaf_field()
	await Startup.checkpoint(self,"Preparing the factory's working day…")
	merge_static()
	merge_collision()
	operations=preload("res://world/suryagarh/settlements/indigo_factory_operations.gd").new()
	operations.name="Operations";add_child(operations);await operations.configure(self)
	await clear_saved_grass()
	configured=true
	# Map is already alive by the time the site's amortised setup ends.
	var world:=get_parent();var map:=world.get_node_or_null("Player/UI/WorldMap")
	if map!=null:map.refresh_sites()

func piece(parent:Node3D,label:String,at:Vector3,size:Vector3,material:String,solid:=true) -> Node3D:
	return builder.piece(parent,label,at,size,materials[material],solid)

func building(label:String,at:Vector2,size:Vector2,height:float,ventilated:bool) -> Node3D:
	var room:=Node3D.new();room.name=label;room.position=point(at)-position
	var maximum:=room.position.y
	for x in [-size.x*.5,size.x*.5]:
		for z in [-size.y*.5,size.y*.5]:maximum=maxf(maximum,point(at+Vector2(x,z)).y)
	room.position.y=maximum+.05;geometry.add_child(room)
	var floor:=piece(room,"GroundCollision",Vector3(0,-.12,0),Vector3(size.x,.24,size.y),"brick")
	var support:StaticBody3D=floor.get_child(1);Ground.register_terrain_support(self,support);support_bodies.append(support)
	for side in [-1.0,1.0]:
		piece(room,"SideWall",Vector3(side*size.x*.5,height*.5,0),Vector3(.42,height,size.y),"plaster")
	# Keep an actual 2.4m doorway in both ends, rather than a painted opening.
	for z in [-size.y*.5,size.y*.5]:
		for side in [-1.0,1.0]:
			var wall_height:=height-.9 if ventilated else height
			piece(room,"DoorSide",Vector3(side*(size.x*.25+.6),wall_height*.5,z),Vector3(size.x*.5-1.2,wall_height,.42),"plaster")
		piece(room,"DoorHeader",Vector3(0,(height+2.5)*.5,z),Vector3(2.4,height-2.5,.42),"plaster")
		for x in [-1.22,1.22]:piece(room,"DoorJamb",Vector3(x,1.25,z),Vector3(.12,2.5,.24),"wood",false)
	# Close the triangular roof ends; ventilation remains in the authored slats.
	for end in [-1.0,1.0]:
		for course in 12:
			var rise:float=(course+.5)*.125
			var width:float=maxf(.02,(size.y+1.4)*(1.0-(course+1)*.125/1.5))
			piece(room,"GableMasonry",Vector3(end*size.x*.5,height+rise,0),Vector3(.42,.125,width),"plaster")
	var ridge:=height+1.5
	for side in [-1.0,1.0]:
		var half_width:=size.x*.5+.7
		var eave:float=side*(size.y*.5+.7)
		# Metre UVs preserve tile scale; two-sided collision supports the interior.
		surface(room,"PitchedTileRoof",[Vector3(-half_width,ridge,0),Vector3(half_width,ridge,0),Vector3(-half_width,height,eave),Vector3(half_width,ridge,0),Vector3(half_width,height,eave),Vector3(-half_width,height,eave)],materials.tile,true,true)
	for x in range(-int(size.x*.5),int(size.x*.5),2):
		piece(room,"TieBeam",Vector3(x,height-.12,0),Vector3(.13,.15,size.y),"wood",false)
		if ventilated:
			for z in [-size.y*.5-.03,size.y*.5+.03]:
				piece(room,"VentPier",Vector3(x,height-.45,z),Vector3(.16,.9,.42),"brick")
				for y in [height-.75,height-.45,height-.15]:piece(room,"DryingVentSlat",Vector3(x+.85,y,z),Vector3(1.5,.08,.11),"wood",false)
	# Low masonry plinth faces meet existing terrain instead of floating slabs.
	for x in [-size.x*.5,size.x*.5]:
		for z in [-size.y*.5,size.y*.5]:
			var ground:=point(at+Vector2(x,z)).y
			var depth:=maxf(.25,maximum-ground+.25)
			piece(room,"PlinthPier",Vector3(x,-depth*.5, z),Vector3(.6,depth,.6),"brick")
	for z in [-1.0,1.0]:
		var end:=Vector3(0,height_at(Data.CENTER+at+Vector2(0,z*(size.y*.5+8)))-maximum-.05,z*(size.y*.5+8))
		ramp(room,end,Vector3(0,0,z*size.y*.5),3.0,"EntranceRamp")
	return room

func vat(parent:Node3D,at:Vector3,size:Vector2,label:String,color:Color) -> void:
	var root:=Node3D.new();root.name=label;root.position=at;parent.add_child(root)
	var lowest:=INF
	for x in [-size.x*.5,size.x*.5]:
		for z in [-size.y*.5,size.y*.5]:
			var base:=root.to_global(Vector3(x,0,z));lowest=minf(lowest,height_at(Vector2(base.x,base.z)))
	var depth:=maxf(.2,root.global_position.y-lowest+.2)
	piece(root,"VatMasonryPlinth",Vector3(0,-depth*.5,0),Vector3(size.x+.45,depth,size.y+.45),"brick")
	piece(root,"VatFloor",Vector3(0,.08,0),Vector3(size.x,.16,size.y),"brick")
	for x in [-size.x*.5,size.x*.5]:piece(root,"VatSide",Vector3(x,.55,0),Vector3(.45,1.1,size.y+.45),"brick")
	for z in [-size.y*.5,size.y*.5]:piece(root,"VatEnd",Vector3(0,.55,z),Vector3(size.x,.1+1.0,.45),"brick")
	var liquid:=MeshInstance3D.new();liquid.name="ProcessLiquor"
	var plane:=PlaneMesh.new();plane.size=size-Vector2(.5,.5);liquid.mesh=plane;liquid.position.y=.86
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.34;liquid.material_override=mat
	root.add_child(liquid);liquids.append(liquid)
	liquid.set_meta("vat_role",label)
	liquid.set_meta("factory_dynamic",true)
	if label=="Steeper":
		for x in [-2.7,0.0,2.7]:piece(root,"PlantRetainingSlat",Vector3(x,.93,0),Vector3(.12,.08,size.y-.6),"wood",false)

func ramp(parent:Node3D,start:Vector3,end:Vector3,width:float,label:String) -> void:
	var axis:=(end-start).normalized();var side:=Vector3(-axis.z,0,axis.x).normalized()*width*.5
	surface(parent,label,[start-side,start+side,end-side,start+side,end+side,end-side],materials.earth,true)

func surface(parent:Node3D,label:String,vertices:Array,mat:Material,solid:bool,both_sides:bool=false) -> void:
	# Godot uses clockwise front faces; support must face upward, not into earth.
	var upward:=PackedVector3Array()
	for i in range(0,vertices.size(),3):
		var reverse:bool=(vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).y>0
		upward.append(vertices[i]);upward.append(vertices[i+2] if reverse else vertices[i+1]);upward.append(vertices[i+1] if reverse else vertices[i+2])
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex:Vector3 in upward:st.set_uv(Vector2(vertex.x,vertex.z));st.add_vertex(vertex)
	st.generate_normals()
	var node:=MeshInstance3D.new();node.name=label;node.mesh=st.commit();node.material_override=mat;parent.add_child(node)
	if solid:
		var body:=StaticBody3D.new();body.name="GroundCollision";parent.add_child(body)
		var shape:=ConcavePolygonShape3D.new();shape.set_faces(upward);shape.backface_collision=both_sides
		var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider)
		Ground.register_terrain_support(self,body);support_bodies.append(body)

func ground_strip(route:Array,width:float,label:String) -> void:
	var faces:Array[Vector3]=[]
	for index in route.size()-1:
		var a:Vector2=route[index];var b:Vector2=route[index+1];var direction:=(b-a).normalized();var side:=Vector2(-direction.y,direction.x)*width*.5
		var count:=ceili(a.distance_to(b)/2.0)
		for i in count:
			var start:=a.lerp(b,float(i)/count);var end:=a.lerp(b,float(i+1)/count)
			for p:Vector2 in [start-side,start+side,end-side,start+side,end+side,end-side]:faces.append(Vector3(p.x,height_at(p)+.025,p.y)-position)
	surface(geometry,label,faces,materials.earth,true)

func merge_collision() -> void:
	# Keep registered terrain support separate; share one body for static fixtures.
	var merged:=StaticBody3D.new();merged.name="FactoryFixturesCollision";geometry.add_child(merged)
	for body:StaticBody3D in geometry.find_children("*","StaticBody3D",true,false):
		if body==merged or body.get_script()!=null or support_bodies.has(body):continue
		if body.collision_layer!=merged.collision_layer or body.collision_mask!=merged.collision_mask:continue
		for child in body.get_children():
			if child is CollisionShape3D:
				var frame:Transform3D=merged.global_transform.affine_inverse()*child.global_transform
				body.remove_child(child);merged.add_child(child);child.transform=frame
		body.free()

func station(id:String,at:Vector3,text:String) -> void:
	var prompt:=preload("res://story/rebellion_prompt.gd").new();prompt.name=id.to_pascal_case()+"FactoryStation"
	prompt.director=self;prompt.action_id=id;prompt.interaction_text=text;prompt.marker_height=0
	prompt.set_meta("entity_id","factory.station."+id);add_child(prompt);prompt.global_position=at;stations[id]=prompt

func can_request(id:String) -> bool:
	return configured and stations.has(id) and operations.can_request(id)
func request(id:String,actor:CharacterBody3D) -> bool:
	return operations!=null and operations.request(id,actor)

func leaf_field() -> void:
	var field:=Node3D.new();field.name="IndigoLeafPlot";geometry.add_child(field)
	field.position=Vector3(Data.FIELD.get_center().x,0,Data.FIELD.get_center().y)-position
	# The small demonstration plot is a leafy crop, never blue flowers/blue grass.
	preload("res://world/suryagarh/settlements/farm_visuals.gd").build(field,layout,Data.FIELD.size,185713)
	field.get_node("FarmPlants").multimesh.mesh=crop_mesh
	field.set_meta("crop","green paired-leaf indigo candidate; botanical art approval open")

func clear_saved_grass() -> void:
	var nature:=get_parent().get_node_or_null("Landscape/NatureTiles")
	if nature==null:return
	for node:MultiMeshInstance3D in nature.find_children("*","MultiMeshInstance3D",true,false):
		if not "Grass" in str(node.name):continue
		var bounds:=node.get_aabb();var center:=node.to_global(bounds.get_center())
		if center.distance_to(Vector3(Data.CENTER.x,center.y,Data.CENTER.y))>350:continue
		await Startup.checkpoint(self,"Clearing the factory's doorways…")
		var transforms:=Ground.instance_transforms(node.multimesh);var copy:MultiMesh
		for i in transforms.size():
			var root:=node.to_global(transforms[i].origin)
			if Data.reserved(Vector2(root.x,root.z),1.0) and not is_zero_approx(transforms[i].basis.determinant()):
				if copy==null:copy=Ground.copy_instances(node.multimesh)
				copy.set_instance_transform(i,Transform3D(Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO),transforms[i].origin));grass_removed+=1
		if copy!=null:
			if OS.get_environment("TLM_FACTORY_DIAGNOSE")=="1":print("FACTORY GRASS REPLACE ",node.get_path()," surfaces=",copy.mesh.get_surface_count())
			node.multimesh=copy
	set_meta("grass_removed",grass_removed)

func merge_static() -> void:
	var groups:Dictionary={}
	for node:MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		if node.get_meta("factory_dynamic",false) or node.material_override==null:continue
		var ancestor:Node=node.get_parent();var dynamic:=false
		while ancestor!=geometry:
			if ancestor.get_script()!=null or ancestor is Interactable or ancestor.get_meta("factory_dynamic_group",false):dynamic=true
			ancestor=ancestor.get_parent()
		if dynamic:continue
		var mat:Material=node.material_override
		if not groups.has(mat):
			var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);groups[mat]=st
		preload("res://systems/static_mesh_source.gd").append(groups[mat],node.mesh,0,geometry.global_transform.affine_inverse()*node.global_transform)
		node.queue_free()
	for mat:Material in groups:
		var merged:=MeshInstance3D.new();merged.name="FactoryMasonryAndTimber";merged.mesh=groups[mat].commit();merged.material_override=mat
		merged.visibility_range_end=450;merged.visibility_range_end_margin=30;geometry.add_child(merged)

func _exit_tree() -> void:
	# Shared RID set is world-owned; remove only factory additions while alive.
	for body in support_bodies:
		if is_instance_valid(body) and is_instance_valid(get_parent()):Ground.unregister_terrain_support(self,body)
	if is_instance_valid(builder):builder.free()
