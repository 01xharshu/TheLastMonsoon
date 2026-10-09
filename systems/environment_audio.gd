extends Node
## Eight bounded positional loops; activity sounds share WorldAudio's voice cap.
const Layout=preload('res://world/suryagarh/landscape_layout.gd')
var layout:=Layout.new()
var clips: Dictionary={}
var loops: Array[AudioStreamPlayer3D]=[]
var sources: Dictionary={}
var actors: Dictionary={}
var birds: Dictionary={}
var timer:=0.0
var bird_wait:=2.0
var morning_bird_wait := -1.0
var morning_bird_position := Vector3.ZERO
var river_voice: AudioStreamPlayer3D
var shore_voice: AudioStreamPlayer3D
var water_seconds:=0.0
var emissions: Dictionary={}
func _ready() -> void:
 for key in ['fire','river','cow','sparrow']:
  clips[key]=(load('res://audio/ambience/'+key+'.wav') as AudioStreamWAV)
  if key in ['fire','river']:
   clips[key]=preload('res://systems/audio_edges.gd').prepare(clips[key],true)
 for i in 8:
  var voice:=AudioStreamPlayer3D.new();voice.max_distance=28;voice.unit_size=6;voice.volume_db=-3
  add_child(voice);loops.append(voice)
 river_voice=AudioStreamPlayer3D.new();river_voice.max_distance=110;river_voice.unit_size=10;river_voice.volume_db=-2
 river_voice.stream=clips.river;add_child(river_voice)
 shore_voice=AudioStreamPlayer3D.new();shore_voice.max_distance=32;shore_voice.unit_size=7
 shore_voice.stream=clips.river;shore_voice.pitch_scale=.92;shore_voice.volume_db=-3;add_child(shore_voice)
 get_tree().node_added.connect(_added)
 for node in get_tree().root.find_children('*','',true,false):_added(node)
func _added(node: Node) -> void:
 if node is OmniLight3D and node.name=='FireLight':sources[node.get_instance_id()]=weakref(node)
 if node is MeshInstance3D and node.name=='MangoTree_Leaves':birds[node.get_instance_id()]=weakref(node)
 if node.get_script()==null:return
 var path: String=node.get_script().resource_path
 if path in ['res://animals/cow_motion.gd','res://animals/cattle_caretaker.gd','res://world/suryagarh/settlements/administrative_actor.gd','res://characters/npcs/households/household_npc_actor.gd','res://vehicles/horse_cart_candidate.gd','res://vehicles/family_carriage_candidate.gd','res://vehicles/bullock_cart.gd']:
  actors[node.get_instance_id()]={'ref':weakref(node),'path':path,'wait':randf_range(8,17),'phase':-1,'last':Vector3.ZERO,'last_stage':'','transfers':0}
func day_at(hour: int) -> bool:return hour>=6 and hour<18
func emit(key: String, at: Vector3, db: float) -> void:
 if get_parent().play_at(key,at,db):
  emissions[key]=int(emissions.get(key,0))+1
func _process(delta: float) -> void:
 timer-=delta
 if timer>0:return
 var step:=.25;timer=step
 var camera:=get_viewport().get_camera_3d()
 if camera==null:
  river_voice.stop();shore_voice.stop()
  for voice in loops:voice.stop()
  return
 var scene:=get_tree().current_scene
 if scene==null or scene.get_node_or_null('GameTimeSystem')==null:
  river_voice.stop();shore_voice.stop()
  for voice in loops:voice.stop()
  return
 var clock: Node=scene.get_node('GameTimeSystem')
 tick(camera.global_position,int(clock.current_hour),step)
func bank_x(z: float, side: float) -> float:
 # Follow the actual terrain/water intersection rather than the channel-width marker.
 var centre: float=layout.river_x(z)
 var low: float=layout.river_width(z)-9.0
 var high: float=layout.river_width(z)+37.0
 for i in 9:
  var offset: float=(low+high)*.5
  if layout.height(centre+side*offset,z)>Layout.WATER_LEVEL:high=offset
  else:low=offset
 return centre+side*(low+high)*.5
func stop_loops() -> void:
 river_voice.stop();shore_voice.stop()
 for voice in loops:voice.stop()

