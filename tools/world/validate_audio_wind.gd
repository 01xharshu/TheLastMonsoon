extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:call_deferred('run')
func check(ok: bool, label: String) -> void:
 print(('PASS ' if ok else 'FAIL ')+label)
 if not ok:failures.append(label)
func run() -> void:
 var world: Node3D=load('res://world/suryagarh/suryagarh_world.tscn').instantiate()
 root.add_child(world);current_scene=world
 for i in 45:await physics_frame
 var audio: Node=root.get_node('WorldAudio')
 var wind: Node=root.get_node('WindSystem')
 check(audio.streams.size()==25,'all generated sound assets load')
 check(audio.tracked.size()>0,'live player movement registered')
 check(audio.npc_tracks.size()>0,'live NPC movement registered')
 var actor: CharacterBody3D=world.get_node('Player')
 var before: int=audio.events
 audio.play_at('impact',actor.global_position)
 check(audio.events==before+1,'spatial sound dispatch')
 for i in 40:audio.play_at('cloth',actor.global_position)
 check(audio.voices.size()==24,'voices bounded under burst')
 for i in 120:await physics_frame
 check(wind.speed>0.0 and wind.speed<6.0,'wind ramps within safe range')
 check(wind.sample(Vector3.ZERO).length()>0.0,'world wind sample drives cloth')
 check(get_nodes_in_group('wind_flags').size()>0,'live flags registered')
 check(wind.ambience.playing,'wind loop active')
 preload('res://tools/test_audio_cleanup.gd').stop(root)
 await preload('res://tools/test_audio_cleanup.gd').settle(self)
 print('AUDIO WIND: '+('PASS' if failures.is_empty() else 'FAIL'))
 quit(0 if failures.is_empty() else 1)
