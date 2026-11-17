extends Node3D
## Dedicated remote highland corridor on the existing authoritative landscape.
## Static chunked scenery; no autonomous NPCs or per-frame region callbacks.
signal built
const Layout=preload("res://world/suryagarh/landscape_layout.gd")
const Survey=preload("res://world/suryagarh/remote_mountain_route.gd")
const Terrain=preload("res://world/suryagarh/tree_trunk_collision.gd")
const LANDMARKS={"Mountain trailhead":Vector2(460,-250),"High ridge lookout":Vector2(570,-440),"Remote mountain pass":Vector2(800,-650),"Northeastern summit":Vector2(1000,-700),"Northern mountain refuge":Vector2(960,-930)}
var layout:=Layout.new()
var route: Array[Vector3]=[]
var trail_material: Material
var stone: StandardMaterial3D
var timber: StandardMaterial3D
var ready_for_exploration:=false
var clearance_image: Image
var clearance_texture: ImageTexture
var clearance_rect:=Rect2()
var verge_roots: Array[Vector3]=[]
var refuge_site:=Vector3.ZERO
func _ready()->void:
 name="RemoteMountains"
 Terrain.configure_terrain_support(get_parent())
 await get_tree().physics_frame
 var trail:=ShaderMaterial.new();trail.shader=load("res://world/suryagarh/shaders/mountain_trail.gdshader");trail.set_shader_parameter("grain",load("res://environment/forest/assets/textures/rock_albedo.jpg"));trail_material=trail
 stone=material(Color(.67,.63,.54))
 stone.albedo_texture=load("res://environment/forest/assets/textures/rock_albedo.jpg")
 stone.uv1_triplanar=true;stone.uv1_world_triplanar=true;stone.uv1_scale=Vector3.ONE*.35
 timber=material(Color(.85,.74,.58))
 timber.albedo_texture=load("res://assets/architecture/materials/dark_wood_Diffuse.jpg")
 timber.uv1_triplanar=true;timber.uv1_world_triplanar=true;timber.uv1_scale=Vector3.ONE*.7
 for i in Survey.POINTS.size()-1:
  var a:Vector2=Survey.POINTS[i];var b:Vector2=Survey.POINTS[i+1]
  var count:=maxi(1,ceili(a.distance_to(b)/2.0))
  for j in count:
   var p:Vector2=a.lerp(b,float(j)/count)
   route.append(surface(p))
 route.append(surface(Survey.POINTS[-1]))
 var refuge:=find_refuge(LANDMARKS["Northern mountain refuge"]);refuge_site=refuge
 for stop:Vector3 in [refuge+Vector3(0,0,-10),refuge+Vector3(0,0,-8)]:
  var spur_start:Vector3=route[-1]
  var spur_steps:=maxi(1,ceili(Vector2(stop.x-spur_start.x,stop.z-spur_start.z).length()/2.0))
  for i in range(1,spur_steps+1):
   var p:Vector3=spur_start.lerp(stop,float(i)/spur_steps);route.append(surface(Vector2(p.x,p.z)))
 build_trail()
 for label: String in LANDMARKS:
  var marker:=Marker3D.new();marker.name=label.replace(" ","");marker.position=refuge if label=="Northern mountain refuge" else surface(LANDMARKS[label]);marker.set_meta("parking_label",label);add_child(marker)
  if label!="Northern mountain refuge":
   for offset:Vector3 in [Vector3(-4,0,-5),Vector3(4,0,5),Vector3(-5,0,4)]:
    var at:Vector3=marker.position+offset
    if public_clearance(Vector2(at.x,at.z))>5:build_cairn(at);break
 build_refuge(refuge)
 build_rocks()
 build_verge_grass()
 apply_walk_clearance()
 ready_for_exploration=true
 print("REMOTE MOUNTAINS READY | ",route.size()," terrain-rooted trail samples | five landmarks")
 built.emit()
func material(color:Color)->StandardMaterial3D:
 var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=1.0;return m
