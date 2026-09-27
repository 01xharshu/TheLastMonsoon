extends Camera3D
# Final camera clearance and smooth recovery after the spring arm retracts.
@onready var arm: SpringArm3D = get_parent()
@onready var actor: CharacterBody3D = get_node("../../..")
var clearance_query := PhysicsRayQueryParameters3D.new()
var visible_distance := -1.0
const WALL_GAP := 0.20
const RETURN_SPEED := 5.0
const BODY_HIDE_DISTANCE := 0.42

func _ready() -> void:
 clearance_query.exclude = [actor.get_rid()]
 clearance_query.collision_mask = arm.collision_mask
 process_priority = 100

func _process(delta: float) -> void:
 if actor.first_person or arm.spring_length <= 0.01:
  visible_distance = -1.0
  return
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
 actor.visual_root.visible = visible_distance > BODY_HIDE_DISTANCE
