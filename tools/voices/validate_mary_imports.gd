extends SceneTree
## Exercise the actual project's Godot resource loader and imported streams.
func _initialize() -> void:
 var missing:Array[String]=[]
 var parts:Array[String]=[]
 for variant in 2:
  for kind in ["hello","farewell","collision","assault"]:parts.append("female_%s_%d"%[kind,variant])
  parts.append("pass_female_%d"%variant);parts.append("worker_female_%d"%variant)
  for kind in ["question","answer"]:parts.append("peer_female_%d_%s"%[variant,kind])
 for variant in range(1,5):
  parts.append("flirt_%d"%variant)
  parts.append("flirt_followup_%d"%variant)
 for part in parts:
  var path:="res://assets/audio/dialogue/context_mary_"+part+".wav"
  if not ResourceLoader.exists(path) or load(path)==null:missing.append(path)
 for variant in range(1,5):
  var path:="res://assets/audio/dialogue/context_arjun_mary_flirt_%d.wav"%variant
  if not ResourceLoader.exists(path) or load(path)==null:missing.append(path)
  var close_path:="res://assets/audio/dialogue/context_arjun_mary_flirt_close_%d.wav"%variant
  if not ResourceLoader.exists(close_path) or load(close_path)==null:missing.append(close_path)
 for variant in 2:
  var goodbye:="res://assets/audio/dialogue/context_mary_depart_%d.wav"%variant
  if not ResourceLoader.exists(goodbye) or load(goodbye)==null:missing.append(goodbye)
  var path:="res://assets/audio/dialogue/context_arjun_reply_%d.wav"%variant
  if not ResourceLoader.exists(path) or load(path)==null:missing.append(path)
 print("MARY RESOURCE IMPORT ","PASS" if missing.is_empty() else "FAIL", " missing=",missing)
 quit(0 if missing.is_empty() else 1)
