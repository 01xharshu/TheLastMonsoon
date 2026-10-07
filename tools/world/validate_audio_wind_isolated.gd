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
 for i in 60:audio.play_at('impact',Vector3.ZERO)
 assert(audio.voices.size()==24 and audio.events==24)
 for i in 600:wind._process(1.0/60.0)
 assert(wind.speed>1.0 and wind.speed<6.0)
 assert(wind.sample(Vector3.ZERO).length()>0)
 assert(wind.sample(Vector3.ZERO)!=wind.sample(Vector3(100,0,100)))
 print('ISOLATED AUDIO WIND: PASS | 25 valid streams | 24 voice cap | ramp and spatial gusts')
 preload('res://tools/test_audio_cleanup.gd').stop(root)
 await preload('res://tools/test_audio_cleanup.gd').settle(self)
 quit()
