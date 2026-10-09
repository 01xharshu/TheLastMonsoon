extends "res://characters/npcs/households/household_npc_actor.gd"
## Work NPC uses its original baked gait and pose-fitted clothes together.
@export_enum("dock_porter","boatman","record_clerk") var purpose_role:String="record_clerk"
var purpose_cloth:Array[MeshInstance3D]=[]
var purpose_walk_indices:Dictionary={}
var purpose_phase:=0.0
var purpose_feet:RefCounted

func _ready() -> void:
 household_job=purpose_role
 foot_plant_enabled=false
 for mesh in find_children("*","MeshInstance3D",true,false):
  if mesh.mesh==null:continue
  var indices:Array[int]=[]
  for index in mesh.mesh.get_blend_shape_count():
   if String(mesh.mesh.get_blend_shape_name(index)).begins_with("Walk cloth "):indices.append(index)
  if not indices.is_empty():
   purpose_cloth.append(mesh);purpose_walk_indices[mesh]=indices
 super._ready()
 purpose_feet=preload("res://characters/npcs/indian/purpose_foot_contact.gd").new()
 purpose_feet.setup(_skeleton)
 if animation_tree!=null:
  var graph:=animation_tree.tree_root as AnimationNodeBlendTree
  graph.get_node("locomotion").set("sync",true)
  graph.get_node("turning").set("sync",true)
 set_meta("purpose_role",purpose_role)
 set_meta("complete_body_retained",true)

func _make_clip(walking:bool,turning:bool=false) -> Animation:
 if turning:return super._make_clip(walking,turning)
 var name:StringName=&"walk" if walking else &"idle"
 for source in find_children("*","AnimationPlayer",true,false):
  if source==animation_player or not source.has_animation(name):continue
  var clip:Animation=source.get_animation(name).duplicate(true)
  clip.loop_mode=Animation.LOOP_LINEAR
  for track in range(clip.get_track_count()-1,-1,-1):
   var original:NodePath=clip.track_get_path(track)
   var bone:=String(original.get_concatenated_subnames())
   if _skeleton.find_bone(bone)<0:clip.remove_track(track)
   else:clip.track_set_path(track,NodePath(str(get_path_to(_skeleton))+":"+bone))
  if not walking:clip=preload("res://characters/npcs/indian/purpose_role_idle.gd").build(clip,purpose_role,_skeleton,get_path_to(_skeleton))
  return clip
 push_error("Purpose actor missing authored clip: "+purpose_role+" "+String(name))
 return super._make_clip(walking,turning)

func _measure_stride(_clip:Animation) -> void:
 nominal_walk_speed={"dock_porter":.40,"boatman":.44,"record_clerk":.28}[purpose_role]/.72

func _set_animation(state:StringName,delta:float) -> void:
 super._set_animation(state,delta)
 if purpose_feet!=null:purpose_feet.update()
 if animation_player==null:return
 purpose_phase+=maxf(delta,0.0)*walk_playback_rate/animation_player.get_animation("walk").length
 if purpose_cloth.is_empty():return
 for mesh in purpose_cloth:
  var indices:Array[int]=purpose_walk_indices[mesh]
  var samples:int=indices.size()
  var phase:=fposmod(purpose_phase,1.0)*float(samples)
  var first:int=int(floorf(phase))%samples
  var fraction:float=phase-floorf(phase)
  for index in samples:
   var weight:float=1.0-fraction if index==first else fraction if index==(first+1)%samples else 0.0
   mesh.set_blend_shape_value(indices[index],weight*locomotion_blend*(1.0-turn_blend))
