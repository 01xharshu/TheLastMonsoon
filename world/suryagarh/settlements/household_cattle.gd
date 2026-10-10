extends Node3D
## Household ownership and usable care station; visual cow remains a candidate.
const Layout=preload("res://world/suryagarh/landscape_layout.gd")
var layout:=Layout.new()
var house:Node3D
var cow:Node3D
var water_surface:MeshInstance3D
var fodder:MeshInstance3D
var feed_portions:=1
var fodder_stock:=4
var water_liters:=4.0
var floor_samples:Array[Vector3]=[]
var supports:Array[Node3D]=[]
var motion:Node
var caretaker:Node
func _ready()->void:
	name="NorthLaneHouseholdCattle"
	for home in get_tree().get_nodes_in_group("bhairavpur_home"):
		if home.name=="BhairavpurHouse27":house=home;break
	if house==null:push_error("Cattle household not found");return
	add_to_group("household_cattle")
	set_meta("owner_house",str(house.get_path()))
	house.set_meta("owns_cow",true)
	position=Vector3(-321,layout.height(-321,289),289)
	var wood:=material(Color(.24,.15,.075));var clay:=material(Color(.46,.34,.22));var straw:=material(Color(.47,.39,.19))
	for x in [-2.5,2.5]:
		for z in [-2.1,2.1]:
			var base:=Vector3(x,ground(x,z),z)
			var post:=piece("ShelterPost",base+Vector3.UP*1.25,Vector3(.13,2.5,.13),wood)
			supports.append(post);floor_samples.append(to_global(base))
	for z in [-2.1,2.1]:piece("RoofBeam",Vector3(0,2.47,z),Vector3(5.15,.16,.14),wood)
	var thatch:=ShaderMaterial.new();thatch.shader=preload("res://world/suryagarh/settlements/yard_thatch.gdshader")
	for x in [-1.3,1.3]:
		var roof:=piece("ThatchRoof",Vector3(x,2.7,0),Vector3(2.75,.20,4.7),thatch)
		roof.rotation.z=(-.19 if x>0 else .19)
	# Low side fence, open at the rear approach; doors and street stay clear.
	for x in [-2.5,2.5]:
		for y in [.48,.87]:piece("SideRail",Vector3(x,y,0),Vector3(.07,.065,4.3),wood)
	cow=preload("res://assets/animals/cow/household_cow.glb").instantiate();cow.name="HouseholdCow";add_child(cow)
	preload("res://animals/cow_visual.gd").apply(cow)
	cow.position.y=ground(0,0)
	cow.set_meta("owner_house",str(house.get_path()));cow.add_to_group("household_cows")
	var body:=AnimatableBody3D.new();body.sync_to_physics=false;body.name="CowBody";cow.add_child(body)
	var shape:=CollisionShape3D.new();shape.name="BodyShape";var box:=BoxShape3D.new();box.size=Vector3(.78,.85,1.9);shape.shape=box;shape.position=Vector3(0,1.09,.1);body.add_child(shape)
	var anim:=cow.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if anim!=null:
		anim.get_animation("idle").loop_mode=Animation.LOOP_LINEAR
		anim.play("idle")
	var feed_point:=Vector3(1.1,ground(1.1,-1.6),-1.6)
	var water_point:=Vector3(-1.1,ground(-1.1,-1.6),-1.6)
	for entry in [["Manger",feed_point],["WaterTrough",water_point]]:
		var p:Vector3=entry[1]
		piece(entry[0]+"Base",p+Vector3.UP*.18,Vector3(.62,.16,.85),clay)
		for side in [-1,1]:piece(entry[0]+"Side",p+Vector3(side*.29,.36,0),Vector3(.065,.32,.85),clay)
		for side in [-1,1]:piece(entry[0]+"End",p+Vector3(0,.36,side*.39),Vector3(.62,.32,.065),clay)
	fodder=piece("Fodder",feed_point+Vector3.UP*.36,Vector3(.48,.15,.67),straw,false)
	water_surface=piece("Water",water_point+Vector3.UP*.37,Vector3(.48,.01,.67),material(Color(.19,.28,.27)),false)
	var basket:Node3D=preload("res://assets/props/polyhaven/wicker_basket_01/wicker_basket_01_1k.gltf").instantiate();add_child(basket);basket.position=Vector3(1.1,ground(1.1,1.5),1.5)
	for entry in [["fodder",feed_point],["water",water_point]]:
		var care:=preload("res://world/suryagarh/settlements/cattle_care.gd").new();care.name="Care_"+entry[0];care.yard=self;care.action=entry[0];care.position=entry[1]+Vector3.UP*.38
		var collision:=CollisionShape3D.new();var target:=BoxShape3D.new();target.size=Vector3(.75,.6,.95);collision.shape=target;care.add_child(collision);add_child(care)
	refresh_supplies()
	# One shared blade batch replaces 28 separate box meshes in the grazing patch.
	var grass:=MultiMesh.new();grass.transform_format=MultiMesh.TRANSFORM_3D
	grass.mesh=preload("res://world/suryagarh/grass_blades.gd").make_mesh()
	grass.instance_count=48
	for i in 48:
		var x:float=sin(i*2.4)*.31;var z:float=2.73+cos(i*1.7)*.28
		grass.set_instance_transform(i,Transform3D(Basis(Vector3.UP,i*1.7).scaled(Vector3.ONE*.65),Vector3(x,ground(x,z)+.015,z)))
	var patch:=MultiMeshInstance3D.new();patch.name="GrazingGrass";patch.multimesh=grass
	patch.visibility_range_end=55;patch.visibility_range_end_margin=8;patch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(patch)
	# Static shelter surfaces batch by shared material; collision children stay put.
	batch_shelter()
	motion=preload("res://animals/cow_motion.gd").new();motion.name="CowMotion";motion.configure(self,cow);cow.add_child(motion)
	caretaker=preload("res://animals/cattle_caretaker.gd").new();caretaker.name="HouseholdCaretaker";caretaker.yard=self;add_child(caretaker)
