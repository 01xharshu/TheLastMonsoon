extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:call_deferred('run')
func check(ok: bool,label: String) -> void:
 print(('PASS ' if ok else 'FAIL ')+label)
 if not ok:failures.append(label)
func run() -> void:
 var world:=Node3D.new();root.add_child(world);current_scene=world
 var audio: Node=root.get_node('WorldAudio')
 var env: Node=audio.get_node('EnvironmentAudio');env.set_process(false)
 var wind: Node=root.get_node('WindSystem');wind.set_process(false);wind.exposure=1.0
 var fire:=OmniLight3D.new();fire.name='FireLight';world.add_child(fire)
 var tree:=MeshInstance3D.new();tree.name='MangoTree_Leaves';tree.mesh=BoxMesh.new();world.add_child(tree)
 await process_frame
 for key in env.clips:check(env.clips[key].data.size()>0,'recorded '+str(key)+' loads')
 env.tick(Vector3.UP,20,.25)
 check(env.loops[0].playing,'nearby lit fire starts')
 fire.light_energy=0;env.tick(Vector3.UP,20,.25)
 check(not env.loops[0].playing,'extinguished fire stops')
 fire.light_energy=1;env.tick(Vector3(500,10,500),20,.25)
 check(not env.loops[0].playing,'remote fire retires')
 var layout:=preload('res://world/suryagarh/landscape_layout.gd').new()
 env.tick(Vector3(layout.river_x(165),2,165),12,.25)
 check(env.river_voice.playing,'near river starts recorded water')
 env.tick(Vector3(-650,8,165),12,.25)
 check(not env.river_voice.playing,'inland river retires')
 for voice in audio.voices:voice.stop()
 env.bird_wait=0;var before: int=int(env.emissions.get('sparrow',0))
 env.tick(Vector3(10,0,0),2,.25)
 check(int(env.emissions.get('sparrow',0))==before,'night excludes daytime bird calls')
 env.bird_wait=0;env.tick(Vector3(10,0,0),8,.25)
 check(int(env.emissions.get('sparrow',0))==before+1,'daylight canopy emits recorded bird')
 fire.light_energy=1;env.tick(Vector3.UP,20,.25)
 env.timer=0;env._process(.25)
 check(not env.loops[0].playing and not env.river_voice.playing,'missing camera retires environment loops')
 var camera:=Camera3D.new();world.add_child(camera);camera.current=true
 env.tick(Vector3.UP,20,.25);env.timer=0;env._process(.25)
 check(not env.loops[0].playing and not env.river_voice.playing,'scene without game clock retires environment loops')
 check(env.loops.size()==8 and audio.voices.size()==24,'environment and action caps remain bounded')
 preload('res://tools/test_audio_cleanup.gd').stop(root)
 await preload('res://tools/test_audio_cleanup.gd').settle(self)
 print('ISOLATED ENVIRONMENT AUDIO: '+('PASS' if failures.is_empty() else 'FAIL'))
 quit(0 if failures.is_empty() else 1)
