extends RefCounted
## Preserve the authored flat-floor ankle support while blending solved poses.
var skeleton: Skeleton3D
var base_y := 0.0
var support_y := 0.0
var feet: Array[int] = []
func setup(rig: Skeleton3D) -> void:
 skeleton = rig
 base_y = rig.position.y
 support_y = INF
 for name in ["foot_l", "foot_r"]:
  var index := rig.find_bone(name)
  if index >= 0:
   feet.append(index)
   support_y = minf(support_y, rig.get_bone_global_pose(index).origin.y)
func update() -> void:
 if skeleton == null or feet.is_empty(): return
 var lowest := INF
 for index in feet:
  lowest = minf(lowest, skeleton.get_bone_global_pose(index).origin.y)
 # Quaternion interpolation of bent leg chains can shorten their combined
 # reach at walk/idle blends. Translate the whole rig, keeping clothing and
 # attachments together; this does not solve terrain slopes or toe roll.
 skeleton.position.y = base_y + maxf(0.0, support_y - lowest)
