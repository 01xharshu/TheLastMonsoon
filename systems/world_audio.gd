extends Node
## Bounded spatial voices. All clips in audio/world are original synthesis.
var streams: Dictionary = {}
var step_variants: Dictionary = {}
var voices: Array[AudioStreamPlayer3D] = []
var events := 0
var event_counts: Dictionary = {}
var tracked: Dictionary = {}
var npc_tracks: Dictionary = {}
var npc_timer := 0.0
func _ready() -> void:
 for key in ['step_dirt','step_stone','step_wood','splash','impact','cloth','paper','door','wind','quill','wood_knock','metal_clink','wheel_creak','chew']:
  streams[key] = (load('res://audio/world/'+key+'.wav') as AudioStreamWAV)
 for key in ['pickup','chest_open','water_fill','water_drink']:
  streams[key]=(load('res://audio/interaction/'+key+'.wav') as AudioStreamWAV)
 for key in ['bow_loose','arrow_impact','blade_swoosh','knife_slash']:
  streams[key]=(load('res://audio/combat/'+key+'.wav') as AudioStreamWAV)
 streams['hoof_dirt']=streams.step_dirt
 for material in ['dirt','stone','wood']:
  step_variants['step_'+material]=[]
  var names: Array=['mud02','gravel'] if material=='dirt' else ['stone01'] if material=='stone' else ['wood01','wood02','wood03']
  for name in names:step_variants['step_'+material].append((load('res://audio/ambience/step_'+name+'.wav') as AudioStreamWAV))
  streams['step_'+material]=step_variants['step_'+material][0]
 for i in 24:
  var voice := AudioStreamPlayer3D.new()
  voice.max_distance = 28.0
  add_child(voice);voices.append(voice)
 for key in ['cow','sparrow']:
  streams[key]=(load('res://audio/ambience/'+key+'.wav') as AudioStreamWAV)
 var environment:=preload('res://systems/environment_audio.gd').new();environment.name='EnvironmentAudio';add_child(environment)
 get_tree().node_added.connect(_added)
 for node in get_tree().root.find_children('*','',true,false):_added(node)
func play_at(key: String, at: Vector3, db: float = -18.0) -> bool:
 if not streams.has(key):return false
 for voice in voices:
  if voice.playing:continue
  # Broad canopy calls must cover the same 40 m radius used by the scheduler.
  voice.max_distance=45.0 if key=='sparrow' else 28.0
  voice.unit_size=8.0 if key=='sparrow' else 1.0
  voice.stream=step_variants[key].pick_random() if step_variants.has(key) else streams[key];voice.global_position=at;voice.volume_db=db
  voice.pitch_scale=randf_range(.94,1.06);voice.play();events+=1;event_counts[key]=int(event_counts.get(key,0))+1;return true
 return false
func interaction(target: Node3D) -> void:
 if not is_instance_valid(target):return
 var label := (str(target.name)+' '+str(target.get('interaction_text'))).to_lower()
 # Dedicated chest/pickup/water effects already exist; avoid doubling them.
 if 'chest' in label or 'pickup' in label or 'water' in label or 'notice' in label or target.is_in_group('house_doors'):return
 var key := 'door' if 'door' in label or 'shutter' in label else 'paper' if 'notice' in label or 'letter' in label or 'document' in label else 'cloth'
 play_at(key,target.global_position)
func _added(node: Node) -> void:
 if node is Node3D and node.get_script()!=null and node.get_script().resource_path in ['res://characters/npcs/indian/indian_npc_candidate.gd','res://characters/npcs/british/british_npc_actor.gd','res://characters/npcs/households/household_npc_actor.gd','res://characters/npcs/indian/purpose_work_actor.gd','res://world/suryagarh/settlements/administrative_actor.gd']:
  npc_tracks[node.get_instance_id()]={'actor':weakref(node),'position':node.position,'distance':0.0,'side':''}
 if node is CharacterBody3D and node.get_script()!=null and node.get_script().resource_path=='res://player/player_controller.gd':
  tracked[node.get_instance_id()]={'actor':weakref(node),'distance':0.0,'position':node.position,'ground':false}
