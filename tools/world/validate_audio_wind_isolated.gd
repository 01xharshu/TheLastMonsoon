extends SceneTree
func _initialize() -> void:call_deferred('run')
func run() -> void:
 await process_frame
 var audio: Node=root.get_node('WorldAudio')
 var wind: Node=root.get_node('WindSystem')
 assert(audio.streams.size()==25)
 for stream in audio.streams.values():assert(stream!=null and stream.data.size()>0)
 assert(audio.step_variants.step_wood.size()==3 and audio.step_variants.step_dirt.size()==2)
 for variants in audio.step_variants.values():
  for clip in variants:assert(clip.data.size()>0)
 assert(not audio.play_at('missing_clip',Vector3.ZERO))
 for i in 60:audio.play_at('impact',Vector3.ZERO)
 assert(audio.voices.size()==24 and audio.events==24)
 assert(not audio.play_at('impact',Vector3.ZERO))
 var env: Node=audio.get_node('EnvironmentAudio')
 var before: int=int(env.emissions.get('sparrow',0))
 env.emit('sparrow',Vector3.ZERO,-3)
 assert(int(env.emissions.get('sparrow',0))==before)
 var stone:=StaticBody3D.new();stone.name='GenericFloor';stone.set_meta('audio_surface','stone');root.add_child(stone)
 var child:=Node.new();stone.add_child(child)
 assert(audio.surface_key(child)=='step_stone')
 stone.queue_free()
 for i in 600:wind._process(1.0/60.0)
 assert(wind.speed>1.0 and wind.speed<6.0)
 assert(wind.sample(Vector3.ZERO).length()>0)
 assert(wind.sample(Vector3.ZERO)!=wind.sample(Vector3(100,0,100)))
 var flag: Node3D=preload('res://assets/props/flags/eic/prop_eic_checkpoint_flag_01.glb').instantiate()
 root.add_child(flag);flag.position=Vector3(13,0,22);flag.add_to_group('wind_flag_roots');flag.rotation.y=2.0
 var base:=flag.global_position
 var animator: AnimationPlayer=flag.find_children('*','AnimationPlayer',true,false)[0]
 var clip: String='wind' if animator.has_animation('wind') else 'wind_loop'
 animator.add_to_group('wind_flags');animator.play(clip)
 for i in 500:wind._process(.1)
 assert(flag.global_basis.x.normalized().dot(wind.sample(flag.global_position).normalized())>.99)
 assert(flag.global_position.is_equal_approx(base))
 assert(animator.is_playing())
 assert(is_equal_approx(animator.speed_scale,clampf(wind.sample(flag.global_position).length()/2.5,.15,1.8)))
 print('PASS actual flag alignment, grounded pole and gust-driven flutter without camera')
 print('ISOLATED AUDIO WIND: PASS | 25 valid streams | 24 voice cap | ramp and spatial gusts')
 preload('res://tools/test_audio_cleanup.gd').stop(root)
 await preload('res://tools/test_audio_cleanup.gd').settle(self)
 quit()
