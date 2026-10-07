extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:call_deferred('run')
func check(ok: bool,label: String) -> void:
 print(('PASS ' if ok else 'FAIL ')+label)
 if not ok:failures.append(label)
func count(audio: Node) -> int:
 return int(audio.event_counts.get('step_dirt',0))+int(audio.event_counts.get('step_stone',0))+int(audio.event_counts.get('step_wood',0))
func run() -> void:
 var world:=Node3D.new();root.add_child(world);current_scene=world
 var clock:=preload('res://world/suryagarh/systems/game_time_system.gd').new();clock.name='GameTimeSystem';world.add_child(clock)
 var floor:=StaticBody3D.new();floor.set_meta('audio_surface','stone');world.add_child(floor)
 var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(80,.2,80);collider.shape=box;collider.position.y=-.1;floor.add_child(collider)
 var actor: CharacterBody3D=load('res://player/player.tscn').instantiate();world.add_child(actor);actor.position=Vector3(0,.9,0)
 var audio: Node=root.get_node('WorldAudio')
 for i in 12:await physics_frame
 var before:=count(audio)
 Input.action_press('move_forward')
 for i in 75:await physics_frame
 Input.action_release('move_forward')
 check(count(audio)>before,'input-driven walk produces contact footsteps')
 check(int(audio.event_counts.get('step_stone',0))>0,'ground surface tag selects recorded stone')
 for i in 25:await physics_frame
 before=count(audio)
 for i in 45:await physics_frame
 check(count(audio)==before,'standing produces no repeated footsteps')
 Input.action_press('jump');await physics_frame;Input.action_release('jump')
 var airborne_silent:=true
 for i in 35:
  var previous:=count(audio)
  var airborne:=not actor.is_on_floor()
  await physics_frame
  if airborne and not actor.is_on_floor() and count(audio)!=previous:airborne_silent=false
 check(airborne_silent,'airborne motion produces no footsteps')
 check(audio.voices.size()==24,'contact events preserve voice cap')
 preload('res://tools/test_audio_cleanup.gd').stop(root);await preload('res://tools/test_audio_cleanup.gd').settle(self)
 print('FOOTSTEP AUDIO: '+('PASS' if failures.is_empty() else 'FAIL'));quit(0 if failures.is_empty() else 1)
