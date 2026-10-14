extends "res://tools/characters/audit_village_runtime_contact.gd"
func run() -> void:
 var woman=load("res://characters/npcs/indian/river_woman_study.gd").new()
 root.add_child(woman);woman.set_process(false)
 var rig:Skeleton3D=woman.skeleton
 print("RIVER_NATIVE_SKELETONS ",woman.find_children("*","Skeleton3D",true,false).size())
 for state in ["rest","walk"]:
  woman.animation_tree.active=state=="walk"
  if state=="rest":rig.reset_bone_poses()
  else:woman.sample(1.0)
  rig.force_update_all_bone_transforms()
  for name in ["head","hand_l","middle_01_l","middle_02_l","middle_03_l"]:
   var bone:int=rig.find_bone(name)
   print("RIVER_NATIVE_BONE ",state," ",name," position=",rig.get_bone_global_pose(bone).origin," scale=",rig.get_bone_global_pose(bone).basis.get_scale())
  for mesh:MeshInstance3D in woman.find_children("*","MeshInstance3D",true,false):
   if mesh.mesh==null:continue
   print("RIVER_NATIVE_MESH ",state," ",mesh.name," skeleton=",mesh.skeleton," skin=",mesh.skin!=null," parent=",mesh.get_parent().name," origin=",mesh.global_position," aabb=",mesh.get_aabb())
 woman.free();quit()
