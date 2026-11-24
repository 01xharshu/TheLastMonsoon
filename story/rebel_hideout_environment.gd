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
 # Sample the hillside under the outer shoulder along its entire length.
 var layout:=preload("res://world/suryagarh/landscape_layout.gd").new()
 for side in [-1.0,1.0]:
  build_earthen_shoulder(root,cellar,layout,earth,side)
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
 build_terrace_masonry(builder,root,cellar,stone)
 build_entrance_facing(root,cellar,stone)
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

static func build_earthen_shoulder(root:Node3D,cellar:Node3D,layout:RefCounted,earth:Material,side:float) -> void:
 var points:=PackedVector3Array()
 const WIDTH_STEPS:=8
 const LENGTH_STEPS:=16
 for row in LENGTH_STEPS+1:
  var z:=lerpf(-7.3,7.3,float(row)/LENGTH_STEPS)
  for column in WIDTH_STEPS+1:
   var across:=float(column)/WIDTH_STEPS
   var x:=side*lerpf(10.8,15.2,across)
   var world:=cellar.to_global(Vector3(x,0,z))
   var terrain:float=layout.height(world.x,world.z)-cellar.global_position.y-.08
   points.append(Vector3(x,lerpf(3.7,terrain,smoothstep(0.0,1.0,across)),z))
 var surface:=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in LENGTH_STEPS:
  for column in WIDTH_STEPS:
   var first:=row*(WIDTH_STEPS+1)+column
   var next:=first+WIDTH_STEPS+1
   var winding: Array[int]=[first,first+1,next+1,first,next+1,next]
   if side<0.0:winding.reverse()
   for index in winding:surface.add_vertex(points[index])
 surface.generate_normals()
 var slope:=surface.commit()
 slope.surface_set_material(0,earth)
 var bank:=StaticBody3D.new()
 bank.name="EarthenShoulder"
 root.add_child(bank,true)
 var visual:=MeshInstance3D.new()
 visual.mesh=slope
 bank.add_child(visual)
 var collision:=CollisionShape3D.new()
 collision.shape=slope.create_trimesh_shape()
 bank.add_child(collision)

static func build_terrace_masonry(builder:Node,root:Node3D,cellar:Node3D,material:Material) -> void:
 var stones:=MultiMesh.new()
 stones.transform_format=MultiMesh.TRANSFORM_3D
 stones.mesh=preload("res://world/ruined_fort/fort_modules.gd").chipped_stone(1857)
 var transforms:Array[Transform3D]=[]
 for side in [-1.0,1.0]:
  for section in 7:
   var z:=18.45+section*.82
   var courses:=3 if section in [0,1,5] else (1 if section==3 else 2)
   var height:=courses*.34
   var x:float=side*3.65
   var wall:Node3D=builder.piece(root,"BrokenTerraceParapet",Vector3(x,3.70+height*.5,z),Vector3(.46,height,.81),material,true)
   wall.get_child(0).hide()
   for course in courses:
    var yaw:=.12*sin(float(section*3+course)*1.7)
    var at:=Vector3(x+.04*sin(float(course+section)),3.70+(course+.5)*.34,z)
    transforms.append(Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3(.53,.36,.88)),at))
 # Low and high remnants of the former curtain stand outside the approach.
 for side in [-1.0,1.0]:
  for section in 4:
   var x:float=side*(3.5+section*.92)
   var z:float=27.0+section*.13
   var base:=terrain_y(cellar,Vector3(x,0,z))
   var courses:int=[2,4,3,1][section]
   var height:=courses*.43
   var wall:Node3D=builder.piece(root,"BreachedCurtainRemnant",Vector3(x,base+height*.5,z),Vector3(.91,height,.78),material,true)
   wall.get_child(0).hide()
   for course in courses:
    var at:=Vector3(x,base+(course+.5)*.43,z+.045*sin(float(course+section)))
    transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(.97,.46,.87)),at))
 stones.instance_count=transforms.size()
 for index in transforms.size():stones.set_instance_transform(index,transforms[index])
 var facing:=MultiMeshInstance3D.new()
 facing.name="WeatheredTerraceMasonry"
 facing.multimesh=stones
 facing.material_override=material
 facing.visibility_range_end=140.0
 root.add_child(facing)

static func build_entrance_facing(root:Node3D,cellar:Node3D,material:Material) -> void:
 var transforms:Array[Transform3D]=[]
 for wall in cellar.get_children():
  var label:=str(wall.name)
  if not (label.begins_with("EntrancePier") or label.begins_with("PassageWall")):continue
  var panel:=wall.get_child(0) as MeshInstance3D
  if panel==null or not panel.mesh is BoxMesh:continue
  var size:Vector3=panel.mesh.size
  var along_x:=size.x>size.z
  var length:=size.x if along_x else size.z
  var columns:=ceili(length/.8)
  var rows:=ceili(size.y/.4)
  var width:=length/columns
  var height:=size.y/rows
  for row in rows:
   for column in columns:
    var offset:=(column+.5)*width-length*.5
    var elevation:=(row+.5)*height-size.y*.5
    var local:=Vector3(offset,elevation,0) if along_x else Vector3(0,elevation,offset)
    var extent:=Vector3(width*1.02,height*1.02,size.z) if along_x else Vector3(size.x,height*1.02,width*1.02)
    transforms.append(Transform3D(Basis.IDENTITY.scaled(extent),wall.position+local))
  panel.hide()
 var masonry:=MultiMesh.new()
 masonry.transform_format=MultiMesh.TRANSFORM_3D
 masonry.mesh=preload("res://world/ruined_fort/fort_modules.gd").chipped_stone(1857)
 masonry.instance_count=transforms.size()
 for index in transforms.size():masonry.set_instance_transform(index,transforms[index])
 var facing:=MultiMeshInstance3D.new()
 facing.name="WeatheredEntranceMasonry"
 facing.multimesh=masonry
 facing.material_override=material
 root.add_child(facing)

static func terrain_y(cellar:Node3D,local:Vector3) -> float:
 var point:=cellar.to_global(local)
 return preload("res://world/suryagarh/landscape_layout.gd").new().height(point.x,point.z)-cellar.global_position.y-.08
