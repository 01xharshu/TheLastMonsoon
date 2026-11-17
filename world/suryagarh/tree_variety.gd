extends RefCounted
## Shared species meshes over existing grounded slots with terrain-aware wood contacts.
const Ground = preload("res://world/suryagarh/tree_trunk_collision.gd")
const Startup = preload("res://systems/world_startup.gd")
const PALETTE = ["island", "mango", "spreading", "young", "peepal", "banyan", "palm"]
static var meshes:Dictionary={}
static var trunk_profiles:Dictionary={}

static func profile_for(mesh:Mesh) -> Array[Dictionary]:
 var key:=mesh.get_instance_id()
 if not trunk_profiles.has(key):trunk_profiles[key]=Ground.profile(mesh)
 return trunk_profiles[key]

static func mesh_for(kind:String, rebuild:bool=false) -> Mesh:
 if meshes.has(kind) and not rebuild:return meshes[kind]
 if kind in ["peepal","banyan","palm"]:return species_mesh(kind)
 if kind=="mango" and not rebuild and ResourceLoader.exists("res://environment/vegetation/world_palette/mango.res"):
  meshes[kind]=load("res://environment/vegetation/world_palette/mango.res");return meshes[kind]
 var path:String="res://environment/vegetation/mango_tree/mango_tree_01.glb" if kind=="mango" else "res://environment/forest/assets/"+("canopy_broad" if kind=="spreading" else "small_tree")+"_lod1.glb"
 var result:=ArrayMesh.new()
 if kind!="mango":
  var loader=preload("res://environment/forest/scripts/forest_generator.gd").new()
  loader.config=preload("res://environment/forest/scripts/forest_config.gd").new()
  for mesh in loader._scene_meshes(load(path)):
   for surface in mesh.get_surface_count():
    var tool:=SurfaceTool.new();tool.append_from(mesh,surface,Transform3D.IDENTITY);tool.set_material(mesh.surface_get_material(surface));tool.commit(result)
  loader.free();result=with_lods(result);result.resource_name="WorldTree_"+kind;meshes[kind]=result
  return result
 var scene:Node3D=load(path).instantiate()
 for node in scene.find_children("*","MeshInstance3D",true,false):
  var transform:=Transform3D.IDENTITY;var cursor:Node=node
  while cursor!=null:
   if cursor is Node3D:transform=cursor.transform*transform
   if cursor==scene:break
   cursor=cursor.get_parent()
  for surface in node.mesh.get_surface_count():
   var tool:=SurfaceTool.new();tool.append_from(node.mesh,surface,transform)
   tool.set_material(node.get_active_material(surface));tool.commit(result)
 scene.free();result=with_lods(result,true);result.resource_name="WorldTree_"+kind;meshes[kind]=result
 return result

static func with_lods(mesh:ArrayMesh, reduce_base:bool=false) -> ArrayMesh:
 var importer:=ImporterMesh.new()
 for surface in mesh.get_surface_count():importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(surface),[],{},mesh.surface_get_material(surface))
 importer.generate_lods(60.0,25.0,[])
 if not reduce_base:return importer.get_mesh()
 var reduced:=ArrayMesh.new()
 for surface in mesh.get_surface_count():
  var arrays:=importer.get_surface_arrays(surface)
  for lod in importer.get_surface_lod_count(surface):
   var indices:=importer.get_surface_lod_indices(surface,lod)
   arrays[Mesh.ARRAY_INDEX]=indices
   if indices.size()<=18000:break
  if "leaf" in str(mesh.surface_get_material(surface).resource_name).to_lower():arrays=sparse_leaf_cards(arrays)
  var intermediate:=ArrayMesh.new();intermediate.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var compact:=SurfaceTool.new();compact.create_from(intermediate,0);compact.deindex();compact.index();compact.set_material(mesh.surface_get_material(surface));compact.commit(reduced)
  print("TREE MANGO SURFACE ",surface," vertices=",reduced.surface_get_array_len(surface)," indices=",reduced.surface_get_array_index_len(surface))
 return with_lods(reduced)

static func choice(point:Vector3) -> int:
 # Stable spatial identity: unaffected by batching, removal or save/load.
 var key:=absi(int(round(point.x*10))*73856093 ^ int(round(point.z*10))*19349663)
 var roll: int=(key ^ (key>>16) ^ (key>>8))%100
 return 0 if roll<20 else 1 if roll<40 else 2 if roll<55 else 3 if roll<70 else 4 if roll<85 else 5 if roll<91 else 6

