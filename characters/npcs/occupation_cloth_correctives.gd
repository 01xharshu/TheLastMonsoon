extends RefCounted
## Pose-driven binding for the fitted occupation candidate; no body changes.
## Inactive on existing outfits that do not carry these authored morph names.
var actor: Node3D
var entries: Array[Dictionary] = []

func setup(owner_actor: Node3D) -> void:
 actor=owner_actor
 entries.clear()
 for mesh:MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
  if not mesh.mesh is ArrayMesh:continue
  var seated:=mesh.find_blend_shape_by_name("Study seated correction")
  var walk:=mesh.find_blend_shape_by_name("Study walk correction")
  if seated<0:seated=mesh.find_blend_shape_by_name("Study seated foundation")
  if walk<0:walk=mesh.find_blend_shape_by_name("Study walk foundation")
  var reverse := mesh.find_blend_shape_by_name("Study reverse walk correction")
  if reverse < 0:reverse=mesh.find_blend_shape_by_name("Study reverse walk foundation")
  var sit := mesh.find_blend_shape_by_name("Study sit midpoint correction")
  if sit < 0:sit=mesh.find_blend_shape_by_name("Study sit midpoint foundation")
  var rise := mesh.find_blend_shape_by_name("Study rise midpoint correction")
  if rise < 0:rise=mesh.find_blend_shape_by_name("Study rise midpoint foundation")
  var refinements: Array[Dictionary] = []
  for index in mesh.mesh.get_blend_shape_count():
   var tokens := str(mesh.mesh.get_blend_shape_name(index)).split(" ")
   if tokens.size()<4 or tokens[0]!="Study" or not tokens[2].is_valid_int():continue
   if tokens[1] in ["sit","rise","repair-entry"]:
    refinements.append({"key":index,"mode":tokens[1],"center":float(tokens[2])/1000.0})
   elif tokens[1]=="gait" and tokens.size()==5 and tokens[3].is_valid_int():
    refinements.append({"key":index,"mode":"gait","center":float(tokens[2])/100000.0,"blend":float(tokens[3])/1000.0})
  if seated>=0 or walk>=0 or reverse>=0 or sit>=0 or rise>=0 or not refinements.is_empty():
   entries.append({"mesh":mesh,"seated":seated,"walk":walk,"reverse":reverse,"sit":sit,"rise":rise,"refinements":refinements})

func pitch(bone_name: String) -> float:
 var rig:Skeleton3D=actor._skeleton
 var index:=rig.find_bone(bone_name)
 if index<0 or not actor._pitch_axes.has(bone_name):return 0.0
 var base:Quaternion=actor._base_rotations.get(bone_name,Quaternion.IDENTITY)
 var relative:Quaternion=base.inverse()*rig.get_bone_pose_rotation(index)
 if relative.w<0:relative=-relative
 var axis:Vector3=actor._pitch_axes[bone_name]
 return 2.0*atan2(Vector3(relative.x,relative.y,relative.z).dot(axis),relative.w)

func update() -> void:
 if entries.is_empty():return
 # Ordinary gait bends a calf too; require both hips to fold into sitting.
 var seated:=clampf(-(pitch("thigh_l")+pitch("thigh_r"))/2.7,0.0,1.0)
 var stride := (pitch("thigh_l")-pitch("thigh_r"))/.60
 var walking := clampf(stride,0.0,1.0)*(1.0-seated)
 var reverse_walking := clampf(-stride,0.0,1.0)*(1.0-seated)
 var age: float = actor.activity_age
 var phase_weight := clampf(minf(age / .32, (.65 - age) / .33), 0.0, 1.0)
 var working_seated: bool = actor.activity in actor.SEATED_WORK
 var sit_weight := phase_weight if working_seated and not actor.retained_seat_support else 0.0
 var rise_weight := phase_weight if not working_seated and seated > .01 else 0.0
 for entry in entries:
  if entry.seated>=0:entry.mesh.set_blend_shape_value(entry.seated,seated)
  if entry.walk>=0:entry.mesh.set_blend_shape_value(entry.walk,walking)
  if entry.reverse>=0:entry.mesh.set_blend_shape_value(entry.reverse,reverse_walking)
  if entry.sit>=0:entry.mesh.set_blend_shape_value(entry.sit,sit_weight)
  if entry.rise>=0:entry.mesh.set_blend_shape_value(entry.rise,rise_weight)
  for correction in entry.refinements:
   var weight := 0.0
   match correction.mode:
    "sit":
     if working_seated and not actor.retained_seat_support:
      weight=clampf(1.0-absf(age-correction.center)/.08,0.0,1.0)
    "repair-entry":
     if actor.activity==&"repair" and not actor.retained_seat_support:
      weight=clampf(1.0-absf(age-correction.center)*30.0,0.0,1.0)
    "rise":
     if actor.rising_from_seat and age<.65:
      weight=clampf(1.0-absf(age-correction.center)/.08,0.0,1.0)
    "gait":
     if actor.animation_state==&"walk":
      var difference:=absf(wrapf(actor._walk_phase-correction.center,-.5,.5))
      var phase_width:float=.08/actor.animation_player.get_animation("walk").length
      weight=clampf(1.0-difference/phase_width,0.0,1.0)*clampf(1.0-absf(actor.locomotion_blend-correction.blend)/.2,0.0,1.0)
   entry.mesh.set_blend_shape_value(correction.key,weight)