func surface(p:Vector2)->Vector3:
 var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,350,p.y),Vector3(p.x,-30,p.y),Terrain.TERRAIN_SUPPORT_LAYER)
 var hit:=get_world_3d().direct_space_state.intersect_ray(query)
 return hit.position if not hit.is_empty() else Vector3(p.x,layout.height(p.x,p.y),p.y)
func build_trail()->void:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var vertices:=0
 for i in route.size()-1:
  var a:=route[i];var b:=route[i+1];var forward:Vector3=(b-a).normalized();var side:=Vector3(forward.z,0,-forward.x).normalized()*1.35
  var corners: Array[Vector3]=[]
  for p:Vector3 in [a-side,a+side,b-side,b+side]:corners.append(surface(Vector2(p.x,p.z))+Vector3.UP*.07)
  for index in [0,2,1,1,2,3]:st.set_uv(Vector2(0.0 if index in [0,2] else 1.0,float(i)));st.add_vertex(corners[index]);vertices+=1
  if vertices>=384 or i==route.size()-2:
   st.generate_normals();var mesh:=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=trail_material;mesh.visibility_range_end=550;mesh.visibility_range_end_margin=60;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(mesh)
   st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);vertices=0
func box_part(label:String,at:Vector3,size:Vector3,mat:Material,solid:=true)->void:
 var mesh:=MeshInstance3D.new();mesh.name=label;var shape:=BoxMesh.new();shape.size=size;mesh.mesh=shape;mesh.material_override=mat;mesh.position=at;mesh.visibility_range_end=600;mesh.visibility_range_end_margin=60;add_child(mesh)
 if solid:
  var body:=StaticBody3D.new();body.position=at;add_child(body)
  var collision:=CollisionShape3D.new();var form:=BoxShape3D.new();form.size=size;collision.shape=form;body.add_child(collision)
func build_cairn(at:Vector3)->void:
 at=surface(Vector2(at.x,at.z))
 for tier in 4:
  var width:=.7-float(tier)*.12
  box_part("TrailCairn",at+Vector3(0,.12+float(tier)*.2,0),Vector3(width,.22,width),stone)
func find_refuge(near:Vector2)->Vector3:
 var shape:=BoxShape3D.new();shape.size=Vector3(6,3.5,5)
 for dz in [0,-8,8,-16,16,-24,24,-32,32]:
  for dx in [8,-8,16,-16,0,24,-24,32,-32]:
   var p:=surface(near+Vector2(dx,dz));var lowest:=p.y;var highest:=p.y
   for corner:Vector2 in [Vector2(-2.5,-2),Vector2(2.5,-2),Vector2(-2.5,2),Vector2(2.5,2)]:
    var h:float=surface(Vector2(p.x,p.z)+corner).y;lowest=minf(lowest,h);highest=maxf(highest,h)
   if highest-lowest>2.0:continue
   var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=Vector3(p.x,highest+1.85,p.z);query.collision_mask=1;query.exclude=Terrain.terrain_exclusions(get_parent())
   if not get_world_3d().direct_space_state.intersect_shape(query,4).is_empty():continue
   var clear:=true;var from:Vector3=route[-1];var entrance:=p+Vector3(0,0,-8)
   var steps:=maxi(1,ceili(from.distance_to(entrance)/2))
   var capsule:=CapsuleShape3D.new();capsule.radius=.7;capsule.height=2.4
   for step in steps+1:
    var sample:Vector3=from.lerp(entrance,float(step)/steps);sample=surface(Vector2(sample.x,sample.z))
    query.shape=capsule;query.transform.origin=sample+Vector3.UP*1.5
    if not get_world_3d().direct_space_state.intersect_shape(query,4).is_empty():clear=false;break
   if clear:return Vector3(p.x,highest,p.z)
 push_error("REMOTE MOUNTAINS: no clear supported refuge plot")
 return surface(near)
