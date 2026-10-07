extends RefCounted
## Actual posed body triangles, spatially indexed in cart coordinates.
const CELL := .12
var triangles: Array[Dictionary] = []
var cells: Dictionary = {}
func _cell(at: Vector3) -> Vector3i:
 return Vector3i(floori(at.x/CELL),floori(at.y/CELL),floori(at.z/CELL))
static func closest(p: Vector3,a: Vector3,b: Vector3,c: Vector3) -> Vector3:
 var ab := b-a
 var ac := c-a
 var ap := p-a
 var d1 := ab.dot(ap)
 var d2 := ac.dot(ap)
 if d1 <= 0 and d2 <= 0: return a
 var bp := p-b
 var d3 := ab.dot(bp)
 var d4 := ac.dot(bp)
 if d3 >= 0 and d4 <= d3: return b
 var vc := d1*d4-d3*d2
 if vc <= 0 and d1 >= 0 and d3 <= 0: return a+ab*(d1/(d1-d3))
 var cp := p-c
 var d5 := ab.dot(cp)
 var d6 := ac.dot(cp)
 if d6 >= 0 and d5 <= d6: return c
 var vb := d5*d2-d1*d6
 if vb <= 0 and d2 >= 0 and d6 <= 0: return a+ac*(d2/(d2-d6))
 var va := d3*d6-d5*d4
 if va <= 0 and d4-d3 >= 0 and d5-d6 >= 0: return b+(c-b)*((d4-d3)/((d4-d3)+(d5-d6)))
 var denom := va+vb+vc
 return a if absf(denom) < .00000001 else a+ab*(vb/denom)+ac*(vc/denom)
func build_body(actor: Node3D,coach: Node3D) -> void:
 triangles.clear()
 cells.clear()
 var skeleton: Skeleton3D = actor._skeleton
 for node in actor.find_children("*","MeshInstance3D",true,false):
  if node.skin == null: continue
  for surface in node.mesh.get_surface_count():
   var arrays: Array = node.mesh.surface_get_arrays(surface)
   var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
   if vertices.size() < 14000: continue
   var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
   var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
   var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
   var stride: int = bones.size()/vertices.size()
   var transforms: Array[Transform3D] = []
   for bind in node.skin.get_bind_count():
    var bone: int = node.skin.get_bind_bone(bind)
    if bone < 0: bone = skeleton.find_bone(node.skin.get_bind_name(bind))
    transforms.append(skeleton.get_bone_global_pose(bone)*node.skin.get_bind_pose(bind))
   var posed := PackedVector3Array()
   var directions := PackedVector3Array()
   var to_cart := coach.global_transform.affine_inverse()*skeleton.global_transform
   for index in vertices.size():
    var point := Vector3.ZERO
    var normal := Vector3.ZERO
    for slot in stride:
     var offset: int = index*stride+slot
     if weights[offset] <= 0: continue
     var transform: Transform3D = transforms[bones[offset]]
     point += (transform*vertices[index])*weights[offset]
     normal += (transform.basis*normals[index])*weights[offset]
    posed.append(to_cart*point)
    directions.append((to_cart.basis*normal).normalized())
   var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
   for offset in range(0,indices.size(),3):
    var a: Vector3 = posed[indices[offset]]
    var b: Vector3 = posed[indices[offset+1]]
    var c: Vector3 = posed[indices[offset+2]]
    if maxf(a.y,maxf(b.y,c.y)) < 1.40 or minf(a.y,minf(b.y,c.y)) > 2.12: continue
    var normal: Vector3 = (directions[indices[offset]]+directions[indices[offset+1]]+directions[indices[offset+2]]).normalized()
    var id := triangles.size()
    triangles.append({"a":a,"b":b,"c":c,"normal":normal,"low":a.min(b).min(c),"high":a.max(b).max(c)})
    var low := _cell(a.min(b).min(c))
    var high := _cell(a.max(b).max(c))
    for x in range(low.x,high.x+1):
     for y in range(low.y,high.y+1):
      for z in range(low.z,high.z+1):
       var key := Vector3i(x,y,z)
       if not cells.has(key): cells[key] = []
       cells[key].append(id)
