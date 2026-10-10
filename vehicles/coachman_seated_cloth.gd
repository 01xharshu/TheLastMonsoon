extends RefCounted
const CACHE_PATH := "res://vehicles/generated/coachman_startup_cloth.res"
const CACHE_REVISION := 2
var use_startup_cache := true
var startup_signature := ""
const Startup = preload("res://systems/world_startup.gd")
## Reforms only the existing exported garments; the MakeHuman body stays skinned.
var actor: Node3D
var coach: Node3D
var pieces: Array[Dictionary] = []
var last_knee := Vector3(INF,INF,INF)
var updates := 0
var skin_fit = preload("res://vehicles/coachman_clearance.gd").new()
var skin_corrections := 0
var fit_cache: Dictionary = {}
func configure(person: Node3D, vehicle: Node3D) -> void:
 actor = person
 coach = vehicle
 for node in actor.find_children("*","MeshInstance3D",true,false):
  var label: String = node.name.to_lower()
  if not ("wrapped dhoti" in label or "dhoti woven border" in label): continue
  var surfaces: Array[Dictionary] = []
  for index in node.mesh.get_surface_count():
   surfaces.append({"arrays":node.mesh.surface_get_arrays(index),"material":node.get_active_material(index)})
  pieces.append({"node":node,"surfaces":surfaces})
  node.skin = null
  node.skeleton = NodePath("")
  node.show()
func update() -> void:
 var skeleton: Skeleton3D = actor._skeleton
 var knee := Vector3.ZERO
 for side in ["l","r"]:
  knee += coach.to_local(skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("calf_"+side)).origin))*.5
 if knee.distance_to(last_knee) < .0005: return
 last_knee = knee
 # Dynamically spawned traffic needs the same exact-input cache as title loads.
 # Trying only on first fit avoids hashing full body meshes during motion.
 if use_startup_cache and updates == 0:
  startup_signature = source_signature()
  if _restore_startup_cache(): return
 skin_fit.build_body(actor,coach)
 skin_corrections = 0
 fit_cache.clear()
 var hip: Vector3 = coach.to_local(skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("pelvis")).origin))
 for piece in pieces:
  var node: MeshInstance3D = piece.node
  var result := ArrayMesh.new()
  for surface in piece.surfaces:
   var arrays: Array = surface.arrays
   var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
   var uv := PackedVector2Array()
   if arrays[Mesh.ARRAY_TEX_UV] != null: uv = arrays[Mesh.ARRAY_TEX_UV]
   else:
    for point in source: uv.append(Vector2(atan2(point.z,point.x)/TAU+.5,point.y))
   var indices := PackedInt32Array()
   if arrays[Mesh.ARRAY_INDEX] != null: indices = arrays[Mesh.ARRAY_INDEX]
   else:
    for index in source.size(): indices.append(index)
   var tool := SurfaceTool.new()
   tool.begin(Mesh.PRIMITIVE_TRIANGLES)
   for triangle in range(0,indices.size(),3):
    if triangle % 24 == 0: await Startup.checkpoint(actor, "Preparing the carriages…")
    var ids := [indices[triangle],indices[triangle+1],indices[triangle+2]]
    _split_triangle(tool,node,[source[ids[0]],source[ids[1]],source[ids[2]]],[uv[ids[0]],uv[ids[1]],uv[ids[2]]],2,hip,knee)
   tool.index()
   tool.generate_normals()
   tool.set_material(surface.material)
   tool.commit(result)
  node.mesh = await _relax(result,node)
 updates += 1

