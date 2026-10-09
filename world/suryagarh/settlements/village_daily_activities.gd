extends Node3D
## Bounded additions to existing surveyed village life; no duplicate cattle/police.
const Actor=preload("res://characters/npcs/indian/indian_street_actor.gd")
const Activity=preload("res://world/suryagarh/settlements/resident_activity.gd")
var layout:=preload("res://world/suryagarh/landscape_layout.gd").new()
var residents:Array[Node3D]=[]
var pending:Array[Dictionary]=[]
var wait:=0.0
var viewer:Node3D
var owned_horse:Node3D
var saved_residents:Dictionary={}

func _ready() -> void:
	name="VillageDailyActivities";add_to_group("village_daily_activities")
	prepare.call_deferred()

func prepare() -> void:
	await get_tree().process_frame
	viewer=get_parent().get_node_or_null("Player")
	pending=[
		{"job":"hoe","sex":"male","id":1,"at":Vector2(-289,333),"home":Vector2(-289,328)},
		{"job":"sow","sex":"male","id":3,"at":Vector2(-286,335),"home":Vector2(-286,328)},
		{"job":"hoe","sex":"male","id":2,"at":Vector2(-277,345),"home":Vector2(-277,339)},
		{"job":"sow","sex":"female","id":3,"at":Vector2(-280,343),"home":Vector2(-280,337)},
		{"job":"well","sex":"female","id":1,"at":Vector2(-289,229.3),"home":Vector2(-286,225)},
		{"job":"well","sex":"female","id":2,"at":Vector2(-290.6,231.0),"home":Vector2(-295,231)},
		{"job":"social","sex":"female","id":3,"at":Vector2(-286,233),"home":Vector2(-284,237)},
		{"job":"social","sex":"female","id":4,"at":Vector2(-285,234),"home":Vector2(-282,238)},
		{"job":"social","sex":"male","id":2,"at":Vector2(-294.45,235),"home":Vector2(-296,239),"seat":true},
		{"job":"social","sex":"male","id":4,"at":Vector2(-293.5,235),"home":Vector2(-296,237),"seat":true},
		{"job":"carry","sex":"male","id":1,"at":Vector2(-355,251),"home":Vector2(-355,235)},
		{"job":"carry","sex":"female","id":4,"at":Vector2(-250,280),"home":Vector2(-250,294)},
		{"job":"inspect","role":"landowner","sex":"male","id":2,"at":Vector2(-283,340),"home":Vector2(-321,337)}]
	_fields()
	_home_horse()
	if owned_horse!=null:
		var at:=Vector2(owned_horse.global_position.x-.9,owned_horse.global_position.z)
		pending.append({"job":"groom","sex":"male","id":4,"at":at,"home":at+Vector2(-2,2)})
	set_process(true)

func _process(delta:float) -> void:
	wait-=delta
	if pending.is_empty():set_process(false);return
	if wait>0:return
	wait=.12
	_spawn(pending.pop_front())

func _spawn(record:Dictionary) -> void:
	var actor:=Actor.new();actor.name="Village_%s_%02d"%[record.job,residents.size()]
	actor.movement_enabled=false;actor.cycle_offset=residents.size()*.47;actor.ground_height=layout.height
	actor.movement_profile=&"female" if record.sex=="female" else &"male"
	actor.household_job=record.job
	var role: String=record.get("role",{"hoe":"tenant_farmer","sow":"tenant_farmer","well":"household_worker","carry":"porter","groom":"groom","social":"villager"}.get(record.job,"villager"))
	actor.set_meta("social_role",role);actor.set_meta("assigned_workplace",record.at)
	var source:="res://characters/npcs/street_residents/%s_%02d.glb"%[record.sex,record.id]
	if record.sex=="male" and record.job not in ["social","inspect"]:source="res://characters/npcs/street_residents/workman_%02d.glb"%record.id
	actor.add_child(preload("res://characters/human_scene.gd").instantiate(source,false))
	var at:Vector2=record.at;actor.position=Vector3(at.x,layout.height(at.x,at.y),at.y)
	if record.job=="well":actor.rotation.y=atan2(-289-at.x,231-at.y)
	if record.job=="social":actor.rotation.y=PI*.25 if residents.size()%2==0 else -PI*.75
	if record.job=="groom":actor.rotation.y=PI*.5
	add_child(actor);actor.add_to_group("village_work_residents");actor.set_meta("human_source",source)
	var activity:=Activity.new();activity.name="DailyActivity";activity.actor=actor;activity.job=record.job;activity.social_role=role
	activity.home=record.home;activity.workplace=record.at;activity.viewer=viewer;activity.elapsed=residents.size()*.71
	activity.seated=record.get("seat",false)
	if record.job=="groom":activity.animal=owned_horse
	var nearest:Node3D
	var best:=INF
	for house:Node3D in get_tree().get_nodes_in_group("bhairavpur_home"):
		var distance:float=house.global_position.distance_squared_to(actor.global_position)
		if distance<best:best=distance;nearest=house
	if nearest!=null:
		actor.set_meta("assigned_house",str(nearest.get_path()))
		var front:Vector3=nearest.to_global(Vector3(0,0,5.6))
		var side:Vector3=nearest.to_global(Vector3(5.3,0,5.6))
		activity.home=Vector2(front.x,front.z)
		var corner:=Vector2(side.x,at.y) if absf(nearest.global_basis.x.x)>.5 else Vector2(at.x,side.z)
		activity.commute=[activity.home,Vector2(side.x,side.z),corner,at]
		activity.route_goal=activity.commute.size()-1
	if role=="landowner":
		activity.home=Vector2(-321,337);activity.commute=[activity.home,Vector2(-321,330),Vector2(-283,330),at];activity.route_goal=3
	actor.add_child(activity);residents.append(actor)
	activity.restore_state(saved_residents.get(str(actor.name),{}))
	for mesh:GeometryInstance3D in actor.find_children("*","GeometryInstance3D",true,false):
		mesh.visibility_range_end=150;mesh.visibility_range_end_margin=15

