extends "res://tools/world/bake_landscape.gd"
const Density=preload("res://world/suryagarh/settlements/countryside_density.gd")
var builder:Node3D
var density:Node3D
var survey:RefCounted
var soil:Material
var cleared:=0
func bake() -> void:
	if DisplayServer.get_name()=="headless":push_error("Density bake requires native MultiMesh serialization");quit(1);return
	world.free() # Release the base baker’s unused placeholder before incremental load.
	world=load(OUT+"landscape.scn").instantiate();root.add_child(world)
	survey=preload("res://tools/world/density_ground.gd").new();survey.configure(world)
	# Use existing architectural helpers without starting their runtime settlement build.
	builder=Node3D.new()
	density=Node3D.new();density.name="CountrysideDensity";root.add_child(density)
	density.add_child(builder);builder.set_script(load("res://world/suryagarh/settlements/settlement_builder.gd"));builder.set_process(false)
	builder.layout=survey
	builder.plaster=builder.material(Color(.76,.70,.56));builder.ochre=builder.material(Color(.55,.40,.24))
	builder.brick=builder.material(Color(.44,.24,.16),true);builder.wood=builder.material(Color(.23,.13,.07))
	builder.tile=builder.material(Color(.43,.19,.105),true);builder.stone=builder.material(Color(.42,.40,.33),true)
	builder.iron=builder.material(Color(.13,.14,.13))
	soil=StandardMaterial3D.new();soil.albedo_texture=load("res://assets/nature/materials/brown_mud_dry_diff_1k.jpg");soil.roughness=1;soil.albedo_color=Color(.68,.58,.43)
	var detail:RefCounted=load("res://world/suryagarh/settlements/bhairavpur_house_detail.gd").new()
	var palette:Array[Material]=[builder.ochre,builder.material(Color(.67,.55,.39)),builder.material(Color(.72,.66,.53)),builder.material(Color(.53,.44,.30))]
	detail.configure(builder,palette)
	var index:=0
	for site in Density.homes():
		var house:Node3D=builder.make_building("DensityHome%02d"%index,site.p,site.size,false,false,false,true)
		house.rotation.y=site.yaw
		for mesh in house.find_children("*","MeshInstance3D",true,false):
			if mesh.material_override==builder.ochre:mesh.material_override=palette[index%palette.size()]
		detail._roof(house,site.size,index)
		house.set_meta("district",site.kind);house.add_to_group("density_home",true)
		# Place level architecture above the highest saved terrain corner. The solid
		# footing extends down to the lowest corner; a separate ramp meets the door.
		var high:float=-INF;var low:float=INF
		for x in [-site.size.x*.5-.5,site.size.x*.5+.5]:
			for z in [-site.size.y*.5-.5,site.size.y*.5+.5]:
				var p:Vector3=house.to_global(Vector3(x,0,z));var h:float=survey.height(p.x,p.z)
				high=maxf(high,h);low=minf(low,h)
		house.position.y=high+.02
		builder.piece(house,"GroundedFooting",Vector3(0,-(high-low)*.5-.13,0),Vector3(site.size.x+.8,high-low+.28,site.size.y+.8),builder.stone)
		var doorstep:Vector3=house.to_global(Vector3(0,.24,site.size.y*.5+.55))
		var end:Vector3=house.to_global(Vector3(0,0,site.size.y*.5+4));end.y=survey.height(end.x,end.z)+.035
		for distance in [6.0,8.0,10.0,14.0]:
			if absf(doorstep.y-end.y)/Vector2(doorstep.x-end.x,doorstep.z-end.z).length()<=.3:break
			end=house.to_global(Vector3(0,0,site.size.y*.5+distance));end.y=survey.height(end.x,end.z)+.035
		var run:float=Vector2(doorstep.x-end.x,doorstep.z-end.z).length()
		# Entrance grade is verified physically by the review fixture.
		if absf(doorstep.y-end.y)/run>.4:push_error("Unwalkable density entrance");quit(1);return
		var ramp:Node3D=builder.piece(house,"DoorApproach",house.to_local((doorstep+end)*.5)-Vector3.UP*.07,Vector3(2.7,.14,doorstep.distance_to(end)+.2),builder.stone)
		ramp.rotation.x=atan2(doorstep.y-end.y,run)
		# Courtyard storage sits to the side, leaving a continuous entrance lane.
		for k in 2:
			var prop:Node3D=load("res://objects/household/storage/"+(["basket","brass_pot","crate"][index%3])+".tscn").instantiate()
			house.add_child(prop);prop.position=Vector3(site.size.x*.5-1,.24,1.2-k*2)
		# Low yard sides occupy frontage gaps while keeping the doorway clear.
		for side in [-1.0,1.0]:
			builder.piece(house,"YardBoundary",Vector3(side*(site.size.x*.5+.8),.65,site.size.y*.5+1.3),Vector3(.22,.85,3.5),palette[index%palette.size()])
		builder.merge_visuals(house);index+=1
	for z in [80.0,-95.0,-240.0]:build_shed(Vector2(-556,z+14))
	build_tree_belts()
	for i in Density.fields().size():build_field(Density.fields()[i],i)
	for lane in Density.lanes():
		for i in range(lane.size()-1):build_lane(lane[i],lane[i+1])
	await process_frame
	# Keep only static authored nodes in the export: no settlement script or ready hooks.
	builder.set_script(null)
	for node in density.find_children("*","Node",true,false):
		node.scene_file_path=""
		node.owner=density
	var packed:=PackedScene.new();assert(packed.pack(density)==OK)
	save_resource(packed,"countryside_density.scn")
	# Clear only the authored footprint; terrain, map, distant vegetation and all
	# existing district/household changes are preserved.
	for batch in world.get_node("NatureTiles").find_children("*","MultiMeshInstance3D",true,false):
		var mm:MultiMesh=batch.multimesh;var copy:MultiMesh
		for i in mm.instance_count:
			var t:=mm.get_instance_transform(i)
			if is_zero_approx(t.basis.determinant()):continue
			var p:Vector3=batch.global_transform*t.origin
			if p.x < -660 or p.x > -230 or p.z < -450 or p.z > 350:continue
			if not Density.clearance(Vector2(p.x,p.z)):continue
			if copy==null:copy=mm.duplicate()
			t.basis=Basis.IDENTITY.scaled(Vector3.ZERO);copy.set_instance_transform(i,t);cleared+=1
		if copy!=null:batch.multimesh=copy
	for body in world.get_node("NatureTiles").find_children("*","StaticBody3D",true,false):
		if Density.clearance(Vector2(body.global_position.x,body.global_position.z)):
			body.get_parent().remove_child(body);body.free()
	# Terrain LOD can simplify through a thin soil overlay. Match the underlying
	# terrain shading to authored plots so no grass patches emerge at distance.
	var mask:=Image.create(1024,1024,false,Image.FORMAT_RGB8)
	for center in Density.fields():
		var min_pixel:=((center-Density.FIELD_SIZE*.5+Vector2.ONE*Layout.HALF)/Layout.SIZE*1024).floor()
		var max_pixel:=((center+Density.FIELD_SIZE*.5+Vector2.ONE*Layout.HALF)/Layout.SIZE*1024).ceil()
		for z in range(int(min_pixel.y),int(max_pixel.y)):
			for x in range(int(min_pixel.x),int(max_pixel.x)):mask.set_pixel(x,z,Color(1,0,0))
	var texture:=ImageTexture.create_from_image(mask);save_resource(texture,"density_mask.res");texture.take_over_path(OUT+"density_mask.res")
	terrain_material=load(OUT+"terrain_material.tres");terrain_material.set_shader_parameter("density_mask_tex",texture)
	save_resource(terrain_material,"terrain_material.tres")
	for tile in world.get_node("TerrainTiles").get_children():tile.material_override=terrain_material
	packed=PackedScene.new();assert(packed.pack(world)==OK);save_resource(packed,"landscape.scn")
	density.free();world.free();survey=null
	for frame in 4:await process_frame
	print("DENSITY_BAKE homes=",index," fields=",Density.fields().size()," sheds=3 cleared=",cleared)
	quit()