static func configure_landscape(landscape:Node3D) -> int:
 if landscape.has_meta("tree_variety_counts"):return 0
 var nature:Node=landscape.get_node_or_null("NatureTiles")
 if nature==null:return 0
 var counts:Dictionary={};var total:=0;var reference:Array=[]
 for batch in nature.find_children("BroadleafTrees*","MultiMeshInstance3D",true,false):
  await Startup.checkpoint(landscape,"Growing varied tree canopies…")
  var source:MultiMesh=batch.multimesh;var original:Mesh=source.mesh
  var record:Dictionary={"batch":batch,"source":source,"visible":batch.visible,"parts":[]}
  var old_profile:=profile_for(original)
  if old_profile.is_empty():continue
  var old_base:Vector3=old_profile[0].centre-Vector3.UP*float(old_profile[0].height)*.5
  var groups:Array=[];var slots:Array=[]
  for kind in PALETTE:groups.append([]);slots.append([])
  var instances:=Ground.instance_transforms(source)
  for index in instances.size():
   var at:Transform3D=instances[index]
   if is_zero_approx(at.basis.determinant()):continue
   var root:Vector3=batch.to_global(at*old_base)
   var species:=choice(root)
   if species==5 and not banyan_site_supported(batch,at,old_base,original):species=4
   groups[species].append(at);slots[species].append(index)
  var parent:Node3D=batch.get_parent()
  var body:Node=parent.get_node_or_null(str(batch.name)+"SolidTrunks")
  if body==null:
   body=StaticBody3D.new();body.name=str(batch.name)+"SolidTrunks";body.set_meta("tree_trunk_geometry",true);parent.add_child(body)
  else:
   for child in body.get_children():body.remove_child(child);child.free()
  var shapes:Dictionary={};var body_count:=0
  for species in PALETTE.size():
   if groups[species].is_empty():continue
   var kind:String=PALETTE[species];var mesh:Mesh=original if species==0 else mesh_for(kind)
   var profile:=profile_for(mesh)
   if profile.is_empty():push_error("Tree has no woody root profile: "+kind);continue
   var base:Vector3=profile[0].centre-Vector3.UP*float(profile[0].height)*.5
   # Keep the original visible root and comparable mature/young heights.
   var ratio:float={"young":.68,"spreading":1.15,"peepal":1.20,"banyan":1.35,"palm":1.60}.get(kind,.95)
   var factor:float=1.0 if species==0 else original.get_aabb().size.y/mesh.get_aabb().size.y*ratio
   var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh
   mm.use_colors=source.use_colors;mm.use_custom_data=source.use_custom_data;mm.instance_count=groups[species].size()
   var solid:Array[Transform3D]=[];var identity:=PackedInt32Array()
   for index in groups[species].size():
    var prior:Transform3D=groups[species][index]
    var at:=Transform3D(prior.basis.scaled(Vector3.ONE*factor),prior.origin)
    at.origin=prior*old_base-at.basis*base
    mm.set_instance_transform(index,at);solid.append(batch.transform*at)
    var slot:int=slots[species][index];identity.append(slot)
    if source.use_colors:mm.set_instance_color(index,source.get_instance_color(slot))
    if source.use_custom_data:mm.set_instance_custom_data(index,source.get_instance_custom_data(slot))
   mm.set_meta("render_source_slots",identity)
   var target:MultiMeshInstance3D=batch if species==0 else batch.duplicate(0)
   if species!=0:parent.add_child(target);target.name=str(batch.name)+"_"+kind
   record.parts.append(target)
   target.multimesh=mm;target.set_meta("tree_variety",kind)
   # Actual terrain support and woody collisions use this variant's geometry.
   var grounded:=await Ground.ground_batch(target,profile)
   append_trunks(body,grounded,profile,shapes);body_count+=grounded.size()
   if mesh.has_meta("prop_roots"):
    var props:Array[Dictionary]=[]
    for root in mesh.get_meta("prop_roots"):props.append(root)
    append_trunks(body,grounded,props,shapes)
   counts[kind]=int(counts.get(kind,0))+mm.instance_count;total+=mm.instance_count
  if groups[0].is_empty():
   var empty:=MultiMesh.new();empty.transform_format=MultiMesh.TRANSFORM_3D;empty.mesh=original;batch.multimesh=empty;batch.hide()
  body.set_meta("tree_count",body_count)
  record.varied=batch.multimesh;record.varied_visible=batch.visible;reference.append(record)
 if OS.get_environment("TLM_TREE_CAPTURE_REFERENCE")=="1":landscape.set_meta("tree_variety_reference",reference)
 landscape.set_meta("tree_variety_counts",counts)
 print("WORLD TREE VARIETY ",landscape.name," ",counts)
 return total

static func append_trunks(body:StaticBody3D,trees:Array[Transform3D],profile:Array[Dictionary],shapes:Dictionary) -> void:
 # One physical owner per original tile, with the actual wood shapes for all kinds.
 for tree in trees:
  var scale:=tree.basis.get_scale()
  for segment in profile:
   var radius:float=segment.radius*maxf(scale.x,scale.z)
   var height:float=segment.height*scale.y+.015
   var key:=Vector2(snappedf(radius,.01),snappedf(height,.01))
   if not shapes.has(key):
    var shape:=CylinderShape3D.new();shape.radius=radius;shape.height=height;shapes[key]=shape
   var collision:=CollisionShape3D.new();collision.shape=shapes[key];collision.position=tree*segment.centre;body.add_child(collision)

