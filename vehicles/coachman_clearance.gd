extends RefCounted
## Actual posed body triangles, spatially indexed in cart coordinates.
const CELL := .12
var triangles: Array[Dictionary] = []
var cells: Dictionary = {}
var hierarchy: Array[Dictionary] = []
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
 hierarchy.clear()
 var skeleton: Skeleton3D = actor._skeleton
 for node in actor.find_children("*","MeshInstance3D",true,false):
  if node.skin == null: continue
  for surface in node.mesh.get_surface_count():
   if node.mesh.surface_get_array_len(surface) < 14000: continue
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
 # Build once for this exact posed body; queries retain the old cell domain.
 var ids: Array[int] = []
 for index in triangles.size(): ids.append(index)
 if not ids.is_empty(): _build_hierarchy(ids)

func _build_hierarchy(ids: Array[int]) -> int:
 var low: Vector3 = triangles[ids[0]].low
 var high: Vector3 = triangles[ids[0]].high
 for id in ids:
  low = low.min(triangles[id].low)
  high = high.max(triangles[id].high)
 var index := hierarchy.size()
 hierarchy.append({"low":low,"high":high,"cell_low":_cell(low),"cell_high":_cell(high)})
 if ids.size() <= 8:
  hierarchy[index]["ids"] = ids
 else:
  var extent := high-low
  var axis := 0 if extent.x >= extent.y and extent.x >= extent.z else 1 if extent.y >= extent.z else 2
  ids.sort_custom(func(a: int,b: int) -> bool:
   return (triangles[a].low[axis]+triangles[a].high[axis]) < (triangles[b].low[axis]+triangles[b].high[axis]))
  var middle: int = ids.size()/2
  hierarchy[index]["left"] = _build_hierarchy(ids.slice(0,middle))
  hierarchy[index]["right"] = _build_hierarchy(ids.slice(middle))
 return index

func _in_domain(low: Vector3i,high: Vector3i,key: Vector3i) -> bool:
 return low.x <= key.x+1 and high.x >= key.x-1 and low.y <= key.y+1 and high.y >= key.y-1 and low.z <= key.z+1 and high.z >= key.z-1

func _earlier(cell: Vector3i,id: int,previous: Vector3i,previous_id: int) -> bool:
 if cell.x != previous.x: return cell.x < previous.x
 if cell.y != previous.y: return cell.y < previous.y
 if cell.z != previous.z: return cell.z < previous.z
 return id < previous_id

func nearest(at: Vector3) -> Dictionary:
 if hierarchy.is_empty(): return {}
 var key := _cell(at)
 var distance := INF
 var result: Dictionary = {}
 var best_cell := Vector3i.ZERO
 var best_id := -1
 var pending: Array[int] = [0]
 while not pending.is_empty():
  var node: Dictionary = hierarchy[pending.pop_back()]
  if not _in_domain(node.cell_low,node.cell_high,key): continue
  var box_point: Vector3 = at.clamp(node.low,node.high)
  if box_point.distance_squared_to(at) > distance+0.0000000001: continue
  if node.has("ids"):
   for id in node.ids:
    var triangle: Dictionary = triangles[id]
    var cell_low := _cell(triangle.low)
    if not _in_domain(cell_low,_cell(triangle.high),key): continue
    box_point = at.clamp(triangle.low,triangle.high)
    if box_point.distance_squared_to(at) > distance+0.0000000001: continue
    var point := closest(at,triangle.a,triangle.b,triangle.c)
    var squared := point.distance_squared_to(at)
    var first_cell := cell_low.max(key-Vector3i.ONE)
    if squared < distance or (squared == distance and _earlier(first_cell,id,best_cell,best_id)):
     distance = squared
     best_cell = first_cell
     best_id = id
     result = {"distance":sqrt(squared),"signed":(at-point).dot(triangle.normal),"point":point,"normal":triangle.normal}
  else:
   var left: Dictionary = hierarchy[node.left]
   var right: Dictionary = hierarchy[node.right]
   var left_at: Vector3 = at.clamp(left.low,left.high)
   var right_at: Vector3 = at.clamp(right.low,right.high)
   var left_first := left_at.distance_squared_to(at) <= right_at.distance_squared_to(at)
   pending.append(node.right if left_first else node.left)
   pending.append(node.left if left_first else node.right)
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
