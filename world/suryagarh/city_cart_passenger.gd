extends Node
## A complete MPFB resident rides an occupied socket on existing live traffic.
var cart:Node3D
var actor:Node3D
var socket:Node3D
var age:=0.0
var viewer:Node3D
func _ready()->void:
 actor.set_process(false)
 # Layer 2 remains solid to the player's all-world mask without the cart's
 # own layer-1 clearance probe detecting a passenger inside itself.
 actor.body_collider.collision_layer=2;actor.body_collider.collision_mask=0
 actor.body_collider.get_node("BodyShape").shape.height=1.1
 actor.body_collider.get_node("BodyShape").position.y=.55
 actor.add_to_group("city_cart_passengers")
func _physics_process(delta:float)->void:
 if actor.get_meta("dead",false) or actor.get_meta("knocked_out",false):return
 age+=delta
 var far:=is_instance_valid(viewer) and cart.global_position.distance_squared_to(viewer.global_position)>22500
 if far and age<.5:return
 var step:=age;age=0
 actor._set_animation(&"idle",step)
 var rig:Skeleton3D=actor._skeleton
 for side in ["l","r"]:
  for entry in [["thigh_",-1.5],["calf_",1.5],["foot_",0.0]]:
   var bone:String=entry[0]+side
   rig.set_bone_pose_rotation(rig.find_bone(bone),actor._base_rotations[bone]*Quaternion(actor._pitch_axes[bone],entry[1]))
 actor.global_rotation.y=socket.global_rotation.y+PI
 var pelvis:Vector3=rig.to_global(rig.get_bone_global_pose(rig.find_bone("pelvis")).origin)
 actor.global_position+=socket.global_position+Vector3.UP*.11-pelvis
 for side in ["l","r"]:
  var at:Vector3=cart.to_local(socket.global_position)+Vector3(-.18 if side=="l" else .18,0,-.55)
  at.y=1.369 if cart.has_method("show_coachman_blockout") else 1.13
  if cart.get_meta("public_passenger_service",false):at.y=1.185
  actor.foot_plant._solve(actor.foot_plant.legs[side],rig.to_local(cart.to_global(at)))
  actor.solve_hand_contact(side,socket.to_global(Vector3(-.18 if side=="l" else .18,.15,-.25)))
 if actor.drape!=null:actor.drape.update()
 actor.body_collider.force_update_transform()
