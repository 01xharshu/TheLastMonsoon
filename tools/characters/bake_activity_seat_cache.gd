extends SceneTree
## Bake the existing activity seat samples using the headless imported rigs.
func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var args := OS.get_cmdline_user_args()
 if args.size() not in [1, 2] or (args.size() == 2 and args[1] != "--rebuild"):
  push_error("Expected an output path in a temporary directory")
  quit(2)
  return
 var profiles := {}
 for name in ["artisan", "cartmaker", "dairyman", "scholar", "teacher"]:
  var path: String = "res://characters/npcs/activity_people/" + name + ".glb"
  var actor_script := preload("res://characters/npcs/activity_actor.gd")
  actor_script.seat_profile_hashes[path] = ["", ""]
  var actor := actor_script.new()
  var model: Node = load(path).instantiate()
  actor.add_child(model)
  root.add_child(actor)
  if actor.seat_samples.is_empty():
   push_error("No seat samples for " + path)
   quit(1)
   return
  var samples := []
  for sample in actor.seat_samples:
   var vertex: Vector3 = sample.vertex
   samples.append({"vertex": [vertex.x, vertex.y, vertex.z], "bindings": sample.bindings})
  actor_script.seat_profile_hashes.erase(path)
  if args.size() == 2:
   profiles[path] = {"sha256": FileAccess.get_sha256(path), "import_sha256": FileAccess.get_sha256(path + ".import"), "samples": samples}
   print("ACTIVITY_SEAT_REBUILT ", name, " samples=", samples.size())
   actor.free()
   continue
  actor.seat_samples.clear()
  actor.prepare_seat_samples()
  if not actor.get_meta("seat_profile_cached", false) or actor.seat_samples.size() != samples.size():
   push_error("Cached seat sample unavailable for " + path)
   quit(1)
   return
  for index in samples.size():
   var cached: Dictionary = actor.seat_samples[index]
   var expected: Dictionary = samples[index]
   var v: Array = expected.vertex
   if cached.vertex.distance_to(Vector3(v[0], v[1], v[2])) > .000001 or cached.bindings.size() != expected.bindings.size():
    actor.free()
    push_error("Cached seat vertex differs for " + path + " at " + str(index))
    quit(1)
    return
   for slot in cached.bindings.size():
    var left: Dictionary = cached.bindings[slot]
    var right: Dictionary = expected.bindings[slot]
    if int(left.bind) != int(right.bind) or absf(float(left.weight) - float(right.weight)) > .000001:
     actor.free()
     push_error("Cached seat weight differs for " + path + " at " + str(index))
     quit(1)
     return
  profiles[path] = {"sha256": FileAccess.get_sha256(path), "import_sha256": FileAccess.get_sha256(path + ".import"), "samples": samples}
  print("ACTIVITY_SEAT_PROFILE ", name, " samples=", samples.size(), " model_scene=", model.scene_file_path, " body_owner=", actor.seat_body.owner)
  actor.free()
 var file := FileAccess.open(args[0], FileAccess.WRITE)
 if file == null:
  push_error("Cannot write seat profile")
  quit(1)
  return
 file.store_string(JSON.stringify(profiles))
 file.close()
 quit()
