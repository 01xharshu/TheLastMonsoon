extends SceneTree
## Checks every generated production dialogue WAV currently visible to Godot.
func _initialize() -> void:
 var folder:="res://assets/audio/dialogue/"
 var missing:Array[String]=[]
 var checked:=0
 for name in DirAccess.get_files_at(folder):
  if not name.ends_with(".wav") or name.begins_with("audition_") or name.begins_with(".context-"):continue
  var path:=folder+name
  if not ResourceLoader.exists(path):missing.append(path);continue
  var stream:=load(path) as AudioStream
  if stream==null or stream.get_length()<=.2:missing.append(path)
  else:checked+=1
 print("AVAILABLE DIALOGUE RESOURCES ","PASS" if missing.is_empty() else "FAIL", " checked=",checked," missing=",missing)
 quit(0 if missing.is_empty() else 1)
