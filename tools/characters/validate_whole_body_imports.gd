extends SceneTree
func _initialize() -> void:
 var audit:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/characters/npcs/whole_body_runtime_audit.json"))
 var errors:Array=[]
 var checked:=0
 for record in audit.assets:
  var scene:=load("res://"+record.path) as PackedScene
  if scene==null:errors.append(record.path+": import missing");continue
  var actor:=scene.instantiate()
  for body in record.body:
   var found:=false
   for node in actor.find_children("*","MeshInstance3D",true,false):
    if String(node.name)==body.node:
     found=true
     var count:=0
     for surface in node.mesh.get_surface_count():count+=node.mesh.surface_get_array_len(surface)
     if count<int(body.vertices):errors.append(record.path+": imported body vertex loss")
   if not found:errors.append(record.path+": body node missing "+body.node)
  actor.free();checked+=1
 var report:Dictionary={"scope":"actual Godot imported body presence and vertex retention; no rendering/cloth approval","assets_checked":checked,"errors":errors,"passed":errors.is_empty()}
 var file:=FileAccess.open("res://docs/characters/npcs/whole_body_import_validation.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t")+"\n")
 print("WHOLE_BODY_IMPORT ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
