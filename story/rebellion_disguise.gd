extends RefCounted
## Fit donor garments to original MPFB rig; body meshes and physique are preserved.
var additions: Array[Node3D]=[]
var originals: Array[GeometryInstance3D]=[]
var original_visible: Array[bool]=[]
var worn=false
var body_grids: Dictionary={}
func mesh_label(node: MeshInstance3D) -> String:
 return (str(node.name)+" "+node.mesh.resource_name).to_lower()
func is_uniform(label: String) -> bool:
 return "casualsuit" in label or "shoes04" in label or "crossbelt" in label or "cap" in label or "tunic button" in label
func copy_garment(node: MeshInstance3D,donor: Skeleton3D,rig: Skeleton3D,label: String) -> MeshInstance3D:
 var skin=Skin.new()
 for i in node.skin.get_bind_count():
  var bone=node.skin.get_bind_bone(i)
  var bone_name=str(node.skin.get_bind_name(i))
  if bone_name.is_empty() and bone>=0:bone_name=donor.get_bone_name(bone)
  var index=rig.find_bone(bone_name)
  while index<0:
   var source_index=donor.find_bone(bone_name)
   if source_index<0:return null
   var parent=donor.get_bone_parent(source_index)
   if parent<0:return null
   bone_name=donor.get_bone_name(parent);index=rig.find_bone(bone_name)
  skin.add_bind(index,rig.get_bone_global_rest(index).affine_inverse())
 var grid: Dictionary=body_grid(rig)
 var mesh=ArrayMesh.new()
 for surface in node.mesh.get_surface_count():
  var arrays: Array=node.mesh.surface_get_arrays(surface)
  var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  var indices: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
  var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
  var stride=int(indices.size()/vertices.size())
  for vertex in vertices.size():
   var at=Vector3.ZERO;var normal=Vector3.ZERO
   for influence in stride:
    var bind=indices[vertex*stride+influence];var weight=weights[vertex*stride+influence]
    if weight<=0:continue
    var correction=rig.get_bone_global_rest(skin.get_bind_bone(bind))*node.skin.get_bind_pose(bind)
    at+=(correction*vertices[vertex])*weight
    normal+=(correction.basis.inverse().transposed()*normals[vertex])*weight
   normal=normal.normalized()
   vertices[vertex]=fit_outside_body(at,normal,grid);normals[vertex]=normal
  arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
  # Recompute tangent frames after rest-space fitting.
  arrays[Mesh.ARRAY_TANGENT]=null
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  mesh.surface_set_material(surface,node.get_active_material(surface))
 var clothing=MeshInstance3D.new();clothing.name=label;clothing.mesh=mesh;clothing.skin=skin;clothing.set_meta("source_garment",mesh_label(node));rig.add_child(clothing);clothing.skeleton=clothing.get_path_to(rig)
 return clothing
func wear(visual: Node3D,guard: Node3D) -> bool:
 if worn:return true
 var rig: Skeleton3D=visual.skeleton
 var donor: Skeleton3D=guard._skeleton
 if not prepare_stripped_guard(visual,guard):return false
 for node in guard.find_children("*","MeshInstance3D",true,false):
  if node.skin==null or node.mesh==null or not is_uniform(mesh_label(node)):continue
  var fitted=copy_garment(node,donor,rig,"CapturedUniform")
  if fitted==null:remove();return false
  additions.append(fitted)
 if additions.is_empty():return false
 for node in visual.find_children("*","MeshInstance3D",true,false):
  if node in additions or node.mesh==null:continue
  var label=mesh_label(node)
  if "makehuman_body" in label or "arjun_base_001" in label or "foundation" in label or "short02" in label or "high-poly" in label or "eyebrow" in label:continue
  if node.skin==null and not ("boot" in label or "sash" in label or "kurta" in label):continue
  originals.append(node);original_visible.append(node.visible);node.hide()
 add_lungi(guard)
 for node in guard.find_children("*","MeshInstance3D",true,false):
  if node.mesh!=null and is_uniform(mesh_label(node)):node.hide()
 worn=true;return true
func remove() -> void:
 for i in originals.size():
  if is_instance_valid(originals[i]):originals[i].visible=original_visible[i]
 for node in additions:
  if is_instance_valid(node):node.queue_free()
 additions.clear();originals.clear();original_visible.clear();worn=false