func _split_triangle(tool: SurfaceTool,node: MeshInstance3D,points: Array,uv: Array,level: int,hip: Vector3,knee: Vector3) -> void:
 if level > 0:
  var ab: Vector3 = (points[0]+points[1])*.5
  var bc: Vector3 = (points[1]+points[2])*.5
  var ca: Vector3 = (points[2]+points[0])*.5
  var uab: Vector2 = (uv[0]+uv[1])*.5
  var ubc: Vector2 = (uv[1]+uv[2])*.5
  var uca: Vector2 = (uv[2]+uv[0])*.5
  _split_triangle(tool,node,[points[0],ab,ca],[uv[0],uab,uca],level-1,hip,knee)
  _split_triangle(tool,node,[ab,points[1],bc],[uab,uv[1],ubc],level-1,hip,knee)
  _split_triangle(tool,node,[ca,bc,points[2]],[uca,ubc,uv[2]],level-1,hip,knee)
  _split_triangle(tool,node,[ab,bc,ca],[uab,ubc,uca],level-1,hip,knee)
  return
 for index in 3:
  var point: Vector3 = points[index]
  if fit_cache.has(point):
   tool.set_uv(uv[index])
   tool.add_vertex(node.to_local(coach.to_global(fit_cache[point])))
   continue
  var t := clampf((.84-point.y)/.41,0,1)
  var center := (hip+Vector3.UP*.025).lerp(knee+Vector3(0,-.035,-.04),smoothstep(0,1,t))
  var angle := t*PI*.45
  var depth := Vector3(0,sin(angle),-cos(angle))
  var wrapped_depth := lerpf(point.z,absf(point.z),smoothstep(.12,.45,t))
  var at := center+Vector3.RIGHT*point.x*lerpf(.82,1.0,t)+depth*wrapped_depth*lerpf(.74,.63,t)
  if point.z < 0: at += depth*.007*smoothstep(.12,.45,t)
  # Keep the rear cloth above the existing cushion; never cut the body beneath it.
  if absf(at.x) < .79 and at.z > .68 and at.z < 1.22:
   at.y = maxf(at.y,1.825)
  # Fit against the retained posed body instead of hiding covered anatomy.
  for iteration in 3:
   var near: Dictionary = skin_fit.nearest(at)
   if not near.is_empty() and near.distance < .13 and near.signed < .022:
    at = near.point+near.normal*.022
    skin_corrections += 1
   if absf(at.x) < .79 and at.z > .68 and at.z < 1.22:
    at.y = maxf(at.y,1.825)
  fit_cache[point] = at
  tool.set_uv(uv[index])
  tool.add_vertex(node.to_local(coach.to_global(at)))

func _relax(mesh: ArrayMesh,node: MeshInstance3D) -> ArrayMesh:
 var relaxed := ArrayMesh.new()
 for surface in mesh.get_surface_count():
  var arrays: Array = mesh.surface_get_arrays(surface)
  var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
  var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
  var neighbors: Array[Dictionary] = []
  for index in positions.size(): neighbors.append({})
  for offset in range(0,indices.size(),3):
   for edge in 3:
    var a: int = indices[offset+edge]
    var b: int = indices[offset+(edge+1)%3]
    neighbors[a][b] = true
    neighbors[b][a] = true
  for iteration in 2:
   var next := positions.duplicate()
   for index in positions.size():
    if index % 32 == 0: await Startup.checkpoint(actor, "Preparing the carriages…")
    if neighbors[index].is_empty(): continue
    var average := Vector3.ZERO
    for other in neighbors[index]: average += positions[other]
    average /= neighbors[index].size()
    var at: Vector3 = coach.to_local(node.to_global(positions[index].lerp(average,.38)))
    for correction in 3:
     var near: Dictionary = skin_fit.nearest(at)
     if not near.is_empty() and near.distance < .13 and near.signed < .022: at = near.point+near.normal*.022
    if absf(at.x) < .79 and at.z > .68 and at.z < 1.22: at.y = maxf(at.y,1.825)
    next[index] = node.to_local(coach.to_global(at))
   positions = next
  arrays[Mesh.ARRAY_VERTEX] = positions
  arrays[Mesh.ARRAY_NORMAL] = null
  arrays[Mesh.ARRAY_TANGENT] = null
  var intermediate := ArrayMesh.new()
  intermediate.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var tool := SurfaceTool.new()
  tool.create_from(intermediate,0)
  tool.generate_normals()
  tool.set_material(mesh.surface_get_material(surface))
  tool.commit(relaxed)
 return relaxed

