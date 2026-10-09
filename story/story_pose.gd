extends RefCounted
## Authored MPFB skeleton poses layered over the existing player AnimationTree.
var tree: AnimationTree
var node: AnimationNodeAnimation
var weight:=0.0
func configure(visual: Node3D) -> void:
 tree=visual.motion_tree
 var source: AnimationPlayer=tree.get_node(tree.anim_player)
 var library:=AnimationLibrary.new()
 var shapes: Dictionary={
  "collar":{"upperarm_l":Vector3(-1.35,0,.15),"upperarm_r":Vector3(-1.35,0,-.15),"lowerarm_l":Vector3(-.7,0,0),"lowerarm_r":Vector3(-.7,0,0),"spine_02":Vector3(.13,0,0)},
  "pain":{"spine_01":Vector3(.22,0,.08),"head":Vector3(.16,0,0),"upperarm_l":Vector3(-.5,0,.3),"lowerarm_l":Vector3(-1.7,0,0),"upperarm_r":Vector3(-.3,0,-.12)},
  "drink":{"upperarm_r":Vector3(-1.8,0,-.15),"lowerarm_r":Vector3(-1.5,0,0),"head":Vector3(-.10,0,0)},
  "down":{"pelvis":Vector3(-PI/2,0,0),"spine_02":Vector3(-.10,0,0),"thigh_l":Vector3(-.25,0,0),"thigh_r":Vector3(-.15,0,0),"calf_l":Vector3(.4,0,0),"calf_r":Vector3(.3,0,0),"upperarm_l":Vector3(.1,0,.4),"upperarm_r":Vector3(.1,0,-.4)}}
 for action: String in shapes:
  var clip:=Animation.new();clip.length=2;clip.loop_mode=Animation.LOOP_LINEAR
  for bone: String in shapes[action]:
   if not visual.bones.has(bone):continue
   var path:=NodePath(str(source.get_node(source.root_node).get_path_to(visual.skeleton))+":"+bone)
   var track:=clip.add_track(Animation.TYPE_ROTATION_3D);clip.track_set_path(track,path)
   var angles: Vector3=shapes[action][bone];var axes: Basis=visual.axes[bone]
   for k in 9:
    var pulse:=sin(float(k)/8*TAU)*.015 if action in ["pain","drink"] else 0.0
    var rotation: Quaternion=visual.base_rotations[bone]*Quaternion(axes*Vector3.RIGHT,angles.x+pulse)*Quaternion(axes*Vector3.UP,angles.y)*Quaternion(axes*Vector3.BACK,angles.z)
    clip.rotation_track_insert_key(track,float(k)/4,rotation)
   if bone=="pelvis" and action=="down":
    var i: int=visual.bones[bone];var parent: int=visual.skeleton.get_bone_parent(i)
    var axis: Vector3=visual.skeleton.get_bone_global_rest(parent).basis.inverse()*Vector3.DOWN
    var pos:=clip.add_track(Animation.TYPE_POSITION_3D);clip.track_set_path(pos,path)
    var value: Vector3=visual.skeleton.get_bone_pose_position(i)+axis*.72
    clip.position_track_insert_key(pos,0,value);clip.position_track_insert_key(pos,2,value)
  library.add_animation(action,clip)
 source.add_animation_library("story",library)
 var graph:=tree.tree_root as AnimationNodeBlendTree
 var previous: StringName=&""
 var connections: Array=graph.get("node_connections")
 for index in range(0,connections.size(),3):
  if connections[index]==&"output":previous=connections[index+2]
 if previous==&"":push_error("Story pose needs player output connection");return
 node=AnimationNodeAnimation.new();node.animation=&"story/pain";graph.add_node("story_animation",node)
 var blend:=AnimationNodeBlend2.new();blend.filter_enabled=true
 for action in shapes:
  var clip: Animation=library.get_animation(action)
  for track in clip.get_track_count():blend.set_filter_path(clip.track_get_path(track),true)
 graph.add_node("story_pose",blend);graph.disconnect_node("output",0)
 graph.connect_node("story_pose",0,previous);graph.connect_node("story_pose",1,"story_animation");graph.connect_node("output",0,"story_pose")
 tree.set("parameters/story_pose/blend_amount",0.0)
func apply(action: String,amount: float,delta: float) -> void:
 if node==null:return
 if not action.is_empty():node.animation=StringName("story/"+action)
 weight=move_toward(weight,amount,delta*3)
 tree.set("parameters/story_pose/blend_amount",weight)
