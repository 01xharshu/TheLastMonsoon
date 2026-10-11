extends SceneTree
## Collision-only physics fixture; no human or visual assets are constructed.
const Recovery=preload("res://world/suryagarh/city_contact_recovery.gd")
func _initialize() -> void:call_deferred("run")
func shape(body:Node3D,size:Vector3,at:Vector3) -> void:
 var collision:=CollisionShape3D.new();var box:=BoxShape3D.new()
 box.size=size;collision.shape=box;collision.position=at;body.add_child(collision)
func run() -> void:
 var world:=Node3D.new();root.add_child(world)
 var floor:=StaticBody3D.new();floor.name="GroundCollision";world.add_child(floor)
 shape(floor,Vector3(20,.1,20),Vector3(0,-.05,0))
 var wall:=StaticBody3D.new();world.add_child(wall);shape(wall,Vector3(1,2,2),Vector3(0,1,0))
 var actor:=Node3D.new();world.add_child(actor);actor.position=Vector3(.7,0,0)
 var body:=AnimatableBody3D.new();body.sync_to_physics=false;actor.add_child(body)
 var collision:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new()
 capsule.radius=.3;capsule.height=1.5;collision.shape=capsule;collision.position.y=.75;body.add_child(collision)
 for frame in 4:await physics_frame
 # Vehicle helpers can return a generic Array containing RID values.
 var generic_exclusions:Array=[floor.get_rid()]
 var recovered:=Recovery.recover(actor,body,generic_exclusions)
 assert(recovered>0 and recovered<.45,"existing contact did not recover")
 assert(absf(actor.position.y)<.001,"ground support changed")
 for frame in 2:await physics_frame
 assert(Recovery.recover(actor,body)<.0001,"clear pose kept moving")
 assert(body.collision_layer==1 and body.collision_mask==1,"collision disabled")
 actor.position=Vector3(10.7,0,0);wall.position.x=10;body.force_update_transform()
 for frame in 2:await physics_frame
 assert(Recovery.recover(actor,body)==0,"recovery left supported ground")
 assert(is_equal_approx(actor.position.x,10.7),"unsupported pose was applied")
 print("CITY CONTACT RECOVERY PASS: bounded separation, stable ground, collision retained, unsupported target rejected")
 quit()