func ground(x:float,z:float)->float:return layout.height(position.x+x,position.z+z)-position.y
func material(color:Color)->StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.9;return m
func piece(label:String,at:Vector3,size:Vector3,mat:Material,solid:=true)->MeshInstance3D:
	var visual:=MeshInstance3D.new();visual.name=label;var mesh:=BoxMesh.new();mesh.size=size;visual.mesh=mesh;visual.material_override=mat;visual.position=at;add_child(visual)
	if solid:
		var body:=StaticBody3D.new();var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collider.shape=shape;body.add_child(collider);visual.add_child(body)
	return visual
func refresh_supplies()->void:
	fodder.visible=feed_portions>0;fodder.scale.y=.5+feed_portions*.3
	water_surface.visible=water_liters>0
	water_surface.position.y=ground(-1.1,-1.6)+.25+.015*water_liters

func export_state()->Dictionary:
	return {"feed_portions":feed_portions,"fodder_stock":fodder_stock,"water_liters":water_liters}
func restore_state(state:Dictionary)->void:
	feed_portions=clampi(int(state.get("feed_portions",1)),0,3)
	fodder_stock=clampi(int(state.get("fodder_stock",4)),0,4)
	water_liters=clampf(float(state.get("water_liters",4)),0,8)
	refresh_supplies()

func batch_shelter()->void:
	var surfaces:Dictionary={}
	for node in get_children():
		if not node is MeshInstance3D or node in [fodder,water_surface]:continue
		var mat:Material=node.material_override
		if not surfaces.has(mat):
			var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);surfaces[mat]=st
		preload("res://systems/static_mesh_source.gd").append(surfaces[mat],node.mesh,0,node.transform)
		# Preserve supports, physical shapes and their transforms for care/collision.
		node.mesh=null
	var merged:=ArrayMesh.new()
	for mat:Material in surfaces:
		surfaces[mat].set_material(mat);surfaces[mat].commit(merged)
	var visual:=MeshInstance3D.new();visual.name="ShelterBatched";visual.mesh=merged
	visual.visibility_range_end=180;visual.visibility_range_end_margin=20;add_child(visual)
