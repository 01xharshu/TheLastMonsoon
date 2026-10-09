extends "res://characters/npcs/indian/purpose_work_actor.gd"
## Stationary clerk desk routine. The fitted seat clip owns all body motion.
## Integration requires the matching chair height and source contact checks.
var seat_phase:=1.0
var seated_requested:=true
var seat_ready:=false
var seat_clock:=0.0
var seat_cloth:Dictionary={}
var seat_active_indices:Dictionary={}

func _ready() -> void:
 purpose_role="record_clerk"
 movement_enabled=false
 super._ready()
 if _skeleton==null or animation_tree==null:return
 if purpose_feet!=null:_skeleton.position.y=purpose_feet.base_y
 purpose_feet=null
 var clip:Animation
 for source:AnimationPlayer in find_children("*","AnimationPlayer",true,false):
  if source!=animation_player and source.has_animation("seat_entry"):
   clip=source.get_animation("seat_entry").duplicate(true);break
 if clip==null:
  push_error("Desk clerk requires its fitted seat_entry clip");return
 clip.loop_mode=Animation.LOOP_NONE
 for track in range(clip.get_track_count()-1,-1,-1):
  var bone:=String(clip.track_get_path(track).get_concatenated_subnames())
  if _skeleton.find_bone(bone)<0:clip.remove_track(track)
  else:clip.track_set_path(track,NodePath(str(get_path_to(_skeleton))+":"+bone))
 animation_player.get_animation_library("").add_animation("seat_entry",clip)
 var graph:=animation_tree.tree_root as AnimationNodeBlendTree
 var pose:=AnimationNodeAnimation.new();pose.animation=&"seat_entry"
 graph.add_node("seat_entry",pose);graph.add_node("seat_seek",AnimationNodeTimeSeek.new())
 graph.connect_node("seat_seek",0,"seat_entry")
 var observation:=AnimationNodeAnimation.new();observation.animation=&"idle"
 graph.add_node("desk_idle",observation)
 graph.add_node("desk_idle_seek",AnimationNodeTimeSeek.new());graph.connect_node("desk_idle_seek",0,"desk_idle")
 var head:=AnimationNodeBlend2.new();head.filter_enabled=true
 head.set_filter_path(NodePath(str(get_path_to(_skeleton))+":head"),true)
 graph.add_node("desk_observation",head)
 graph.connect_node("desk_observation",0,"seat_seek");graph.connect_node("desk_observation",1,"desk_idle_seek")
 graph.disconnect_node("output",0);graph.connect_node("output",0,"desk_observation")
 animation_tree.set("parameters/desk_observation/blend_amount",1.0)
 for mesh:MeshInstance3D in find_children("*","MeshInstance3D",true,false):
  if mesh.mesh==null:continue
  var indices:Array[int]=[]
  for index in mesh.mesh.get_blend_shape_count():
   if String(mesh.mesh.get_blend_shape_name(index)).begins_with("Seat cloth "):indices.append(index)
  if not indices.is_empty():
   seat_cloth[mesh]=indices;seat_active_indices[mesh]=[]
   for index in mesh.mesh.get_blend_shape_count():mesh.set_blend_shape_value(index,0.0)
 seat_ready=true
 _set_animation(&"idle",0.0)

func request_seated(value:bool) -> void:
 seated_requested=value

func _set_animation(state:StringName,delta:float) -> void:
 if not seat_ready:
  super._set_animation(state,delta);return
 seat_clock+=maxf(delta,0.0)
 seat_phase=move_toward(seat_phase,1.0 if seated_requested else 0.0,maxf(delta,0.0)/2.0)
 animation_state=&"seated" if seat_phase==1.0 else (&"standing" if seat_phase==0.0 else &"seat_transition")
 animation_tree.set("parameters/seat_seek/seek_request",seat_phase*animation_player.get_animation("seat_entry").length)
 animation_tree.set("parameters/desk_idle_seek/seek_request",fposmod(seat_clock,animation_player.get_animation("idle").length))
 animation_tree.advance(0.0)
 for mesh:MeshInstance3D in seat_cloth:
  var indices:Array[int]=seat_cloth[mesh]
  for index in seat_active_indices[mesh]:mesh.set_blend_shape_value(index,0.0)
  var sample:=seat_phase*float(indices.size()-1);var first:=mini(int(sample),indices.size()-1);var fraction:=sample-floorf(sample)
  mesh.set_blend_shape_value(indices[first],1.0-fraction)
  seat_active_indices[mesh]=[indices[first]]
  if first+1<indices.size():
   mesh.set_blend_shape_value(indices[first+1],fraction);seat_active_indices[mesh].append(indices[first+1])
 if body_collider!=null:
  var collision:=body_collider.get_node("BodyShape") as CollisionShape3D
  var shape:=collision.shape as CapsuleShape3D
  shape.height=lerpf(1.6,1.38,seat_phase)
  collision.position=Vector3(0,shape.height*.5,lerpf(.338,0.0,seat_phase))

func _configure_combat() -> void:
 super._configure_combat()
 if not seat_ready or animation_tree==null:return
 # The shared deferred combat setup chooses the generic locomotion branch.
 # Preserve the desk branch as its normal pose while retaining reactions.
 var graph:=animation_tree.tree_root as AnimationNodeBlendTree
 graph.disconnect_node("combat",0)
 graph.connect_node("combat",0,"desk_observation")
