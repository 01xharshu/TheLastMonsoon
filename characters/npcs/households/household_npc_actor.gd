extends "res://characters/npcs/british/british_npc_actor.gd"
## Personal work branch overlays arms while retaining independent locomotion.
@export var household_job:String="resident"
func _ready() -> void:
	super._ready()
	if household_job not in ["Cook","WaterBearer"] or animation_tree==null:return
	var clip:=Animation.new();clip.length=2.8;clip.loop_mode=Animation.LOOP_LINEAR
	var skeleton_path:=str(get_path_to(_skeleton))
	var paths:Array[NodePath]=[]
	for side in ["l","r"]:
		for part in ["upperarm_","lowerarm_"]:
			var bone:String=part+side
			var path:=NodePath(skeleton_path+":"+bone);paths.append(path)
			var track:=clip.add_track(Animation.TYPE_ROTATION_3D);clip.track_set_path(track,path)
			for key in 17:
				var fraction:=float(key)/16
				var pitch:float=-.50 if part=="upperarm_" else -.9
				if household_job=="Cook":pitch+=sin(fraction*TAU)*.10
				clip.rotation_track_insert_key(track,fraction*clip.length,_base_rotations[bone]*Quaternion(_pitch_axes[bone],pitch))
	animation_player.get_animation_library("").add_animation("household_work",clip)
	var graph:=animation_tree.tree_root as AnimationNodeBlendTree
	var work:=AnimationNodeAnimation.new();work.animation=&"household_work"
	graph.add_node("household_work",work)
	var overlay:=AnimationNodeBlend2.new();overlay.filter_enabled=true
	for path in paths:overlay.set_filter_path(path,true)
	graph.add_node("work_pose",overlay)
	graph.disconnect_node("output",0)
	graph.connect_node("work_pose",0,"turning")
	graph.connect_node("work_pose",1,"household_work")
	graph.connect_node("output",0,"work_pose")
	animation_tree.set("parameters/work_pose/blend_amount",1.0)
	animation_tree.advance(0.0)

func _process(delta:float) -> void:
	super._process(delta)
	if household_job=="WaterBearer" and _skeleton!=null:
		var pot:=get_node_or_null("CarriedWaterPot") as Node3D
		if pot!=null:
			var left:=_skeleton.find_bone("hand_l");var right:=_skeleton.find_bone("hand_r")
			var palms:=(_skeleton.get_bone_global_pose(left).origin+_skeleton.get_bone_global_pose(right).origin)*.5
			pot.position=to_local(_skeleton.to_global(palms))+Vector3(0,-.11,0)
