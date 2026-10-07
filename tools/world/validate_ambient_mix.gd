extends SceneTree
## Lightweight ambience regression. Prints results without retaining test output.
var failures: Array[String]=[]
func _initialize() -> void:call_deferred('run')
func check(ok: bool,label: String) -> void:
 print(('PASS ' if ok else 'FAIL ')+label)
 if not ok:failures.append(label)
func run() -> void:
 var scene:=Node3D.new();root.add_child(scene);current_scene=scene
 var clock:=preload('res://world/suryagarh/systems/game_time_system.gd').new()
 clock.name='GameTimeSystem';scene.add_child(clock);clock.set_process(false)
 var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
 var light:=OmniLight3D.new();light.name='FireLight';scene.add_child(light)
 var tree:=MeshInstance3D.new();tree.name='MangoTree_Leaves';tree.mesh=BoxMesh.new();tree.position=Vector3(35,0,0);scene.add_child(tree)
 await process_frame
 var env: Node=root.get_node('WorldAudio/EnvironmentAudio')
 var audio: Node=root.get_node('WorldAudio');var wind: Node=root.get_node('WindSystem')
 env.set_process(false)
 var layout:=preload('res://world/suryagarh/landscape_layout.gd').new()
 wind.exposure=1
 env.tick(Vector3(0,2,0),8,.25)
 check(env.loops[0].playing and env.loops[0].volume_db==-3 and env.loops[0].unit_size==6,'nearby fire plays at corrected level')
 light.hide();env.tick(Vector3(0,2,0),8,.25)
 check(not env.loops[0].playing,'extinguished fire stops')
 env.tick(Vector3(layout.river_x(165),2,165),8,.25)
 check(env.river_voice.playing and env.river_voice.volume_db>=-3,'river bank plays at corrected level')
 env.tick(Vector3(-650,2,165),8,.25)
 check(not env.river_voice.playing,'river stops inland')
 env.bird_wait=0;env.tick(Vector3.ZERO,8,.25)
 check(int(env.emissions.get('sparrow',0))==1,'daytime canopy at 35 metres emits bird')
 var bird_voice: AudioStreamPlayer3D=audio.voices[0]
 check(bird_voice.max_distance==45 and bird_voice.unit_size==8 and bird_voice.volume_db==-3,'bird range matches scheduling radius')
 env.bird_wait=0;env.tick(Vector3.ZERO,2,.25)
 check(int(env.emissions.get('sparrow',0))==1,'night suppresses daytime birds')
 for voice in audio.voices:voice.stop()
 audio.play_at('impact',Vector3.ZERO)
 check(audio.voices[0].unit_size==1 and audio.voices[0].max_distance==28,'action voice restores its normal range')
 camera.position=Vector3(-650,2,165)
 for i in 120:wind._process(1.0/60)
 check(wind.ambience.volume_db>-25,'outdoor wind uses audible mix gain')
 camera.current=false;env._process(1)
 check(not env.river_voice.playing and not env.loops[0].playing,'missing listener retires environment loops')
 print('AMBIENT MIX: '+('PASS' if failures.is_empty() else 'FAIL'))
 preload('res://tools/test_audio_cleanup.gd').stop(root)
 await preload('res://tools/test_audio_cleanup.gd').settle(self)
 quit(0 if failures.is_empty() else 1)
