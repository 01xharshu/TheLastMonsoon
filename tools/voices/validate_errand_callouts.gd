extends SceneTree

class Target extends Node3D:
 var person: Node3D
class Manager extends Node3D:
 var active := ""
 var player: Node3D
 var targets := {}
 var available := ""
 var message := ""
 func job_available(id: String) -> bool: return id == available
 func _message(text: String) -> void: message = text

func _initialize() -> void: run.call_deferred()
func run() -> void:
 create_timer(8.0).timeout.connect(func(): push_error("Errand fixture timed out"); quit(1))
 var manager := Manager.new(); root.add_child(manager)
 manager.player = Node3D.new(); manager.add_child(manager.player)
 for key in ["medicine_request", "money_sender", "road"]:
  var target := Target.new(); manager.add_child(target)
  target.person = Node3D.new(); target.add_child(target.person)
  manager.targets[key] = target
 var calls: Node = load("res://world/suryagarh/errands/expanded_jobs.gd").new()
 manager.add_child(calls); calls.set_physics_process(false); calls.manager = manager
 for entry in [["medicine_request", "urgent_medicine", "medicine"], ["money_sender", "emergency_money", "money"], ["road", "road_meal", "food"]]:
  calls.call_cooldown = 0; manager.available = entry[1]
  calls._physics_process(.1)
  var person: Node3D = manager.targets[entry[0]].person
  var voice: AudioStreamPlayer3D = person.get_child(0) as AudioStreamPlayer3D
  assert(voice != null and voice.playing)
  assert(voice.stream.resource_path.ends_with("errand_" + entry[2] + ".wav"))
  assert(voice.max_distance == 22 and voice.volume_db == -8 and calls.call_cooldown == 45)
  assert(not manager.message.is_empty())
  calls._physics_process(.1); assert(person.get_child_count() == 1)
  voice.queue_free(); await process_frame
 print("ERRAND CALLOUTS PASS: three positional WAVs, captions, cooldown")
 quit()
