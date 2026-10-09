extends SceneTree
var failures: Array[String]=[]
var evidence: Dictionary={}
func _initialize() -> void:call_deferred('run')
func check(ok: bool,label: String) -> void:
 print(('PASS ' if ok else 'FAIL ')+label);evidence[label]=ok
 if not ok:failures.append(label)
func playing(players: Array) -> int:
 var count:=0
 for voice in players:
  if voice.playing:count+=1
 return count
func silence(audio: Node) -> void:
 for voice in audio.voices:voice.stop()
func run() -> void:
 var world: Node3D=load('res://world/suryagarh/suryagarh_world.tscn').instantiate();root.add_child(world);current_scene=world
 for i in 50:await physics_frame
 var audio: Node=root.get_node('WorldAudio');var env: Node=audio.get_node('EnvironmentAudio');var wind: Node=root.get_node('WindSystem')
 env.set_process(false)
 check(audio.streams.size()==25,'25 cached action types plus six recorded footstep variants')
 for key in env.clips:check(env.clips[key].data.size()>0,'recording '+str(key)+' loads')
 check(env.loops.size()==8,'environment loops capped at eight')
 check(env.loops[0].volume_db>=-6 and env.loops[0].unit_size>=6,'fire mix retains near-field audibility')
 var lights:=get_nodes_in_group('village_gathering_fire')
 check(not lights.is_empty(),'live gathering fire sources exist')
 var fire: Node3D=lights[0]
 var light: OmniLight3D=fire.get_node('FireLight')
 var was_visible:=light.visible
 light.show();env.tick(fire.global_position+Vector3.UP,20,.25)
 check(playing(env.loops)>0,'lit nearby fire audible')
 light.hide();env.tick(fire.global_position+Vector3.UP,20,.25)
 check(playing(env.loops)==0,'extinguished nearby fire silent')
 light.visible=was_visible
 env.tick(Vector3(0,20,-700),12,.25)
 check(playing(env.loops)==0,'remote fire voices retire')
 var layout:=preload('res://world/suryagarh/landscape_layout.gd').new()
 var river_at:=Vector3(layout.river_x(165),2,165)
 env.tick(river_at,12,.25);check(env.river_voice.playing,'water audible near river')
 check(env.river_voice.volume_db>=-6,'river recording is not doubly attenuated')
 env.tick(Vector3(-650,8,165),12,.25);check(not env.river_voice.playing,'water silent inland')
 check(not env.day_at(2) and env.day_at(8),'day bird schedule excludes night')
 var bird: Node3D
 for id in env.birds:
  bird=env.birds[id].get_ref()
  if bird!=null:break
 check(bird!=null,'live mango-tree bird anchors exist')
 if bird!=null:
  silence(audio);env.bird_wait=0;wind.exposure=1
  var before: int=int(env.emissions.get('sparrow',0))
  env.tick(bird.global_position+Vector3(10,0,0),2,.25)
  check(int(env.emissions.get('sparrow',0))==before,'night emits no day bird')
  env.bird_wait=0;env.tick(bird.global_position+Vector3(10,0,0),8,.25)
  check(int(env.emissions.get('sparrow',0))>before,'day emits local recorded bird')
  silence(audio);audio.play_at('sparrow',bird.global_position,-3)
  var bird_voice: AudioStreamPlayer3D=audio.voices[0]
  check(bird_voice.max_distance>=40 and bird_voice.unit_size>=8,'bird voice covers canopy scheduling radius')
  silence(audio);audio.play_at('impact',bird.global_position)
  check(bird_voice.max_distance==28 and bird_voice.unit_size==1,'reused ambient voice restores action attenuation')
 var yard: Node3D=get_nodes_in_group('household_cattle')[0]
 var motion: Node=yard.motion;motion.enabled=false
 motion.state='idle';env.actors[motion.get_instance_id()].wait=0
 env.tick(yard.cow.global_position,12,.25)
 check(int(env.emissions.get('cow',0))>0,'idle cow vocalizes from live mouth')
 var staff:=get_nodes_in_group('administrative_staff')
 check(not staff.is_empty(),'live office staff present')
 var clerk: Node3D=staff[0] if not staff.is_empty() else null
 var actor: CharacterBody3D=world.get_node('Player');actor.set_physics_process(false)
 var clock: Node=world.get_node('GameTimeSystem')
 clock.advance_minutes(fposmod(600-fmod(clock.total_game_minutes,1440),1440))
 var service: Node3D=get_nodes_in_group('administrative_services')[0]
 actor.global_position=service.global_position+Vector3.UP*.2
 silence(audio);var service_before: int=audio.events
 service.interact(actor)
 check(service.completed and audio.events>service_before,'successful live paperwork has sound')
 service_before=audio.events;service.interact(actor)
 check(audio.events==service_before,'repeat paperwork emits no success sound')
 var query:=PhysicsRayQueryParameters3D.create(Vector3(-335,30,230),Vector3(-335,-5,230),1)
 var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
 check(not hit.is_empty(),'contact test grounded in world')
 if not hit.is_empty():
  silence(audio);var before: int=audio.events
  audio.foot_contact(actor,'test',hit.position);audio.foot_contact(actor,'test',hit.position)
  check(audio.events==before+1,'same foot contact cannot double-trigger')
 var camera:=Camera3D.new();world.add_child(camera);camera.current=true
 if clerk!=null:
  camera.global_position=clerk.global_position+Vector3.UP*1.2
  for i in 20:wind._process(.25)
  check(wind.sheltered and wind.exposure<.5,'actual office roof damps wind')
 camera.global_position=Vector3(-335,10,230)
 for i in 20:wind._process(.25)
 check(not wind.sheltered and wind.exposure>.8,'open village lane restores wind')
 var flags:=get_nodes_in_group('wind_flag_roots')
 check(not flags.is_empty(),'live wind flag roots exist')
 for flag in flags:
  var base: Vector3=flag.global_position
  flag.rotation.y=2.0
  for i in 500:wind._process(.1)
  var cloth_direction: Vector3=flag.global_basis.x.normalized()
  var breeze: Vector3=wind.sample(flag.global_position).normalized()
  check(cloth_direction.dot(breeze)>.99,'flag aligns its authored cloth axis with breeze')
  check(flag.global_position.is_equal_approx(base),'wind rotation preserves pole grounding')
  break
 var animators:=get_nodes_in_group('wind_flags')
 check(not animators.is_empty(),'live authored flutter clips exist')
 if not animators.is_empty():
  var animator: AnimationPlayer=animators[0]
  var expected: float=clampf(wind.sample(animator.get_parent().global_position).length()/2.5,.15,1.8)
  check(animator.is_playing() and is_equal_approx(animator.speed_scale,expected),'flutter clip speed follows local gust')
 var saves: Node=root.get_node('SaveManager')
 var ambient_bus:=AudioServer.get_bus_index('Ambient')
 check(ambient_bus>=0,'actual world has independent ambient bus')
 check(env.river_voice.bus=='Ambient' and env.shore_voice.bus=='Ambient' and wind.ambience.bus=='Ambient','world water/wind use ambient volume')
 var saved_ambient: float=float(saves.options.ambient)
 saves.options.ambient=0.0;saves.apply_options(world)
 check(AudioServer.is_bus_mute(ambient_bus),'ambient zero mutes live world sound')
 saves.options.ambient=saved_ambient;saves.apply_options(world)
 check(AudioServer.is_bus_mute(ambient_bus)==(saved_ambient<=.001),'restored ambient value restores bus state')
 for key in ['river','fire']:
  check(env.clips[key].loop_mode==AudioStreamWAV.LOOP_FORWARD,'world '+key+' has smoothed continuous loop')
 var wind_stream: AudioStreamWAV=wind.ambience.stream
 check(wind_stream.format==AudioStreamWAV.FORMAT_16_BITS and wind_stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,'world wind uses PCM crossfade')
 var seam: float=absf(wind_stream.data.decode_s16(0)-wind_stream.data.decode_s16(wind_stream.data.size()-2))/32768.0
 var step_energy:=0.0
 var sample_count:=mini(4096,wind_stream.data.size()/2-1)
 for i in sample_count:
  var step: float=(wind_stream.data.decode_s16(i*2+2)-wind_stream.data.decode_s16(i*2))/32768.0
  step_energy+=step*step
 var normal_step:=sqrt(step_energy/maxf(1,sample_count))
 check(seam<maxf(.005,normal_step*4),'wind seam stays within normal texture transitions')
 evidence['renderer']=str(RenderingServer.get_rendering_device().get_device_name()) if RenderingServer.get_rendering_device()!=null else 'headless'
 evidence['passed']=failures.is_empty();evidence['listening_approved']=false
 # Disposable results are printed only; no checkout reports are retained.
 preload('res://tools/test_audio_cleanup.gd').stop(root);await preload('res://tools/test_audio_cleanup.gd').settle(self)
 print('ENVIRONMENT AUDIO: '+('PASS' if failures.is_empty() else 'FAIL'));quit(0 if failures.is_empty() else 1)
