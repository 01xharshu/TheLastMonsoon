extends Node3D
## Damped leather strips with pinned bit/palm endpoints and persistent quad buffers.
const SEGMENTS := 16
var cart: Node3D
var reins: Array[Dictionary] = []
const FULL_DETAIL_DISTANCE := 80.0
const DETAIL_CULL_DISTANCE := 180.0
const DISTANCE_CHECK_SECONDS := .25
const DISTANT_UPDATE_SECONDS := .1
var distance_lod_enabled := true
var detail_updates := 0
var _distance_elapsed := DISTANCE_CHECK_SECONDS
var _detail_elapsed := 0.0
var _distance_squared := 0.0

func _detail_due(delta: float) -> bool:
 if not distance_lod_enabled:
  visible = true
  return true
 # Occupied vehicles keep immediate contact updates, independent of camera distance.
 if cart.boarding != null and cart.boarding.rider != null:
  visible = true
  _detail_elapsed = 0.0
  return true
 _distance_elapsed += delta
 if _distance_elapsed >= DISTANCE_CHECK_SECONDS:
  _distance_elapsed = 0.0
  var camera := get_viewport().get_camera_3d()
  _distance_squared = camera.global_position.distance_squared_to(cart.global_position) if camera != null else 0.0
 visible = _distance_squared <= DETAIL_CULL_DISTANCE * DETAIL_CULL_DISTANCE
 if not visible:
  _detail_elapsed = 0.0
  return false
 if _distance_squared <= FULL_DETAIL_DISTANCE * FULL_DETAIL_DISTANCE:
  _detail_elapsed = 0.0
  return true
 _detail_elapsed += delta
 if _detail_elapsed < DISTANT_UPDATE_SECONDS: return false
 _detail_elapsed = fmod(_detail_elapsed,DISTANT_UPDATE_SECONDS)
 return true

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
  var strip := MultiMeshInstance3D.new()
  strip.multimesh = MultiMesh.new()
  strip.multimesh.transform_format = MultiMesh.TRANSFORM_3D
  strip.multimesh.mesh = QuadMesh.new()
  strip.multimesh.mesh.size = Vector2.ONE
  strip.multimesh.instance_count = SEGMENTS
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
 if not _detail_due(delta): return
 detail_updates += 1
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
  var strip: MultiMeshInstance3D = entry.strip
  var bounds := AABB(to_local(points[0]),Vector3.ZERO)
  for index in SEGMENTS:
   var a: Vector3 = to_local(points[index])
   var b: Vector3 = to_local(points[index+1])
   var across := (b-a).cross(Vector3.UP).normalized()*.009
   var normal := across.cross(b-a).normalized()
   # Same two triangles, width and normal as the former ImmediateMesh strip.
   # Reuse the instance buffer instead of freeing/recreating GPU surfaces.
   strip.multimesh.set_instance_transform(index,Transform3D(Basis(across*2.0,b-a,normal),(a+b)*.5))
   bounds = bounds.expand(a).expand(b)
  strip.multimesh.custom_aabb = bounds.grow(.02)
