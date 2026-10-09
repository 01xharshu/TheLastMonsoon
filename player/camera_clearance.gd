extends Camera3D
# Final camera clearance and smooth recovery after the spring arm retracts.
@onready var arm: SpringArm3D = get_parent()
@onready var actor: CharacterBody3D = get_node("../../..")
var clearance_query := PhysicsRayQueryParameters3D.new()
var shoulder_query := PhysicsRayQueryParameters3D.new()
var shoulder_overlap := PhysicsShapeQueryParameters3D.new()
var visible_distance := -1.0
var desired_shoulder_offset := 0.6
var shoulder_scale := 1.0
var shoulder_probe_elapsed := 0.0
var shoulder_blocked := false
var body_hidden_by_camera := false
const WALL_GAP := 0.20
const RETURN_SPEED := 5.0
const BODY_HIDE_DISTANCE := 0.42
const SHOULDER_MIN_CLEARANCE := 0.50

func _ready() -> void:
 clearance_query.exclude = [actor.get_rid()]
 clearance_query.collision_mask = arm.collision_mask
 shoulder_query.exclude = [actor.get_rid()]
 shoulder_query.collision_mask = arm.collision_mask
 shoulder_overlap.exclude = [actor.get_rid()]
 shoulder_overlap.collision_mask = arm.collision_mask
 var probe_shape := SphereShape3D.new()
 probe_shape.radius = 0.18
 shoulder_overlap.shape = probe_shape
 process_priority = 100

func _process(delta: float) -> void:
 if actor.first_person or arm.spring_length <= 0.01:
  visible_distance = -1.0
  body_hidden_by_camera = false
  return
 if not current:
  _restore_body()
  return
 shoulder_probe_elapsed += delta
 if (shoulder_scale == 1.0 and arm.get_hit_length() < SHOULDER_MIN_CLEARANCE) or shoulder_probe_elapsed >= 0.10:
  shoulder_probe_elapsed = 0.0
  var shoulder_origin: Vector3 = actor.camera_pivot.to_global(Vector3(desired_shoulder_offset, 0.0, 0.0))
  shoulder_query.from = shoulder_origin
  shoulder_query.to = shoulder_origin + arm.global_basis.z * SHOULDER_MIN_CLEARANCE
  shoulder_overlap.transform = Transform3D(Basis.IDENTITY, shoulder_origin)
  var space := get_world_3d().direct_space_state
  shoulder_blocked = not space.intersect_ray(shoulder_query).is_empty() or not space.intersect_shape(shoulder_overlap, 1).is_empty()
 shoulder_scale = 0.0 if shoulder_blocked else move_toward(shoulder_scale, 1.0, delta * 4.0)
 arm.position.x = desired_shoulder_offset * shoulder_scale
 var origin: Vector3 = arm.global_position
 var intended: float = maxf(0.0, arm.get_hit_length())
 # The spring arm updates at physics rate. Keep the previous rendered distance
 # so clearing a wall eases out instead of jumping to the full arm length.
 if visible_distance < 0.0:
  visible_distance = intended
 clearance_query.from = origin
 clearance_query.to = arm.to_global(Vector3(0.0, 0.0, intended))
 var hit := get_world_3d().direct_space_state.intersect_ray(clearance_query)
 if not hit.is_empty():
  intended = minf(intended, maxf(0.0, origin.distance_to(hit.position) - WALL_GAP))
 if intended < visible_distance:
  visible_distance = intended
 else:
  visible_distance = move_toward(visible_distance, intended, RETURN_SPEED * delta)
 position.z = visible_distance
 if actor.has_meta("mounted_vehicle") and actor.get_meta("mounted_vehicle") != null:
  _restore_body()
 elif visible_distance <= BODY_HIDE_DISTANCE:
  if actor.visual_root.visible:
   actor.visual_root.visible = false
   body_hidden_by_camera = true
 else:
  _restore_body()

func _restore_body() -> void:
 if body_hidden_by_camera:
  actor.visual_root.visible = true
  body_hidden_by_camera = false
