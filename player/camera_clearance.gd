extends Camera3D
# Final render-frame clearance for thin/complex colliders missed by SpringArm3D.
@onready var arm: SpringArm3D = get_parent()
@onready var actor: CharacterBody3D = get_node("../../..")

func _process(_delta: float) -> void:
 if arm.spring_length <= 0.01:
  return
 var origin: Vector3 = arm.global_position
 var destination: Vector3 = global_position
 var distance := origin.distance_to(destination)
 if distance <= 0.01:
  return
 var query := PhysicsRayQueryParameters3D.create(origin, destination)
 query.collision_mask = arm.collision_mask
 query.exclude = [actor.get_rid()]
 var hit := get_world_3d().direct_space_state.intersect_ray(query)
 if hit.is_empty():
  return
 var clear_distance: float = maxf(0.0, origin.distance_to(hit.position) - 0.20)
 position.z = minf(position.z, clear_distance)
