extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var world:=load("res://world/suryagarh/suryagarh_world.tscn").instantiate() as Node3D;root.add_child(world);current_scene=world
 for frame in 25:await physics_frame
 var actor:Node3D=world.get_node("ErrandSystem").targets.office.person
 for node:Node3D in world.find_children("*","Node3D",true,false):
  var label:=String(node.name).to_lower()
  if node.global_position.distance_to(actor.global_position)>3:continue
  if "chair" in label or "seat" in label or "desk" in label or "table" in label:
   print("CLERK_FURNITURE ",node.get_path()," position=",node.global_position)
   if node is MeshInstance3D and node.mesh!=null:print("CLERK_FURNITURE_BOUNDS ",node.global_transform*node.mesh.get_aabb())
 quit()