func tick(listener: Vector3,hour: int,delta: float) -> void:
 if get_parent().is_opening_quiet():
  stop_loops()
  return
 var gain_db := linear_to_db(maxf(.0001,get_parent().ambience_gain))
 if morning_bird_wait >= 0.0:
  morning_bird_wait -= delta
  if morning_bird_wait < 0.0 and day_at(hour):
   emit('sparrow',morning_bird_position,-12)
   bird_wait = randf_range(4.0,7.0)
 water_seconds+=delta
 # A river's broad source follows the nearest bank, rather than the player's feet.
 var z:=clampf(listener.z,-820,820)
 var centre: float=layout.river_x(z)
 var width: float=layout.river_width(z)
 var x:=clampf(listener.x,centre-width,centre+width)
 river_voice.global_position=Vector3(x,Layout.WATER_LEVEL,z)
 var exposure: float=get_tree().root.get_node('WindSystem').exposure
 var upstream:=1.0-smoothstep(350.0,750.0,z)
 river_voice.volume_db=gain_db-4+upstream*3+linear_to_db(maxf(.12,exposure))
 river_voice.pitch_scale=lerpf(.95,1.08,upstream)
 if listener.distance_to(river_voice.global_position)<110:
  if not river_voice.playing:river_voice.play()
 else:river_voice.stop()
 # A close, separately phased bank wash adds gentle lapping beneath the current.
 var side: float=-1.0 if listener.x<centre else 1.0
 shore_voice.global_position=Vector3(bank_x(z,side),Layout.WATER_LEVEL,z)
 shore_voice.volume_db=gain_db-3+linear_to_db(maxf(.12,exposure))+sin(water_seconds*.8)*2
 if listener.distance_to(shore_voice.global_position)<32:
  if not shore_voice.playing:shore_voice.play(clips.river.get_length()*.43)
 else:shore_voice.stop()
 var active: Array[Node3D]=[]
 for id in sources.keys():
  var light: OmniLight3D=sources[id].get_ref()
  if light==null:sources.erase(id);continue
  if light.is_visible_in_tree() and light.light_energy>0 and listener.distance_squared_to(light.global_position)<784:active.append(light)
 active.sort_custom(func(a,b):return listener.distance_squared_to(a.global_position)<listener.distance_squared_to(b.global_position))
 for i in loops.size():
  var voice:=loops[i]
  if i>=active.size():voice.stop();continue
  voice.volume_db = -3+gain_db
  voice.global_position=active[i].global_position
  if not voice.playing:voice.stream=clips.fire;voice.play(randf_range(0,clips.fire.get_length()))
 bird_wait-=delta
 if bird_wait<=0:
  bird_wait=randf_range(9,18)
  if day_at(hour) and get_tree().root.get_node('WindSystem').exposure>.6:
   var nearest: MeshInstance3D=null
   var nearest_distance:=1600.0
   for id in birds.keys():
    var tree: MeshInstance3D=birds[id].get_ref()
    if tree==null:birds.erase(id);continue
    var distance:=listener.distance_squared_to(tree.global_position)
    if distance<nearest_distance:
     nearest=tree;nearest_distance=distance
   if nearest!=null:
    emit('sparrow',nearest.to_global(nearest.get_aabb().get_center()),-3)
 for id in actors.keys():
  var state: Dictionary=actors[id];var node: Node=state.ref.get_ref()
  if node==null:actors.erase(id);continue
  var body: Node3D=node as Node3D
  if state.path.ends_with('cow_motion.gd'):body=node.cow
  if body==null or not body.is_inside_tree():continue
  if body.get_meta("dead",false) or body.get_meta("knocked_out",false):continue
  if listener.distance_squared_to(body.global_position)>900:continue
  state.wait-=delta
  if state.path.ends_with('cow_motion.gd'):
   if state.wait<=0:
    if node.state=='idle':emit('cow',node.mouth_world(),-17)
    state.wait=randf_range(35,75)
   var beat:=int(float(node.contact_seconds)*1.1)
   if beat!=state.phase and float(node.contact_seconds)>.1:
    if node.state=='drink':emit('water_drink',node.mouth_world(),-26)
    elif node.state in ['graze','feed']:emit('chew',node.mouth_world(),-28)
   state.phase=beat
  elif state.path.ends_with('administrative_actor.gd'):
   var phase:=int(float(node.working_phase)*1.5)
   if phase!=state.phase and fmod(float(node.working_phase),10)<7 and float(node.response_blend)<.1 and float(node.get_meta('office_pen_error',1.0))<.025:
    emit('quill',node.paper_target,-30)
   state.phase=phase
  elif state.path.begins_with('res://vehicles/'):
   var distance: float=body.global_position.distance_to(state.last);state.last=body.global_position
   if distance>.01 and distance<5 and state.wait<=0:
    emit('wheel_creak',body.global_position,-25);state.wait=randf_range(1.5,3.0)
  elif state.path.ends_with('cattle_caretaker.gd'):
   if int(node.transfers)>int(state.transfers):emit('cloth',node.actor.global_position,-24)
   state.transfers=int(node.transfers)
   state.last_stage=node.stage
  else:
   var travel:=body.global_position.distance_to(state.last);state.last=body.global_position
   if node.household_job=='WaterBearer' and travel>.015 and travel<2 and state.wait<=0:
    emit('splash',body.global_position+Vector3.UP,-30);state.wait=2.0
