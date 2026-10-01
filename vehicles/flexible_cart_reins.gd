extends Node3D
## Damped leather strips with pinned bit/palm endpoints; two draw surfaces per cart.
const SEGMENTS := 16
var cart: Node3D
var reins: Array[Dictionary] = []
func configure(vehicle: Node3D) -> void:
 cart = vehicle
 process_priority = 120 # After the character's pose and arm contact solve.
func _ready() -> void:
 for part in cart.visual_root.get_children():
  if not part is MeshInstance3D or not str(part.get_meta("part_label",part.name)).begins_with("Rein"): continue
  if not part.mesh is BoxMesh: continue
  var half: Vector3 = part.basis.y*part.mesh.size.y*.5
  var a: Vector3 = part.position-half
  var b: Vector3 = part.position+half
  var bit: Vector3 = a if a.z < b.z else b
  var hand: Vector3 = b if a.z < b.z else a
  var side := "l" if hand.distance_to(cart.to_local(cart.rein_grip_world("l"))) < hand.distance_to(cart.to_local(cart.rein_grip_world("r"))) else "r"
  var strip := MeshInstance3D.new()
  strip.mesh = ImmediateMesh.new()
  var material: StandardMaterial3D = part.material_override.duplicate()
  material.cull_mode = BaseMaterial3D.CULL_DISABLED
  strip.material_override = material
  add_child(strip)
  var entry := {"side":side,"bit":bit,"hand":hand,"strip":strip,"points":[],"previous":[],"rig":null,"head":-1,"head_anchor":Vector3.ZERO}
  var nearest := INF
  for rig in cart.visual_root.find_children("*","Skeleton3D",true,false):
   var head: int = rig.find_bone("Head")
   if head < 0: continue
   var at: Vector3 = rig.to_global(rig.get_bone_global_rest(head).origin)
   var distance: float = at.distance_to(cart.to_global(bit))
   if distance < nearest:
    nearest = distance
    entry.rig = rig
    entry.head = head
    entry.head_anchor = rig.get_bone_global_rest(head).affine_inverse()*rig.to_local(cart.to_global(bit))
  reins.append(entry)
  part.hide()
func anchors(entry: Dictionary) -> Array[Vector3]:
 var bit: Vector3 = cart.to_global(entry.bit)
 if is_instance_valid(entry.rig):
  var rig: Skeleton3D = entry.rig
  rig.force_update_all_bone_transforms()
  bit = rig.to_global(rig.get_bone_global_pose(entry.head)*entry.head_anchor)
 var hand: Vector3 = cart.to_global(entry.hand)
 if cart.boarding != null and cart.boarding.rider != null and cart.boarding.role == "driver" and cart.boarding.transition == "":
  var visual: Node3D = cart.boarding.rider.get_node("VisualRoot/CharacterVisual")
  var rig: Skeleton3D = visual.skeleton
  hand = rig.to_global(rig.get_bone_global_pose(rig.find_bone("hand_"+entry.side))*visual.equipment.palm_offsets[entry.side])
 return [bit,hand]
func _process(delta: float) -> void:
 for entry in reins:
  var pins := anchors(entry)
  entry.rendered_pins = pins.duplicate()
  var points: Array = entry.points
  var previous: Array = entry.previous
  if points.is_empty() or (points[0] as Vector3).distance_to(pins[0]) > 2.0:
   points.clear()
   previous.clear()
   for index in SEGMENTS+1:
    var p := pins[0].lerp(pins[1],float(index)/SEGMENTS)-Vector3.UP*sin(PI*index/SEGMENTS)*.25
    points.append(p)
    previous.append(p)
  var step: float = pins[0].distance_to(pins[1])*1.025/SEGMENTS
  var elapsed := minf(delta,1.0/30.0)
  for index in range(1,SEGMENTS):
   var current: Vector3 = points[index]
   points[index] = current+(current-previous[index])*.88+Vector3.DOWN*7.0*elapsed*elapsed
   previous[index] = current
  for iteration in 12:
   points[0] = pins[0]
   points[SEGMENTS] = pins[1]
   for index in SEGMENTS:
    var edge: Vector3 = points[index+1]-points[index]
    var correction := edge*(1.0-step/maxf(edge.length(),.0001))
    if index == 0: points[index+1] -= correction
    elif index == SEGMENTS-1: points[index] += correction
    else:
     points[index] += correction*.5
     points[index+1] -= correction*.5
  points[0] = pins[0]
  points[SEGMENTS] = pins[1]
  var mesh: ImmediateMesh = entry.strip.mesh
  mesh.clear_surfaces()
  mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
  for index in SEGMENTS:
   var a: Vector3 = to_local(points[index])
   var b: Vector3 = to_local(points[index+1])
   var across := (b-a).cross(Vector3.UP).normalized()*.009
   var normal := across.cross(b-a).normalized()
   mesh.surface_set_normal(normal)
   for vertex in [a-across,a+across,b+across,a-across,b+across,b-across]: mesh.surface_add_vertex(vertex)
  mesh.surface_end()
