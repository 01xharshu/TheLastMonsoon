extends RefCounted
## World-integrated dressing for the existing mission-owned undercroft. The
## central follow route, target lane and mission prompts remain unobstructed.
static func build(builder:Node, cellar:Node3D) -> void:
 var root:=Node3D.new();root.name="HideoutEnvironment";cellar.add_child(root)
 var stone:=StandardMaterial3D.new();stone.albedo_color=Color(.80,.75,.65);stone.albedo_texture=preload("res://assets/nature/materials/rock_boulder_dry_diff_1k.jpg");stone.normal_enabled=true;stone.normal_texture=preload("res://assets/nature/materials/rock_boulder_dry_nor_gl_1k.jpg");stone.normal_scale=.3;stone.uv1_triplanar=true;stone.uv1_world_triplanar=true;stone.uv1_scale=Vector3.ONE*.7;stone.roughness=.96
 var aged:Material=stone
 var timber:=StandardMaterial3D.new();timber.albedo_color=Color(.8,.72,.61);timber.albedo_texture=preload("res://assets/architecture/materials/dark_wood_Diffuse.jpg");timber.uv1_triplanar=true;timber.uv1_world_triplanar=true;timber.roughness=.95
 var linen:Material=builder.material(Color(.48,.42,.31))
 var iron:Material=builder.material(Color(.14,.13,.11))
 var earth:=StandardMaterial3D.new();earth.albedo_color=Color(.76,.72,.56);earth.albedo_texture=preload("res://assets/nature/materials/brown_mud_dry_diff_1k.jpg");earth.normal_enabled=true;earth.normal_texture=preload("res://assets/nature/materials/brown_mud_dry_nor_gl_1k.jpg");earth.normal_scale=.35;earth.uv1_triplanar=true;earth.uv1_world_triplanar=true;earth.uv1_scale=Vector3.ONE*.5;earth.roughness=1.0;earth.cull_mode=BaseMaterial3D.CULL_DISABLED
 # Replace the original flat/checkered blockout materials without changing
 # their support and collision. The soil shoulders below meet those surfaces.
 for part in cellar.get_children():
  if not part is Node3D or part.get_child_count()==0:continue
  var mesh:=part.get_child(0) as MeshInstance3D
  if mesh==null:continue
  var label:=str(part.name)
  if label.begins_with("EarthBank") or label.begins_with("EarthenCap"):mesh.material_override=earth
  elif label.begins_with("CellarFloor") or label.begins_with("UpperTerrace") or label.begins_with("TerraceApproach") or label.begins_with("DescendingPassage"):mesh.material_override=earth
  elif label.begins_with("CellarWall") or label.begins_with("RearWall") or label.begins_with("EntrancePier") or label.begins_with("PassageWall") or label.begins_with("CellarRoof"):mesh.material_override=stone
 # Sloped earth shoulders blend the buried chamber into the surrounding hill.
 # Real solid surfaces are outside the entry corridor and shared follow path.
 for side in [-1.0,1.0]:
  var outer_back:=Vector3(side*15.2,0,-7.3);outer_back.y=terrain_y(cellar,outer_back)
  var outer_front:=Vector3(side*15.2,0,7.3);outer_front.y=terrain_y(cellar,outer_front)
  var inner_back:=Vector3(side*10.8,0,-7.3);inner_back.y=terrain_y(cellar,inner_back)
  var inner_front:=Vector3(side*10.8,0,7.3);inner_front.y=terrain_y(cellar,inner_front)
  var points:=PackedVector3Array([Vector3(side*10.8,3.7,-7.3),outer_back,Vector3(side*10.8,3.7,7.3),outer_front,inner_back,inner_front])
  var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  for index in [0,1,2,1,3,2,0,4,1,2,3,5]:surface.add_vertex(points[index])
  surface.generate_normals();var slope:=surface.commit();slope.surface_set_material(0,earth)
  var bank:=StaticBody3D.new();bank.name="EarthenShoulder";root.add_child(bank)
  var bank_visual:=MeshInstance3D.new();bank_visual.mesh=slope;bank.add_child(bank_visual)
  var bank_shape:=CollisionShape3D.new();bank_shape.shape=slope.create_trimesh_shape();bank.add_child(bank_shape)
 # Scattered weathered stones break the roof's rectangular silhouette.
 var rock_mesh:=preload("res://world/ruined_fort/fort_modules.gd").fractured_rock()
 for i in 12:
  var rock:=MeshInstance3D.new();rock.name="WeatheredRoofStone";rock.mesh=rock_mesh;rock.material_override=stone
  rock.position=Vector3(-9.0+float(i%6)*3.6,4.10,-5.4+float(i/6)*10.0)
  rock.scale=Vector3(.9+float(i%3)*.25,.35,.7+float(i%2)*.25);rock.rotation.y=float(i)*.77;root.add_child(rock)
 # Small native shrubs and grasses weather the buried roof without adding
 # collision or covering the descent. Shared vegetation assets keep the hideout
 # visually tied to the surrounding fort hillside.
 var grass_scene:PackedScene=preload("res://environment/forest/assets/short_grass_lod1.glb")
 var shrub_scene:PackedScene=preload("res://environment/forest/assets/shrub_lod1.glb")
 for i in 18:
  var plant:Node3D=(shrub_scene if i%5==0 else grass_scene).instantiate();plant.name="RoofVegetation";root.add_child(plant)
  plant.position=Vector3(-8.0+float(i%6)*3.15,4.02,-5.2+float(i/6)*4.8)
  plant.rotation.y=float(i)*1.7;plant.scale=Vector3.ONE*(.55 if i%5==0 else .8)
  for geometry in plant.find_children("*","GeometryInstance3D",true,false):geometry.visibility_range_end=95;geometry.visibility_range_end_margin=12
 # Weathered dressed masonry frames a low, unmarked entrance. The actual
 # structural walls and ramp remain the authoritative collision surfaces.
 for side in [-1.0,1.0]:
  builder.piece(root,"EntranceDressedJamb",Vector3(side*2.02,1.65,7.25),Vector3(.4,3.3,.42),aged,false)
  builder.piece(root,"PassageCap",Vector3(side*1.75,4.94,12.5),Vector3(.42,.18,11),aged,false)
  builder.piece(root,"TerraceParapet",Vector3(side*3.65,4.05,21),Vector3(.35,.7,5.5),stone,true)
  builder.piece(root,"TerraceEndStone",Vector3(side*3.65,4.1,18.25),Vector3(.65,.85,.65),aged,true)
 builder.piece(root,"EntranceLintel",Vector3(0,3.25,7.25),Vector3(4.45,.32,.55),aged,false)
 builder.piece(root,"EntranceThreshold",Vector3(0,.18,7.1),Vector3(3.25,.12,.45),aged,false)
 # Terrain-rooted supports under the raised terrace and approach. They stand
 # at the edges, leaving the original centre-line and descending route open.
 for x in [-3.15,3.15]:
  for z in [19.2,23.0]:
   var bottom:float=terrain_y(cellar,Vector3(x,0,z))
   var top:=3.48
   if top-bottom>.3:builder.piece(root,"TerraceSupport",Vector3(x,(top+bottom)*.5,z),Vector3(.75,top-bottom,.75),stone,true)
 var approach_start:Vector3=cellar.to_local(Vector3(cellar.to_global(Vector3(0,0,34)).x,preload("res://world/suryagarh/landscape_layout.gd").new().height(cellar.to_global(Vector3(0,0,34)).x,cellar.to_global(Vector3(0,0,34)).z)+.06,cellar.to_global(Vector3(0,0,34)).z))
 for x in [-1.75,1.75]:
  for z in [26.0,30.0]:
   var bottom:float=terrain_y(cellar,Vector3(x,0,z))
   var top:float=lerpf(3.7,approach_start.y,clampf((z-24.0)/10.0,0.0,1.0))-.16
   if top-bottom>.3:builder.piece(root,"ApproachSupport",Vector3(x,(top+bottom)*.5,z),Vector3(.55,top-bottom,.55),stone,true)
 # Shallow stone ribs and corbels articulate the low roof without narrowing
 # collision or obscuring the 3 m wide central passage and target line.
 for z in [-5.3,-1.8,1.7,5.2]:
  builder.piece(root,"CeilingCrossBeam",Vector3(0,3.24,z),Vector3(17.5,.24,.28),timber,false)
  for side in [-1.0,1.0]:
   builder.piece(root,"WallCorbel",Vector3(side*8.65,3.0,z),Vector3(.55,.45,.56),aged,false)
   builder.piece(root,"WallPilaster",Vector3(side*8.72,1.65,z),Vector3(.3,3.15,.48),stone,false)
 # Planning corner on the rear-left perimeter; writing and storage stay outside
 # the trainees' positions and the rear target's line of fire.
 var desk:Node3D=builder.piece(root,"PlanningDesk",Vector3(-7.25,.86,-4.75),Vector3(2.2,.14,1.45),timber,true)
 for x in [-.9,.9]:
  for z in [-.54,.54]:builder.piece(desk,"DeskLeg",Vector3(x,-.4,z),Vector3(.12,.8,.12),timber,false)
 builder.piece(root,"PlanningPapers",Vector3(-7.3,.95,-4.7),Vector3(1.0,.025,.7),linen,false).rotation.y=.12
 builder.piece(root,"PlanningBench",Vector3(-7.2,.33,-6.05),Vector3(2.0,.12,.42),timber,true)
 for side in [-1.0,1.0]:
  builder.piece(root,"Bedroll",Vector3(side*7.7,.18,3.6),Vector3(1.25,.18,2.1),linen,true)
  builder.piece(root,"BedrollPillow",Vector3(side*7.7,.22,4.25),Vector3(.85,.10,.42),timber,false)
 # A partially screened rest alcove shelters the left bedroll while leaving
 # an open entry from the room and preserving the follow corridor.
 builder.piece(root,"RestScreenPost",Vector3(-6.75,1.15,4.8),Vector3(.09,2.3,.09),timber,true)
 builder.piece(root,"RestScreenPost",Vector3(-6.75,1.15,2.85),Vector3(.09,2.3,.09),timber,true)
 builder.piece(root,"RestScreenCloth",Vector3(-6.75,1.55,3.83),Vector3(.04,1.0,1.95),linen,false)
 # Shelves, crates and covered supplies line the right wall, keeping the
 # weapons-inspection table and its prompt independently owned and accessible.
 for y in [.65,1.35,2.05]:builder.piece(root,"SupplyShelf",Vector3(8.22,y,-1.0),Vector3(1.35,.12,3.5),timber,true)
 for z in [-2.5,.5]:
  for y in [1.0,1.7]:builder.piece(root,"ShelvedSupply",Vector3(8.22,y,z),Vector3(.75,.5,.65),linen,false)
 for x in [-8.0,8.0]:
  for z in [5.5]:
   builder.piece(root,"SupplyCrate",Vector3(x,.45,z),Vector3(1.15,.9,.95),timber,true)
   for dy in [-.2,.2]:builder.piece(root,"CrateStrap",Vector3(x,.45+dy,z+.485),Vector3(1.1,.055,.03),iron,false)
 # Reuse detailed in-project household meshes, while their existing room
 # perimeter and crate collision still own physical blocking.
 for entry in [
  ["res://assets/props/polyhaven/wine_barrel_01/wine_barrel_01_1k.gltf",Vector3(-8.0,.2,-6.1),.8],
  ["res://assets/props/polyhaven/wicker_basket_01/wicker_basket_01_1k.gltf",Vector3(7.9,.2,-5.7),.8],
  ["res://assets/props/polyhaven/wooden_stool_01/wooden_stool_01_1k.gltf",Vector3(-7.1,.2,-3.4),.8]
 ]:
  var prop:Node3D=load(entry[0]).instantiate();prop.name="HideoutHouseholdProp";root.add_child(prop);prop.position=entry[1];prop.scale=Vector3.ONE*entry[2]
 # Shielded low warm lamps are placed at the walls, not above the central
 # camera or in the training lane.
 for side in [-1.0,1.0]:
  var lamp:=Node3D.new();lamp.name="WallLamp";lamp.position=Vector3(side*8.35,2.35,2.0);root.add_child(lamp)
  builder.piece(lamp,"LampBack",Vector3.ZERO,Vector3(.18,.55,.38),iron,false)
  var glass:=StandardMaterial3D.new();glass.albedo_color=Color(.85,.49,.19);glass.emission_enabled=true;glass.emission=Color(.8,.33,.08);glass.emission_energy_multiplier=.65
  builder.piece(lamp,"LampGlass",Vector3(-side*.16,0,0),Vector3(.16,.28,.24),glass,false)
  var light:=OmniLight3D.new();light.name="WarmLampLight";light.position=Vector3(-side*.28,0,0);light.light_color=Color(1,.65,.33);light.light_energy=.45;light.omni_range=7.0;light.shadow_enabled=false;lamp.add_child(light)
 root.set_meta("hideout_complete_environment",true)

static func terrain_y(cellar:Node3D,local:Vector3) -> float:
 var point:=cellar.to_global(local)
 return preload("res://world/suryagarh/landscape_layout.gd").new().height(point.x,point.z)-cellar.global_position.y-.08