func _physics_process(_delta: float) -> void:
 npc_timer-=_delta
 if npc_timer<=0:
  npc_timer=.1
  _npc_steps()
  var now:=Time.get_ticks_msec()
  for key in contact_times.keys():
   if now-int(contact_times[key])>2000:contact_times.erase(key)
 for id in tracked.keys():
  var state: Dictionary=tracked[id]
  var actor: CharacterBody3D=state.actor.get_ref()
  if actor==null:tracked.erase(id);continue
  var at := actor.global_position
  var travel: float=at.distance_to(state.position);state.position=at
  var ground := actor.is_on_floor()
  var suppressed: bool = not actor.is_physics_processing() or (actor.has_meta('mounted_vehicle') and actor.get_meta('mounted_vehicle')!=null) or actor.get_meta('climbing',false)
  if suppressed:state.distance=0.0;state.ground=ground;continue
  if ground and not state.ground:play_at('impact',at,-23.0)
  state.ground=ground
  if travel>1.0 or (not ground and not actor.is_swimming):state.distance=0.0;continue
  state.distance+=travel
  if actor.get_meta('audio_contact_active',false) and not actor.is_swimming:state.distance=0.0;continue
  if state.distance<.95:continue
  state.distance=0.0
  var key := 'splash' if actor.is_swimming else 'step_dirt'
  if not actor.is_swimming:
   var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP,at-Vector3.UP*2,1)
   query.exclude=[actor.get_rid()]
   var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
   if not hit.is_empty():key=surface_key(hit.collider)
  play_at(key,at,-23.0)

func _npc_steps() -> void:
 var camera := get_viewport().get_camera_3d()
 for id in npc_tracks.keys():
  var state: Dictionary=npc_tracks[id]
  var actor: Node3D=state.actor.get_ref()
  if actor==null:npc_tracks.erase(id);continue
  var at := actor.global_position
  var travel: float=at.distance_to(state.position);state.position=at
  if actor.get_meta('dead',false) or actor.get_meta('knocked_out',false) or not (actor.is_processing() or actor.is_physics_processing()):
   state.distance=0.0;state.side='';continue
  if camera==null or camera.global_position.distance_squared_to(at)>625.0 or travel>2.0:
   state.distance=0.0;continue
  state.distance+=travel
  var plant=actor.get('foot_plant')
  if plant!=null and plant.active and travel>.003:
   if state.side!=plant.planted_side:
    state.side=plant.planted_side;foot_contact(actor,state.side,plant.planted_world,-29.0)
   state.distance=0.0
  elif state.distance>=.8:
   state.distance=0.0;foot_contact(actor,'fallback',at,-29.0)

var contact_times: Dictionary={}
func surface_key(body: Object) -> String:
 var node:=body as Node
 while node!=null:
  var explicit: String=str(node.get_meta('audio_surface',''))
  if explicit in ['dirt','stone','wood']:return 'step_'+explicit
  var label:=str(node.name).to_lower()
  if 'pier' in label or 'timber' in label or 'wood' in label:return 'step_wood'
  if 'stone' in label or 'pav' in label or 'masonry' in label:return 'step_stone'
  node=node.get_parent()
 return 'step_dirt'
func foot_contact(actor: Node3D, side: String, at: Vector3, db: float=-23.0) -> void:
 var id:=str(actor.get_instance_id())+side
 var now:=Time.get_ticks_msec()
 if now-int(contact_times.get(id,-1000))<180:return
 contact_times[id]=now
 var query:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.25,at-Vector3.UP*.4,1)
 if actor is CollisionObject3D:query.exclude=[actor.get_rid()]
 var animal_body:=actor.get_node_or_null("CowBody") as CollisionObject3D
 if animal_body!=null:query.exclude.append(animal_body.get_rid())
 var hit:=actor.get_world_3d().direct_space_state.intersect_ray(query)
 if hit.is_empty():return
 play_at('hoof_dirt' if animal_body!=null else surface_key(hit.collider),hit.position,db)
