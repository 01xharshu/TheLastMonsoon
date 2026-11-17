extends Interactable
var participants: Array[Node3D]=[]
var listener: CharacterBody3D
var lines: Array[String]=[]
var subtitle: Label
var age:=0.0
var index:=-1
var line_duration:=6.0
var dialogue_voice: AudioStreamPlayer3D
var speaking_person: Node3D
func _ready() -> void:
 dialogue_voice=AudioStreamPlayer3D.new();dialogue_voice.max_distance=18.0;dialogue_voice.unit_size=5.0;add_child(dialogue_voice)
 collision_layer=0;set_collision_layer_value(8,true);interaction_text="Join the conversation";interaction_max_distance=2.6
 var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.4,1,.4);collision.shape=shape;add_child(collision)
 var layer:=CanvasLayer.new();layer.layer=36;add_child(layer);subtitle=Label.new();layer.add_child(subtitle)
 subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);subtitle.offset_left=70;subtitle.offset_right=-70;subtitle.offset_top=-130;subtitle.offset_bottom=-45
 subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;subtitle.add_theme_font_size_override("font_size",23);subtitle.add_theme_constant_override("outline_size",6);subtitle.hide()
func interact(actor: CharacterBody3D) -> void:
 if index>=0 or actor.get_meta("document_busy",false) or actor.global_position.distance_to(global_position)>interaction_max_distance:return
 if lines.is_empty():return
 listener=actor;participants.clear()
 for person in get_parent().get_children():
  if person is Node3D:
   for behavior in person.get_children():
    if behavior.get_script() in [preload("res://story/community_social.gd"),preload("res://story/college_activity.gd")]:participants.append(person);break
 index=0;age=0;show_line();subtitle.show()
func show_line() -> void:
 subtitle.text=lines[index]
 line_duration=6.0
 dialogue_voice.stop()
 speaking_person=null
 if participants.is_empty():return
 var parts:=lines[index].split(": ",true,1)
 if parts.size()!=2:return
 speaking_person=participants[posmod(index,participants.size())]
 var role: String=parts[0].to_lower()
 if role in ["student","printer"]:
  for person in participants:
   if is_instance_valid(person) and person.get_meta("world_role","")==role:
    speaking_person=person
    break
 if not is_instance_valid(speaking_person):return
 var speaker: String="Indian female" if speaking_person.get("movement_profile")==&"female" else "Indian male"
 var key: String=(speaker+"\n"+parts[1]).sha256_text()
 var path: String="res://assets/audio/dialogue/"+key+".wav"
 if not ResourceLoader.exists(path):return
 var stream:=load(path) as AudioStream
 if stream==null:return
 dialogue_voice.stream=stream
 dialogue_voice.global_position=speaking_person.global_position+Vector3.UP*1.35
 line_duration=maxf(line_duration,stream.get_length()+.2)
 dialogue_voice.play()

func finish() -> void:
 dialogue_voice.stop()
 subtitle.hide()
 index=-1
 speaking_person=null
 preload("res://story/conversation_facing.gd").release(listener)
 for person in participants:preload("res://story/conversation_facing.gd").release(person)
 participants.clear()

func _process(delta: float) -> void:
 if index<0:return
 var player: Node3D=get_tree().get_first_node_in_group("player")
 if player==null:player=get_tree().root.find_child("Player",true,false)
 if not is_instance_valid(listener) or (player!=null and (player.get_meta("story_cinematic",false) or player.global_position.distance_to(global_position)>6)):
  finish();return
 while not participants.is_empty() and not is_instance_valid(participants[0]):participants.remove_at(0)
 if not participants.is_empty():
  if listener.velocity.length()<.2:preload("res://story/conversation_facing.gd").toward(listener,participants[0].global_position)
  else:preload("res://story/conversation_facing.gd").release(listener)
  for person in participants:preload("res://story/conversation_facing.gd").toward(person,listener.global_position)
 if is_instance_valid(speaking_person):dialogue_voice.global_position=speaking_person.global_position+Vector3.UP*1.35
 age+=delta
 if age>line_duration:
  age=0;index+=1
  if index==lines.size():finish()
  else:show_line()
