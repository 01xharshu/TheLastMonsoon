extends Node3D
const Layout=preload("res://world/suryagarh/landscape_layout.gd")
const Actor=preload("res://characters/npcs/households/household_npc_actor.gd")
var layout:=Layout.new()
var journeys:Array[Node]=[]
var lanes:Array[MeshInstance3D]=[]
var surface_samples:Array[Vector3]=[]
const HOME_MARKET: Array[Vector2]=[Vector2(-321,206),Vector2(-321,199),Vector2(-355,199),Vector2(-355,230),Vector2(-355,275),Vector2(-338,275),Vector2(-338,271.2)]
const HOME_GRAIN: Array[Vector2]=[Vector2(-277,306),Vector2(-277,312),Vector2(-250,312),Vector2(-250,275),Vector2(-270,275),Vector2(-270,289),Vector2(-280,289)]
func _ready() -> void:
	name="VillageStreetLife"
	add_to_group("village_street_life")
	for label in ["village_spine","village_west_lane","village_market_lane","village_north_lane","village_south_lane","village_west_link","village_estate_approach"]:
		var width:float=5.0 if label=="village_spine" else (4.0 if label in ["village_market_lane","village_north_lane"] else 3.4)
		_lane(label,Layout.ROUTES[label],width,1.0)
	_lane("HomeMarketFootApproach",[HOME_MARKET[0],HOME_MARKET[1],HOME_MARKET[2]],1.6,.0)
	_lane("NorthernHouseFootApproach",[HOME_GRAIN[0],HOME_GRAIN[1]],1.6,.0)
	_resident("ClothMarketVisitor","res://characters/npcs/households/merchant.glb",HOME_MARKET,0.0)
	_resident("GrainStoreBuyer","res://characters/npcs/households/landowner.glb",HOME_GRAIN,3.0)

func _resident(label:String,path:String,route:Array[Vector2],delay:float) -> void:
	var actor:=Actor.new();actor.name=label
	actor.movement_enabled=false;actor.patrol_distance=0
	actor.position=Vector3(route[0].x,layout.height(route[0].x,route[0].y),route[0].y)
	actor.add_child(load(path).instantiate());add_child(actor)
	_fit_footwear(actor)
	actor.add_to_group("village_street_resident")
	actor.set_meta("role",label)
	var journey:=preload("res://world/suryagarh/settlements/street_journey.gd").new()
	journey.name="StreetJourney";journey.configure(actor,route,delay);actor.add_child(journey)
	journeys.append(journey)

func _lane(label:String,points:Array,width:float,wear:float) -> void:
	var material:=ShaderMaterial.new();material.shader=preload("res://world/suryagarh/settlements/earth_lane.gdshader")
	material.set_shader_parameter("earth_texture",preload("res://assets/nature/materials/brown_mud_dry_diff_1k.jpg"))
	material.set_shader_parameter("earth_normal",preload("res://assets/nature/materials/brown_mud_dry_nor_gl_1k.jpg"))
	material.set_shader_parameter("lane_width",width);material.set_shader_parameter("wheel_wear",wear)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var run:=0.0
	for i in points.size()-1:
		var a:Vector2=points[i];var b:Vector2=points[i+1]
		var length:=a.distance_to(b);var steps:=maxi(1,ceili(length/1.5))
		var side:=Vector2(-(b-a).y,(b-a).x).normalized()*width*.5
		for step in steps:
			var p:=a.lerp(b,float(step)/steps);var q:=a.lerp(b,float(step+1)/steps)
			var verts:Array[Vector2]=[p-side,p+side,q-side,q+side]
			var uv:Array[Vector2]=[Vector2(0,run+length*step/steps),Vector2(1,run+length*step/steps),Vector2(0,run+length*(step+1)/steps),Vector2(1,run+length*(step+1)/steps)]
			for index in [0,2,1,1,2,3]:
				var point:=verts[index]
				var vertex:=Vector3(point.x,layout.height(point.x,point.y)+.018,point.y)
				st.set_normal(Vector3.UP);st.set_uv(uv[index]);st.add_vertex(vertex);surface_samples.append(vertex)
		run+=length
	var mesh:=MeshInstance3D.new();mesh.name=label;mesh.mesh=st.commit();mesh.material_override=material
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh);lanes.append(mesh)

func _fit_footwear(actor: Node3D) -> void:
	# Candidate-instance correction; imported household meshes stay untouched.
	for node in actor.find_children("*","MeshInstance3D",true,false):
		if not "leather shoe" in str(node.name).to_lower(): continue
		var source: Mesh = node.mesh
		var bounds := source.get_aabb()
		var axis := 0 if bounds.size.x>bounds.size.z else 2
		var length: float = bounds.size[axis]
		if length <= .30: continue
		var factor := .28/length
		var centre := bounds.get_center()
		var fitted := ArrayMesh.new()
		for surface in source.get_surface_count():
			var arrays := source.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for index in vertices.size():
				var vertex := vertices[index]
				vertex[axis] = centre[axis]+(vertex[axis]-centre[axis])*factor
				vertices[index] = vertex
				if index<normals.size():
					var normal := normals[index];normal[axis]/=factor;normals[index]=normal.normalized()
			arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
			fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			fitted.surface_set_material(surface,source.surface_get_material(surface))
		node.mesh=fitted
