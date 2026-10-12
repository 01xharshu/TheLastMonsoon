extends Node
## One queued navigation owner per mission actor; stale results are discarded.
const Queue = preload("res://systems/navigation_work_queue.gd")
var actor: Node3D
var goal := Vector3.INF
var path: Array[Vector3] = []
var pending := false
var retry := 0.0
var blocked := 0.0
var encounters: Node
func configure(person: Node3D, movement: Node) -> void:
 actor = person
 encounters = movement
func cancel() -> void:
 goal = Vector3.INF
 path.clear()
 pending = false
 if is_instance_valid(actor): actor.travel_speed = 0
func receive_navigation(points: Array[Vector3], target: Vector3) -> void:
 if not goal.is_finite() or not target.is_equal_approx(goal): return
 pending = false
 path = points.duplicate()
 retry = 1.0
func advance(target: Vector3, speed: float, delta: float) -> bool:
 if not is_instance_valid(actor) or actor.get_meta("dead", false) or actor.get_meta("knocked_out", false):
  cancel()
  return false
 retry = maxf(0, retry-delta)
 if not goal.is_finite() or goal.distance_to(target)>2:
  goal = target
  path.clear()
  pending = false
 if actor.global_position.distance_to(target)<.65:
  actor.travel_speed = 0
  return true
 if path.is_empty():
  actor.travel_speed = 0
  if not pending and retry<=0:
   pending = Queue.request(self, actor, goal)
   retry = 1.0
  return false
 var before := actor.global_position
 if encounters.move_actor(actor, path[0], speed, delta): path.pop_front()
 blocked = blocked+delta if actor.global_position.distance_squared_to(before)<.000001 else 0.0
 if blocked>1.5:
  path.clear()
  pending = false
  blocked = 0
 return false
