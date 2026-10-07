extends "res://horses/horse_vitality.gd"
## Shared damage/corpse policy with the cattle rig's own limb names.
func configure(owner_host:Node3D,visual:Node3D,anim:AnimationPlayer,centre:Vector3,side:=1.0) -> void:
 super.configure(owner_host,visual,anim,centre,side)
 hit_body.name="BullockHitBody";remove_from_group("horse_vitality");add_to_group("bullock_vitality")
 var body:CollisionShape3D=hit_body.get_child(0);body.position=centre+Vector3(0,.9,0);body.shape.size=Vector3(.65,.85,1.45)
 var head:CollisionShape3D=hit_body.get_child(1);head.position=centre+Vector3(0,.94,-1.3);head.shape.size=Vector3(.46,.65,.75)
func _fold_legs() -> void:
 var skeleton:Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
 for side in ["L","R"]:
  for entry in [["FrontUpper.",-.3],["FrontLower.",.9],["HindUpper.",.4],["HindLower.",-.8]]:
   var bone:=skeleton.find_bone(entry[0]+side)
   if bone<0:continue
   var start:=skeleton.get_bone_pose_rotation(bone)
   var axis:=skeleton.get_bone_global_pose(bone).basis.inverse()*Vector3.RIGHT
   var finish:=start*Quaternion(axis.normalized(),entry[1])
   var apply:=func(value:Quaternion):skeleton.set_bone_pose_rotation(bone,value)
   create_tween().tween_method(apply,start,finish,.8)