func surface(parent:Node3D,center:Vector2,size:Vector2,mat:Material,lift:=.035) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx:=ceili(size.x/1.5);var nz:=ceili(size.y/1.5)
	for iz in nz:
		for ix in nx:
			for c:Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var p:=center-size*.5+Vector2((ix+c.x)*size.x/nx,(iz+c.y)*size.y/nz)
				st.set_uv(p/3);st.add_vertex(Vector3(p.x,survey.height(p.x,p.y)+lift,p.y))
	st.generate_normals();var mesh:=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=mat
	mesh.visibility_range_end=950;mesh.visibility_range_end_margin=80;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(mesh)
func build_field(center:Vector2,index:int) -> void:
	var field:=Node3D.new();field.name="Field%02d"%index;density.add_child(field);field.add_to_group("density_field",true)
	field.set_meta("center",center);field.set_meta("size",Density.FIELD_SIZE)
	surface(field,center,Density.FIELD_SIZE,soil,.08)
	for side in [-1.0,1.0]:
		surface(field,center+Vector2(side*21,0),Vector2(.75,31),builder.ochre,.12)
		surface(field,center+Vector2(0,side*15),Vector2(42,.75),builder.ochre,.12)
	if index%4==0:return # Worked fallow plots break up the planted carpet.
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true
	mm.mesh=preload("res://world/suryagarh/settlements/farm_visuals.gd").plant_mesh();mm.instance_count=40*28
	var random:=RandomNumberGenerator.new();random.seed=1857+index
	for row in 28:
		for col in 40:
			var p:=center+Vector2(-19.5+col,-13.5+row)+Vector2(random.randf_range(-.12,.12),random.randf_range(-.1,.1))
			var scale_value:float=random.randf_range(1.1,1.8)*(.5 if index%3==0 else 1.0)
			mm.set_instance_transform(row*40+col,Transform3D(Basis(Vector3.UP,random.randf()*TAU).scaled(Vector3.ONE*scale_value),Vector3(p.x,survey.height(p.x,p.y)+.025,p.y)))
			mm.set_instance_color(row*40+col,Color(.28,.39,.12).lerp(Color(.49,.47,.21),random.randf()).srgb_to_linear())
	var plants:=MultiMeshInstance3D.new();plants.multimesh=mm;plants.material_override=ShaderMaterial.new()
	plants.material_override.shader=preload("res://world/suryagarh/settlements/farm_foliage.gdshader")
	plants.visibility_range_end=160;plants.visibility_range_end_margin=25;plants.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;field.add_child(plants)