func _contact(at: Vector3) -> Vector3:
 for iteration in 4:
  var near: Dictionary = skin_fit.nearest(at)
  if not near.is_empty() and near.distance < .13 and near.signed < .025: at = near.point+near.normal*.025
  if absf(at.x) < .79 and at.z > .68 and at.z < 1.22: at.y = maxf(at.y,1.835)
 return at
func _refine_contact(mesh: ArrayMesh,node: MeshInstance3D) -> ArrayMesh:
 var refined := ArrayMesh.new()
 for surface in mesh.get_surface_count():
  var arrays: Array = mesh.surface_get_arrays(surface)
  var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
  var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
  var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
  var tool := SurfaceTool.new()
  tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  for offset in range(0,indices.size(),3):
   var a: int = indices[offset]
   var b: int = indices[offset+1]
   var c: int = indices[offset+2]
   var pa := coach.to_local(node.to_global(positions[a]))
   var pb := coach.to_local(node.to_global(positions[b]))
   var pc := coach.to_local(node.to_global(positions[c]))
   var ab := _contact((pa+pb)*.5)
   var bc := _contact((pb+pc)*.5)
   var ca := _contact((pc+pa)*.5)
   var uab := (uv[a]+uv[b])*.5
   var ubc := (uv[b]+uv[c])*.5
   var uca := (uv[c]+uv[a])*.5
   var points := [pa,ab,ca,ab,pb,bc,ca,bc,pc,ab,bc,ca]
   var coordinates := [uv[a],uab,uca,uab,uv[b],ubc,uca,ubc,uv[c],uab,ubc,uca]
   for index in points.size():
    tool.set_uv(coordinates[index])
    tool.add_vertex(node.to_local(coach.to_global(points[index])))
  tool.index()
  tool.generate_normals()
  tool.set_material(mesh.surface_get_material(surface))
  tool.commit(refined)
 return refined

func source_signature() -> String:
 # Validate complete body/garment inputs and the actual seated bone pose.
 var digest := HashingContext.new()
 digest.start(HashingContext.HASH_SHA256)
 for piece in pieces:
  digest.update(var_to_bytes(piece.node.transform))
  for surface in piece.surfaces: digest.update(var_to_bytes(surface.arrays))
 for node in actor.find_children("*","MeshInstance3D",true,false):
  if node.skin == null: continue
  for surface in node.mesh.get_surface_count():
   var arrays: Array = node.mesh.surface_get_arrays(surface)
   if arrays[Mesh.ARRAY_VERTEX].size() >= 14000: digest.update(var_to_bytes(arrays))
 var rig: Skeleton3D = actor._skeleton
 var pose := PackedFloat32Array()
 var relative: Transform3D = coach.global_transform.affine_inverse()*rig.global_transform
 for index in rig.get_bone_count():
  var transform: Transform3D = relative*rig.get_bone_global_pose(index)
  for axis in [transform.basis.x,transform.basis.y,transform.basis.z,transform.origin]:
   for component in [axis.x,axis.y,axis.z]: pose.append(snappedf(component,.001))
 digest.update(var_to_bytes(pose))
 return digest.finish().hex_encode()

func _restore_startup_cache() -> bool:
 if not ResourceLoader.exists(CACHE_PATH): return false
 var cached := load(CACHE_PATH)
 if cached.get_meta("revision",0) != CACHE_REVISION or cached.get_meta("signature","") != startup_signature: return false
 var meshes: Dictionary = cached.get_meta("meshes",{})
 for piece in pieces:
  if not meshes.has(str(piece.node.name)): return false
 for piece in pieces:
  piece.node.mesh = meshes[str(piece.node.name)]
  for surface in piece.surfaces.size(): piece.node.set_surface_override_material(surface,piece.surfaces[surface].material)
 actor.set_meta("startup_cloth_cache",true)
 updates += 1
 return true
