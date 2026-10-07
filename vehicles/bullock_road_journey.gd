extends Node
## A short normal-road freight run, stopped by real clearance and player use.
var cart:Node3D
var route:Array[Vector2]=[Vector2(-416,230),Vector2(-386,230)]
var direction:=1
var wait:=0.0
var blocked_seconds:=0.0
func configure(vehicle:Node3D) -> void:cart=vehicle
func _physics_process(delta:float) -> void:
 if cart==null:return
 if cart.boarding.rider!=null or cart.has_meta("errand_cargo") or cart.has_meta("errand_transfer") or not cart.can_move():return
 if wait>0:
  wait-=delta;cart.boarding.speed=0;cart.set_forward_motion(0,delta);return
 var destination:=route[direction];var offset:=Vector2(destination.x-cart.global_position.x,destination.y-cart.global_position.z)
 if offset.length()<.3:direction=1-direction;wait=5;return
 var heading:=atan2(-offset.x,-offset.y)
 var old_yaw:=cart.rotation.y;cart.rotation.y=rotate_toward(cart.rotation.y,heading,delta*.22)
 if not cart.boarding._clearance_at(cart.global_position):cart.rotation.y=old_yaw;cart.set_forward_motion(0,delta);return
 var pace:=1.05 if absf(angle_difference(cart.rotation.y,heading))<.15 else 0.0
 var next:=cart.global_position-cart.global_basis.z*pace*delta
 var ray:=PhysicsRayQueryParameters3D.create(next+Vector3.UP*2,next-Vector3.UP*3,1,cart.boarding._vehicle_exclusions())
 var ground:=cart.get_world_3d().direct_space_state.intersect_ray(ray)
 if not ground.is_empty():next.y=ground.position.y
 if not ground.is_empty() and absf(next.y-cart.global_position.y)<.35 and cart.boarding._clearance_at(next):
  cart.global_position=next;cart.boarding.speed=pace;blocked_seconds=0
 else:cart.boarding.speed=0;blocked_seconds+=delta
 cart.set_forward_motion(cart.boarding.speed,delta)