func build_refuge(at:Vector3)->void:
 # Open entrance and roofed standing space, not a sealed decorative building.
 var base:=at;
 base.y+=.12
 box_part("RefugeFloor",base-Vector3.UP*1.08,Vector3(5,2.4,4),stone)
 var ramp:=SurfaceTool.new();ramp.begin(Mesh.PRIMITIVE_TRIANGLES)
 var points: Array[Vector3]=[]
 for x in [-1.0,1.0]:points.append(surface(Vector2(base.x+x,base.z-8))+Vector3.UP*.05)
 for x in [-1.0,1.0]:points.append(base+Vector3(x,.12,-2))
 for index in [0,1,2,1,3,2]:ramp.add_vertex(points[index])
 ramp.generate_normals();var deck:=MeshInstance3D.new();deck.mesh=ramp.commit();deck.material_override=stone;deck.visibility_range_end=600;add_child(deck);deck.create_trimesh_collision()
 # Close-set rough timber treads cover the retained continuous ramp support.
 for tread in 25:
  var t:float=(float(tread)+.5)/25.0
  var left:Vector3=points[0].lerp(points[2],t)+Vector3.UP*.045
  var right:Vector3=points[1].lerp(points[3],t)+Vector3.UP*.045
  beam_between("RampTimberTread",left,right,Vector2(.075,.26),timber,false)
 for plank in 16:
  var x:float=-2.34+float(plank)*.31
  box_part("RefugeTimberFloor",base+Vector3(x,.15,0),Vector3(.3,.055,3.95),timber,false)
 for x in [-2.2,2.2]:
  for z in [-1.7,1.7]:box_part("RefugePost",base+Vector3(x,1.5,z),Vector3(.18,3,.18),timber)
 box_part("StoneRearWall",base+Vector3(0,.8,1.8),Vector3(4.8,1.6,.35),stone)
 box_part("StoneSideWall",base+Vector3(-2.3,.6,0),Vector3(.35,1.2,3.7),stone)
 # Split-timber overlapping roof boards on a pitched local timber frame.
 for z in [-1.7,1.7]:
  beam_between("RoofTie",base+Vector3(-2.3,2.9,z),base+Vector3(2.3,2.9,z),Vector2(.16,.18),timber)
  for side in [-1.0,1.0]:beam_between("PitchedRafter",base+Vector3(side*2.75,3.0,z),base+Vector3(0,4.25,z),Vector2(.15,.18),timber)
 for strip in 19:
  var z:float=-2.35+float(strip)*.26
  for side in [-1.0,1.0]:beam_between("SplitTimberRoofBoard",base+Vector3(side*2.85,3.05,z),base+Vector3(0,4.32,z),Vector2(.29,.11),timber)
 beam_between("RoofRidgeCap",base+Vector3(0,4.4,-2.55),base+Vector3(0,4.4,2.55),Vector2(.22,.18),timber)
 # Uneven stone courses break the cast-slab silhouette of the raised plinth.
 for course in 4:
  for block in 6:
   var x:float=-2.15+float(block)*.84+(.12 if course%2 else 0.0)
   box_part("RoughStoneCourse",base+Vector3(x,-.25-float(course)*.53,-2.04),Vector3(.77,.48,.19),stone,false)
 box_part("RestingBench",base+Vector3(0,.5,1.1),Vector3(2.4,.18,.5),timber)
 for x in [-.94,.94]:
  box_part("BenchTrestle",base+Vector3(x,.295,1.1),Vector3(.11,.24,.38),timber,false)
 var vessels:=preload("res://world/suryagarh/settlements/period_vessels.gd").new()
 vessels.place(self,"matka",base+Vector3(-1.55,.18,1.12),1.25,true)
 vessels.place(self,"lota",base+Vector3(-.85,.59,1.1))
 vessels.place(self,"dish",base+Vector3(-.48,.59,1.1),.85,true)
