extends SceneTree
## Rebuild production low-detail mango from its retained original GLB.
func _initialize() -> void:
 var mesh:Mesh=preload("res://world/suryagarh/tree_variety.gd").mesh_for("mango",true)
 DirAccess.make_dir_recursive_absolute("res://environment/vegetation/world_palette")
 var error:=ResourceSaver.save(mesh,"res://environment/vegetation/world_palette/mango.res")
 print("WORLD TREE PALETTE BUILD ",error)
 quit(error)