func _fields() -> void:
	# Real separated young plants and furrows replace rectangular crop bars only
	# on the two plots with sowing/hoeing. Existing survey and terrain stay owned.
	for label in ["EstateField0","EstateField3"]:
		var field:=get_tree().root.find_child(label,true,false) as Node3D
		if field==null:continue
		for node in field.get_children():
			if str(node.name).begins_with("CropRow"):node.hide()
			if node is MeshInstance3D and str(node.name)=="VillageMergedGeometry":
				for surface in node.mesh.get_surface_count():
					var material:Material=node.get_active_material(surface)
					var color:=Color.WHITE
					if material is StandardMaterial3D:color=material.albedo_color
					elif material is ShaderMaterial:color=material.get_shader_parameter("tint")
					if not color.is_equal_approx(Color(.20,.33,.12)):continue
					var invisible:=StandardMaterial3D.new();invisible.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
					invisible.albedo_color=Color(0,0,0,0);node.set_surface_override_material(surface,invisible)
		var blade:=ArrayMesh.new();var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for turn in [0.0,PI*.5]:
			var side:=Vector3(cos(turn)*.018,0,sin(turn)*.018)
			for p in [-side,Vector3(.015,.24,.02),side]:st.add_vertex(p)
		st.generate_normals();blade=st.commit()
		var green:=StandardMaterial3D.new();green.albedo_color=Color(.27,.34,.12);green.cull_mode=BaseMaterial3D.CULL_DISABLED;blade.surface_set_material(0,green)
		var plants:=MultiMesh.new();plants.transform_format=MultiMesh.TRANSFORM_3D;plants.mesh=blade;plants.instance_count=240
		for i in 240:
			var x:float=-3.9+float(i%40)*.2;var z:float=-3+float(i/40)*1.1
			var point:=field.to_global(Vector3(x,0,z));point.y=layout.height(point.x,point.z)+.04
			plants.set_instance_transform(i,Transform3D(Basis(Vector3.UP,i*2.4).scaled(Vector3.ONE*(.7+.3*sin(i*1.7))),field.to_local(point)))
		var visual:=MultiMeshInstance3D.new();visual.name="YoungCropRows";visual.multimesh=plants;visual.visibility_range_end=130;field.add_child(visual)
		var furrow:=SurfaceTool.new();furrow.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row in 6:
			for step in 16:
				var x:float=-4+step*.5;var z:float=-3.3+row*1.1
				for p in [Vector2(x,z),Vector2(x+.5,z),Vector2(x,z+.16),Vector2(x+.5,z),Vector2(x+.5,z+.16),Vector2(x,z+.16)]:
					var world:=field.to_global(Vector3(p.x,0,p.y));world.y=layout.height(world.x,world.z)+.045
					furrow.set_normal(Vector3.UP);furrow.add_vertex(field.to_local(world))
		var earth:=StandardMaterial3D.new();earth.albedo_color=Color(.24,.18,.12);earth.roughness=1.0
		var soil:=MeshInstance3D.new();soil.name="WorkedFurrows";soil.mesh=furrow.commit();soil.material_override=earth;soil.visibility_range_end=130;field.add_child(soil)

func _home_horse() -> void:
	var homes:=get_tree().get_nodes_in_group("arjun_home")
	if homes.is_empty():return
	var house:Node3D=homes[0]
	for horse:Node3D in get_tree().get_nodes_in_group("horses"):
		if str(horse.name)!="VillageHorse" or horse.rider!=null:continue
		owned_horse=horse;horse.set_meta("owner","Arjun");horse.set_meta("owner_home",str(house.get_path()))
		var point:=house.to_global(Vector3(6,0,5));point.y=layout.height(point.x,point.z)+.08
		horse.global_position=point;horse.rotation.y=PI;house.set_meta("owns_horse",true)
		break

func export_state()->Dictionary:
	var state:Dictionary=saved_residents.duplicate(true)
	for resident in residents:state[str(resident.name)]=resident.get_node("DailyActivity").export_state()
	return state

func restore_state(state:Dictionary)->void:
	saved_residents=state.duplicate(true)
	for resident in residents:resident.get_node("DailyActivity").restore_state(state.get(str(resident.name),{}))