func build_rocks()->void:
 var source: Node3D=load("res://environment/forest/assets/rock_reused.glb").instantiate()
 var meshes:=source.find_children("*","MeshInstance3D",true,false)
 if meshes.is_empty():source.free();return
 var shared: Mesh=meshes[0].mesh
 var rock_collision: ConcavePolygonShape3D = shared.create_trimesh_shape()
 # A remote crag chain rises out of the retained eastern ridge. The reused
 # rock geometry remains buried into the terrain and has solid collision.
 var crag_sites: Array[Vector2]=[Vector2(850,-750),Vector2(870,-825),Vector2(860,-900),Vector2(800,-850),Vector2(780,-950),Vector2(710,-890)]
 for i in crag_sites.size():
  var p:Vector2=crag_sites[i]
  if public_clearance(p)<65:continue
  var crag:=MeshInstance3D.new();crag.mesh=shared
  crag.position=surface(p)-Vector3.UP*6
  crag.scale=Vector3(23+float(i%2)*7,30+float(i%3)*8,26)
  crag.rotation.y=float(i)*1.31;crag.visibility_range_end=1000;crag.visibility_range_end_margin=100
  add_child(crag);attach_rock_collision(crag,rock_collision)
 for i in 28:
  var p:=Vector2(700+float(i%7)*56,-530-float(i/7)*100)
  var clearance:=INF
  for point in route:clearance=minf(clearance,Vector2(point.x,point.z).distance_to(p))
  if clearance<12 or public_clearance(p)<15:continue
  var scale:=Vector3(3.0+float(i%3)*1.4,4.0+float(i%4)*1.5,3.0+float(i%2)*2)
  var mesh:=MeshInstance3D.new();mesh.mesh=shared;mesh.position=surface(p)-Vector3.UP;mesh.scale=scale;mesh.rotation.y=float(i)*1.71;mesh.visibility_range_end=650;mesh.visibility_range_end_margin=70;add_child(mesh)
  attach_rock_collision(mesh,rock_collision)
 source.free()

# All instances use the same imported rock mesh. Keep their independent
# transforms and solid bodies, but share the exact triangle collision resource.
static func attach_rock_collision(rock: MeshInstance3D, shape: ConcavePolygonShape3D) -> void:
 var body := StaticBody3D.new()
 body.name = "RockCollision"
 var collision := CollisionShape3D.new()
 collision.shape = shape
 body.add_child(collision)
 rock.add_child(body)

func public_clearance(at:Vector2)->float:
 var nearest:=INF
 for points:Array in Layout.ROUTES.values():
  for i in points.size()-1:nearest=minf(nearest,layout.segment_distance(at,points[i],points[i+1]))
 return nearest

func beam_between(label:String,a:Vector3,b:Vector3,cross_section:Vector2,mat:Material,solid:bool=true)->void:
 var mesh:=MeshInstance3D.new();mesh.name=label;mesh.set_meta("period_roof_board",label=="SplitTimberRoofBoard")
 var form:=BoxMesh.new();form.size=Vector3(cross_section.x,cross_section.y,a.distance_to(b));mesh.mesh=form;mesh.material_override=mat
 mesh.position=(a+b)*.5;add_child(mesh);mesh.look_at(b,Vector3.UP)
 mesh.visibility_range_end=600;mesh.visibility_range_end_margin=60
 if not solid:return
 var body:=StaticBody3D.new();body.transform=mesh.transform;add_child(body)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=form.size;shape.shape=box;body.add_child(shape)

