extends "res://characters/npcs/households/household_npc_actor.gd"
## Authored doorway route; uses the reused actor's existing walk/idle tree.
var state := "waiting"
var route: Array[Vector3]=[]
var advice_blend := 0.0
var facial_expression=preload("res://story/dialogue_expression.gd").new()
func _ready() -> void:
	movement_enabled=false
	set_meta("external_combat_motion",true)
	super._ready()
func _configure_combat() -> void:
	super._configure_combat()
	if animation_tree==null:return
	var clip:=Animation.new();clip.length=3.6;clip.loop_mode=Animation.LOOP_LINEAR
	var paths:Array[NodePath]=[]
	for part in ["upperarm_r","lowerarm_r"]:
		var path:=NodePath(str(get_path_to(_skeleton))+":"+part);paths.append(path)
		var track:=clip.add_track(Animation.TYPE_ROTATION_3D);clip.track_set_path(track,path)
		for key in 25:
			var fraction:=float(key)/24
			var pitch:float=(-.38 if part=="upperarm_r" else -.85)+sin(fraction*TAU)*.08
			clip.rotation_track_insert_key(track,fraction*clip.length,_base_rotations[part]*Quaternion(_pitch_axes[part],pitch))
	animation_player.get_animation_library("").add_animation("chacha_advice",clip)
	var graph:=animation_tree.tree_root as AnimationNodeBlendTree
	var gesture:=AnimationNodeAnimation.new();gesture.animation=&"chacha_advice"
	graph.add_node("chacha_advice",gesture)
	var overlay:=AnimationNodeBlend2.new();overlay.filter_enabled=true
	for path in paths:overlay.set_filter_path(path,true)
	graph.add_node("advice_pose",overlay)
	graph.disconnect_node("output",0)
	graph.connect_node("advice_pose",0,"combat")
	graph.connect_node("advice_pose",1,"chacha_advice")
	graph.connect_node("output",0,"advice_pose")
	facial_expression.configure(self)
func _process(delta: float) -> void:
	if get_meta("dead",false) or get_meta("knocked_out",false):return
	var house: Node3D=get_parent()
	# The base actor calls this override from _ready, while the house is
	# still constructing its siblings. Wait without starting the route.
	var talk: Node3D=house.get_node_or_null("ChachaAdvice")
	var door: Node=house.get_node_or_null("EntranceDoor")
	if talk==null or door==null:
		travel_speed=0
		super._process(delta)
		return
	var player: CharacterBody3D=house.get_parent().get_node_or_null("Player")
	if player == null:super._process(delta);return
	if state in ["waiting","settled"] and talk.speaking:
		state="talking";route.clear()
	if state=="waiting" and not house.get_meta("advice_given",false) and player.global_position.distance_to(house.to_global(Vector3(0,1,9)))<4.5:
		state="approach";route.assign([Vector3(-.85,.2,6.3),Vector3(-1.2,.2,6.3)])
	if state=="approach" and player.global_position.distance_to(global_position)<2.8:
		talk.position=position+Vector3.UP;talk.interact(player)
		if talk.speaking:
			house.set_meta("advice_given",true);state="talking";route.clear()
	travel_speed=0
	if not route.is_empty():
		var crossing: bool=(position.z<5.13 and route[0].z>5.13) or (position.z>5.13 and route[0].z<5.13)
		if crossing and door.swing<.95:
			if not door.locked:door.set_open(true)
			super._process(delta);return
		var offset:=route[0]-position;offset.y=0
		if offset.length()<.06:route.pop_front()
		else:
			var step:=offset.normalized()*minf(offset.length(),1.1*delta)
			if not _patrol_body_blocked(step):
				position+=step
				# The veranda is at courtyard level; descend at the doorway.
				position.y=.2*(1.0-smoothstep(5.0,5.4,position.z))
				travel_speed=1.1
			rotation.y=lerp_angle(rotation.y,atan2(offset.x,offset.z),minf(delta*5,1))
	elif state=="approach":
		var toward:=player.global_position-global_position;toward.y=0
		rotation.y=atan2(toward.x,toward.z)
		if toward.length()<3:
			house.set_meta("advice_given",true)
			talk.interact(player)
			state="talking"
	elif state=="talking" and not talk.speaking:
		state="return";route.assign([Vector3(-.85,.2,1),Vector3(-3.5,.2,1),Vector3(-3.5,.2,3.3)])
	elif state=="return":state="settled"
	talk.position=position+Vector3.UP
	if state=="talking":
		var facing:=player.global_position-global_position
		rotation.y=lerp_angle(rotation.y,atan2(facing.x,facing.z),minf(delta*3,1))
	advice_blend=move_toward(advice_blend,1.0 if state=="talking" and talk.current_speaker=="Chacha" else 0.0,delta*3)
	facial_expression.apply(.65 if state=="talking" and talk.line<3 else .0,0)
	if animation_tree!=null and (animation_tree.tree_root as AnimationNodeBlendTree).has_node("advice_pose"):
		animation_tree.set("parameters/advice_pose/blend_amount",advice_blend)
	super._process(delta)
func _exit_tree() -> void:
	facial_expression.restore()