func build_lane(a:Vector2,b:Vector2) -> void:
	var steps:=ceili(a.distance_to(b)/1.5)
	var direction:Vector2=(b-a).normalized();var side:=Vector2(-direction.y,direction.x)*1.7
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in steps:
		var start:=a.lerp(b,float(i)/steps);var end:=a.lerp(b,float(i+1)/steps)
		for p:Vector2 in [start-side,start+side,end-side,start+side,end+side,end-side]:
			st.set_uv(p/3);st.add_vertex(Vector3(p.x,survey.height(p.x,p.y)+.045,p.y))
	st.generate_normals();var mesh:=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=soil;mesh.visibility_range_end=950;density.add_child(mesh)
func build_shed(p:Vector2) -> void:
	var shed:=Node3D.new();shed.name="FarmStore%d"%int(p.y);builder.add_child(shed)
	shed.position=Vector3(p.x,survey.height(p.x,p.y),p.y)
	builder.piece(shed,"StorePlinth",Vector3(0,.16,0),Vector3(9,.32,7),builder.stone)
	for x in [-4.0,4.0]:
		for z in [-3.0,3.0]:builder.piece(shed,"TimberPost",Vector3(x,1.8,z),Vector3(.2,3.6,.2),builder.wood)
	for side in [-1.0,1.0]:
		builder.piece(shed,"PitchedRoof",Vector3(side*2.2,3.7,0),Vector3(4.8,.18,8),builder.tile).rotation.z=side*-.22
	builder.piece(shed,"RearWall",Vector3(0,1.7,-3),Vector3(8,3,.25),builder.ochre)
	for x in [-2.5,0.0,2.5]:
		builder.piece(shed,"GrainBin",Vector3(x,.8,-1.7),Vector3(1.8,1.2,1.6),builder.wood)
	builder.merge_visuals(shed)

func build_tree_belts() -> void:
	# Share the forest owner's textures, trunk geometry and three real LOD meshes.
	# Only authored positions are new; there is no runtime forest regeneration.
	var importer:Node3D=load("res://environment/forest/scripts/forest_generator.gd").new()
	importer.config=load("res://environment/forest/config/suryagarh_patch.tres")
	var chunks:Dictionary={}
	var random:=RandomNumberGenerator.new();random.seed=18571010
	for p in Density.trees():
		var key:=Vector2i(floori(p.x/45),floori(p.y/45))
		if not chunks.has(key):chunks[key]=[]
		var size:=random.randf_range(.85,1.15)
		chunks[key].append(Transform3D(Basis(Vector3.UP,random.randf()*TAU).scaled(Vector3.ONE*size),Vector3(p.x,survey.height(p.x,p.y)-.06,p.y)))
		var body:=StaticBody3D.new();body.name="ShelterbeltTrunk";body.position=Vector3(p.x,survey.height(p.x,p.y)+3.5*size,p.y)
		var collision:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new();cylinder.radius=.48*size;cylinder.height=7*size;collision.shape=cylinder;body.add_child(collision);density.add_child(body)
	for lod in 3:
		var meshes:Array=importer._scene_meshes(load("res://environment/forest/assets/canopy_broad_lod%d.glb"%lod))
		for key in chunks:
			var center:=Vector3(key.x*45+22.5,0,key.y*45+22.5)
			for mesh in meshes:
				var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=chunks[key].size()
				for i in mm.instance_count:
					var t:Transform3D=chunks[key][i];t.origin-=center;mm.set_instance_transform(i,t)
				var batch:=MultiMeshInstance3D.new();batch.name="ShelterbeltLOD%d"%lod;batch.multimesh=mm;batch.position=center
				batch.visibility_range_begin=[0,55,160][lod];batch.visibility_range_end=[55,160,900][lod]
				batch.visibility_range_begin_margin=8;batch.visibility_range_end_margin=8;batch.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				density.add_child(batch)
	importer.free();density.set_meta("shelterbelt_trees",Density.trees().size())