func nearest(at: Vector3) -> Dictionary:
 var key := _cell(at)
 var distance := INF
 var result: Dictionary = {}
 var visited: Dictionary = {}
 for x in range(-1,2):
  for y in range(-1,2):
   for z in range(-1,2):
    for id in cells.get(key+Vector3i(x,y,z),[]):
     if visited.has(id): continue
     visited[id] = true
     var triangle: Dictionary = triangles[id]
     # Exact lower bound: distant triangle boxes cannot beat the current hit.
     # Keep the existing cell/triangle order and tie handling for contact parity.
     var box_point: Vector3 = at.clamp(triangle.low, triangle.high)
     if box_point.distance_squared_to(at) > distance + 0.0000000001: continue
     var point := closest(at,triangle.a,triangle.b,triangle.c)
     var squared := point.distance_squared_to(at)
     if squared < distance:
      distance = squared
      result = {"distance":sqrt(squared),"signed":(at-point).dot(triangle.normal),"point":point,"normal":triangle.normal}
 return result

func audit_garment(driver: Node3D,cart: Node3D) -> Dictionary:
 var audit := self
 audit.build_body(driver,cart)
 var worst_skin := INF
 var seat_hits := 0
 var vertices := 0
 var cloth_triangles: Array = []
 for piece in driver.seated_cloth.pieces:
  var node: MeshInstance3D = piece.node
  for surface in node.mesh.get_surface_count():
   var arrays: Array = node.mesh.surface_get_arrays(surface)
   var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
   var posed := PackedVector3Array()
   for point in positions:
    var at: Vector3 = cart.to_local(node.to_global(point))
    posed.append(at)
    vertices += 1
    var near: Dictionary = audit.nearest(at)
    if not near.is_empty(): worst_skin = minf(worst_skin,near.signed)
    if absf(at.x) < .765 and at.y > 1.65 and at.y < 1.81 and at.z > .69 and at.z < 1.19: seat_hits += 1
   var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
   for offset in range(0,indices.size(),3):
    var triangle := [posed[indices[offset]],posed[indices[offset+1]],posed[indices[offset+2]]]
    cloth_triangles.append(triangle)
    for at in [(triangle[0]+triangle[1]+triangle[2])/3.0,(triangle[0]+triangle[1])*.5,(triangle[1]+triangle[2])*.5,(triangle[2]+triangle[0])*.5]:
     var near: Dictionary = audit.nearest(at)
     if not near.is_empty(): worst_skin = minf(worst_skin,near.signed)
     if absf(at.x) < .765 and at.y > 1.65 and at.y < 1.81 and at.z > .69 and at.z < 1.19: seat_hits += 1
 var rein_gap := INF
 for entry in cart.get_node("FlexibleReins").reins:
  for index in range(entry.points.size()-1):
   var a: Vector3 = cart.to_local(entry.points[index])
   var b: Vector3 = cart.to_local(entry.points[index+1])
   for sample in 5:
    var at := a.lerp(b,float(sample)/4)
    if at.z < .2 or at.z > 1.3: continue
    for triangle in cloth_triangles:
     rein_gap = minf(rein_gap,at.distance_to(audit.closest(at,triangle[0],triangle[1],triangle[2])))
 print("COACHMAN CLEARANCE AUDIT | body_triangles=",audit.triangles.size()," cloth_vertices=",vertices," minimum_signed_skin_m=",worst_skin," seat_vertices=",seat_hits," rein_surface_m=",rein_gap)
 var report := {"body_triangles":audit.triangles.size(),"cloth_vertices":vertices,"minimum_signed_skin_m":worst_skin,"seat_vertices":seat_hits,"rein_surface_m":rein_gap}
 return report
