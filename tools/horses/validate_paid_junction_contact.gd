extends SceneTree
## Reproduce the discovered main-road carriage contact using actual baked ground.
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene:=Node3D.new();scene.name="Suryagarh";root.add_child(scene);current_scene=scene
 scene.add_child(load("res://world/suryagarh/generated/landscape.scn").instantiate())
 var cart:=preload("res://vehicles/family_carriage_candidate.gd").new()
 cart.position=Vector3(-215.4789,5.491167,-27.15531);cart.rotation.y=.37348812818527;scene.add_child(cart)
 for i in 3:await physics_frame
 var next_basis:Basis=Basis(Vector3.UP,-.0003333333)*cart.global_basis
 var at:Vector3=cart.global_position-next_basis.z*(5.0/60.0/60.0)
 var space:=scene.get_world_3d().direct_space_state
 var road:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*2,at-Vector3.UP*3,1)
 road.exclude=cart.boarding._vehicle_exclusions()
 var ground:=space.intersect_ray(road)
 var contacts:Array=[]
 if not ground.is_empty():
  for shape in cart.boarding.clearance_shapes:
   var query:=PhysicsShapeQueryParameters3D.new()
   query.shape=shape.shape;query.transform=Transform3D(next_basis,Vector3(at.x,ground.position.y,at.z)+next_basis*shape.position)
   query.exclude=cart.boarding._vehicle_exclusions();query.collision_mask=1
   for hit in space.intersect_shape(query,8):contacts.append({"shape_center":str(shape.position),"shape_size":str(shape.shape.size),"collider":str(hit.collider.get_path())})
 var report:Dictionary={"blocked":not contacts.is_empty(),"ground_y":ground.get("position",Vector3.INF).y,"cart_at":str(cart.global_position),"contacts":contacts,"scope":"actual carriage movement-clearance shapes and saved terrain at failed paid-road junction; no collision bypass"}
 FileAccess.open("res://docs/world/ordered_paid_junction_contact.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("PAID JUNCTION CONTACT ",JSON.stringify(report));quit()
