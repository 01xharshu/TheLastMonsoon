extends RefCounted
## Reforms only the existing exported garments; the MakeHuman body stays skinned.
var actor: Node3D
var coach: Node3D
var pieces: Array[Dictionary] = []
var last_knee := Vector3(INF,INF,INF)
var updates := 0
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
 var hip: Vector3 = coach.to_local(skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("pelvis")).origin))
 for piece in pieces:
  var node: MeshInstance3D = piece.node
  var result := ArrayMesh.new()
  for surface in piece.surfaces:
   var arrays: Array = surface.arrays.duplicate(true)
   var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
   var vertices := PackedVector3Array()
   for point in source:
    var t: float = clampf((.84-point.y)/.41,0,1)
    var top := hip+Vector3.UP*.015
    var end := knee+Vector3(0,-.035,-.03)
    var center := top.lerp(end,t)
    var angle := t*PI*.45
    var depth := Vector3(0,sin(angle),-cos(angle))
    var width: float = point.x * lerpf(.80,1.0,t)
    var fold_scale: float = lerpf(.72,.6,t)
    var at := center+Vector3.RIGHT*width+depth*point.z*fold_scale
    vertices.append(node.to_local(coach.to_global(at)))
   arrays[Mesh.ARRAY_VERTEX] = vertices
   arrays[Mesh.ARRAY_BONES] = null
   arrays[Mesh.ARRAY_WEIGHTS] = null
   arrays[Mesh.ARRAY_NORMAL] = null
   arrays[Mesh.ARRAY_TANGENT] = null
   var intermediate := ArrayMesh.new()
   intermediate.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   var tool := SurfaceTool.new()
   tool.create_from(intermediate,0)
   tool.generate_normals()
   tool.set_material(surface.material)
   tool.commit(result)
  node.mesh = result
 updates += 1