func body_grid(rig: Skeleton3D) -> Dictionary:
 if body_grids.has(rig):return body_grids[rig]
 var grid: Dictionary={}
 for node in rig.get_parent().get_parent().find_children("*","MeshInstance3D",true,false):
  if node.skin==null or node.mesh==null:continue
  var label=mesh_label(node)
  if not ("makehuman_body" in label or "arjun_base_001" in label or "private_man_base" in label or "foundation" in label):continue
  for surface in node.mesh.get_surface_count():
   var arrays: Array=node.mesh.surface_get_arrays(surface)
   var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
   var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
   var source_normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
   var stride=int(bones.size()/vertices.size())
   for i in vertices.size():
    var at=Vector3.ZERO;var surface_normal=Vector3.ZERO
    for j in stride:
     var slot=bones[i*stride+j];var weight=weights[i*stride+j]
     if weight<=0:continue
     var index=node.skin.get_bind_bone(slot)
     if index<0:index=rig.find_bone(node.skin.get_bind_name(slot))
     var frame=rig.get_bone_global_rest(index)*node.skin.get_bind_pose(slot)
     at+=(frame*vertices[i])*weight
     surface_normal+=(frame.basis.inverse().transposed()*source_normals[i])*weight
    var key=Vector3i(floori(at.x/.08),floori(at.y/.08),floori(at.z/.08))
    if not grid.has(key):grid[key]=[]
    grid[key].append([at,surface_normal.normalized()])
 body_grids[rig]=grid;return grid
func fit_outside_body(at: Vector3,normal: Vector3,grid: Dictionary) -> Vector3:
 var key=Vector3i(floori(at.x/.08),floori(at.y/.08),floori(at.z/.08))
 var closest: Array=[];var distance_squared=.0144
 for x in [-1,0,1]:
  for y in [-1,0,1]:
   for z in [-1,0,1]:
    for sample in grid.get(key+Vector3i(x,y,z),[]):
     var distance=at.distance_squared_to(sample[0])
     if distance<distance_squared:distance_squared=distance;closest=sample
 if closest.is_empty():return at
 var outward: Vector3=closest[1]
 var clearance=(at-closest[0]).dot(outward)
 return at+outward*maxf(0,.025-clearance)

func add_lungi(guard: Node3D) -> void:
 var rig: Skeleton3D=guard._skeleton
 if rig.get_node_or_null("OpaqueLungiSocket")!=null:return
 # Clothing only: complete MPFB anatomy and the separate foundation remain intact.
 var socket=BoneAttachment3D.new();socket.name="OpaqueLungiSocket";socket.bone_name="pelvis";rig.add_child(socket)
 var garment=MeshInstance3D.new();var wrap=CylinderMesh.new();wrap.top_radius=.29;wrap.bottom_radius=.36;wrap.height=.50;wrap.radial_segments=32;garment.mesh=wrap
 var cotton=StandardMaterial3D.new();cotton.albedo_color=Color(.66,.60,.43);cotton.roughness=1;cotton.cull_mode=BaseMaterial3D.CULL_DISABLED;garment.material_override=cotton;socket.add_child(garment)
 var placement=Transform3D(Basis.IDENTITY,Vector3(0,.66,0))
 garment.transform=rig.get_bone_global_rest(rig.find_bone("pelvis")).affine_inverse()*Transform3D(rig.global_basis.inverse()*guard.global_basis,rig.to_local(guard.to_global(placement.origin)))

func prepare_stripped_guard(visual: Node3D,guard: Node3D) -> bool:
 var rig: Skeleton3D=visual.skeleton;var donor: Skeleton3D=guard._skeleton
 var foundation: MeshInstance3D
 for node in visual.find_children("*","MeshInstance3D",true,false):
  if node.skin!=null and "opaque foundation" in mesh_label(node):foundation=node;break
 if foundation==null:return false
 if donor.get_node_or_null("TakenUniformFoundation")==null:
  if copy_garment(foundation,rig,donor,"TakenUniformFoundation")==null:return false
 add_lungi(guard)
 return true
func strip_guard(visual: Node3D,guard: Node3D) -> void:
 if not prepare_stripped_guard(visual,guard):return
 for node in guard.find_children("*","MeshInstance3D",true,false):
  if node.mesh!=null and is_uniform(mesh_label(node)):node.hide()