static func component_root(parents:PackedInt32Array,index:int) -> int:
 while parents[index]!=index:index=parents[index]
 return index

static func sparse_leaf_cards(arrays:Array) -> Array:
 # Retain whole connected leaves, evenly sampled; enlarge each leaf modestly to
 # preserve crown coverage rather than deleting arbitrary disconnected triangles.
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var parents:=PackedInt32Array();parents.resize(vertices.size())
 for i in parents.size():parents[i]=i
 var used:Dictionary={}
 for i in range(0,indices.size(),3):
  var a:=component_root(parents,indices[i])
  for offset in [1,2]:
   var b:=component_root(parents,indices[i+offset]);parents[b]=a
  for offset in 3:used[indices[i+offset]]=true
 var groups:Dictionary={}
 for index in used:
  var key:=component_root(parents,index)
  if not groups.has(key):groups[key]={"sum":Vector3.ZERO,"count":0,"keep":groups.size()%3==0}
  groups[key].sum+=vertices[index];groups[key].count+=1
 var selected:=PackedInt32Array()
 for i in range(0,indices.size(),3):
  if groups[component_root(parents,indices[i])].keep:selected.append_array(indices.slice(i,i+3))
 for index in used:
  var group:Dictionary=groups[component_root(parents,index)]
  if group.keep:
   var centre:Vector3=group.sum/float(group.count);vertices[index]=centre+(vertices[index]-centre)*1.45
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_INDEX]=selected
 return arrays

static func species_mesh(kind:String) -> Mesh:
 var scene:Node3D=load("res://environment/vegetation/indian_trees/"+kind+"_lod1.glb").instantiate()
 var result:=ArrayMesh.new()
 for node in scene.find_children("*","MeshInstance3D",true,false):
  var transform:=Transform3D.IDENTITY;var cursor:Node=node
  while cursor!=null:
   if cursor is Node3D:transform=cursor.transform*transform
   if cursor==scene:break
   cursor=cursor.get_parent()
  for surface in node.mesh.get_surface_count():
   var material:Material=node.get_active_material(surface)
   if "Leaves" in str(node.name):
    var leaf:=ShaderMaterial.new();leaf.shader=preload("res://environment/forest/shaders/foliage.gdshader")
    leaf.resource_name="Species_Leaves_"+kind
    leaf.set_shader_parameter("tint",{"peepal":Color(.22,.39,.09),"banyan":Color(.12,.28,.07),"palm":Color(.23,.34,.13)}[kind])
    leaf.set_shader_parameter("wind_strength",.10);material=leaf
   elif material is StandardMaterial3D:
    var bark:StandardMaterial3D=material.duplicate();bark.albedo_texture=preload("res://environment/forest/assets/textures/bark_brown_02_diff_2k.jpg")
    bark.normal_enabled=true;bark.normal_texture=preload("res://environment/forest/assets/textures/bark_brown_02_nor_gl_2k.jpg");bark.roughness=.94;material=bark
   var tool:=SurfaceTool.new();tool.append_from(node.mesh,surface,transform);tool.set_material(material);tool.commit(result)
 scene.free();result=with_lods(result);result.resource_name="WorldTree_"+kind
 if kind=="banyan":
  var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://environment/vegetation/indian_trees/species.json"))
  var roots:Array[Dictionary]=[]
  for root in data.banyan.prop_roots:
   roots.append({"centre":Vector3(root.x,(root.top-.55)*.5,-root.y),"radius":root.radius,"height":root.top+.55})
  result.set_meta("prop_roots",roots)
 meshes[kind]=result;return result

static func banyan_site_supported(batch:MultiMeshInstance3D,prior:Transform3D,old_base:Vector3,original:Mesh) -> bool:
 # Prop roots remain on quiet, almost-level ground; steep slopes get Peepal.
 var mesh:=mesh_for("banyan");var profile:=profile_for(mesh)
 var base:Vector3=profile[0].centre-Vector3.UP*float(profile[0].height)*.5
 var factor:float=original.get_aabb().size.y/mesh.get_aabb().size.y*1.35
 var at:=Transform3D(prior.basis.scaled(Vector3.ONE*factor),Vector3.ZERO);at.origin=prior*old_base-at.basis*base
 var space:=batch.get_world_3d().direct_space_state
 for prop in mesh.get_meta("prop_roots"):
  var foot:Vector3=batch.to_global(at*(prop.centre-Vector3.UP*float(prop.height)*.5))
  var query:=PhysicsRayQueryParameters3D.create(foot+Vector3.UP*5,foot-Vector3.UP*5,Ground.TERRAIN_SUPPORT_LAYER)
  var support:=space.intersect_ray(query)
  if support.is_empty() or foot.y>support.position.y+.005 or foot.y<support.position.y-.30:return false
 return true