func build_verge_grass()->void:
 var rng:=RandomNumberGenerator.new();rng.seed=185718
 var tiles:Dictionary={}
 var grass:=preload("res://world/suryagarh/grass_blades.gd").make_mesh()
 for i in range(0,route.size()-1,3):
  var forward:Vector3=route[mini(i+1,route.size()-1)]-route[i]
  var side:=Vector3(forward.z,0,-forward.x).normalized()
  for clump in 18:
   if rng.randf()<.24:continue
   var sign_side:=1.0 if clump%2 else -1.0
   var p:Vector3=route[i]+side*sign_side*rng.randf_range(2.0,7.0)+forward.normalized()*rng.randf_range(-2.5,2.5)
   if Vector2(p.x-refuge_site.x,p.z-refuge_site.z).length()<10 or public_clearance(Vector2(p.x,p.z))<5:continue
   var at:=surface(Vector2(p.x,p.z));verge_roots.append(at)
   var key:=Vector2i(floori(at.x/80),floori(at.z/80))
   if not tiles.has(key):tiles[key]=[]
   var transform:=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(rng.randf_range(1.2,2.0),rng.randf_range(3.0,5.0),rng.randf_range(1.2,2.0))),at)
   tiles[key].append(transform)
 for key in tiles:
  var batch:=MultiMeshInstance3D.new();batch.name="GrassMountainVerge";var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=grass;mm.instance_count=tiles[key].size()
  for i in mm.instance_count:mm.set_instance_transform(i,tiles[key][i])
  batch.multimesh=mm;batch.visibility_range_end=75;batch.visibility_range_end_margin=12;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(batch)

func apply_walk_clearance()->void:
 var walk_line:Array[Vector3]=route.duplicate()
 walk_line.append(refuge_site+Vector3(0,0,-2));walk_line.append(refuge_site)
 var lower:=Vector2.INF;var upper:=Vector2(-INF,-INF)
 for point in walk_line:
  var p:=Vector2(point.x,point.z);lower=lower.min(p);upper=upper.max(p)
 clearance_rect=Rect2(lower-Vector2.ONE*10,upper-lower+Vector2.ONE*20)
 clearance_image=Image.create(1024,1024,false,Image.FORMAT_R8);clearance_image.fill(Color.BLACK)
 var pixel:Vector2=clearance_rect.size/1024.0
 for i in walk_line.size()-1:
  var a:=Vector2(walk_line[i].x,walk_line[i].z);var b:=Vector2(walk_line[i+1].x,walk_line[i+1].z);var ab:=b-a
  var lo:Vector2i=Vector2i((a.min(b)-Vector2.ONE*2-clearance_rect.position)/pixel)
  var hi:Vector2i=Vector2i((a.max(b)+Vector2.ONE*2-clearance_rect.position)/pixel)
  for y in range(maxi(0,lo.y),mini(1023,hi.y)+1):
   for x in range(maxi(0,lo.x),mini(1023,hi.x)+1):
    var p:=clearance_rect.position+(Vector2(x,y)+Vector2.ONE*.5)*pixel
    var t:=clampf((p-a).dot(ab)/maxf(.0001,ab.length_squared()),0,1)
    var distance:=p.distance_to(a+ab*t)
    var value:=1.0-smoothstep(1.1,1.7,distance)
    if value>clearance_image.get_pixel(x,y).r:clearance_image.set_pixel(x,y,Color(value,0,0))
 clearance_texture=ImageTexture.create_from_image(clearance_image)
 var copies:Dictionary={}
 for batch:MultiMeshInstance3D in get_parent().find_children("Grass*","MultiMeshInstance3D",true,false):
  var bounds:AABB=batch.global_transform*batch.get_aabb()
  if not clearance_rect.intersects(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))):continue
  var source:Material=batch.material_override
  if source==null:source=batch.multimesh.mesh.surface_get_material(0)
  if not source is ShaderMaterial or source.shader.resource_path!="res://world/suryagarh/shaders/grass_blades.gdshader":continue
  if not copies.has(source):
   var copy:ShaderMaterial=source.duplicate()
   copy.set_shader_parameter("worn_path_enabled",true);copy.set_shader_parameter("worn_path_mask",clearance_texture)
   copy.set_shader_parameter("worn_path_rect",Vector4(clearance_rect.position.x,clearance_rect.position.y,clearance_rect.size.x,clearance_rect.size.y))
   copies[source]=copy
  # Node-scoped material overrides preserve shared mesh/instance buffers and LOD.
  batch.material_override=copies[source]
