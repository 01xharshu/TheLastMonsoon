extends Interactable
var lines: Array[String]=[]
var subtitle: Label
var age:=0.0
var index:=-1
func _ready() -> void:
 collision_layer=0;set_collision_layer_value(8,true);interaction_text="Join the conversation";interaction_max_distance=2.6
 var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.4,1,.4);collision.shape=shape;add_child(collision)
 var layer:=CanvasLayer.new();layer.layer=36;add_child(layer);subtitle=Label.new();layer.add_child(subtitle)
 subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);subtitle.offset_left=70;subtitle.offset_right=-70;subtitle.offset_top=-130;subtitle.offset_bottom=-45
 subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;subtitle.add_theme_font_size_override("font_size",23);subtitle.add_theme_constant_override("outline_size",6);subtitle.hide()
func interact(actor: CharacterBody3D) -> void:
 if index>=0 or actor.get_meta("document_busy",false) or actor.global_position.distance_to(global_position)>interaction_max_distance:return
 index=0;age=0;subtitle.text=lines[0];subtitle.show()
func _process(delta: float) -> void:
 if index<0:return
 var player: Node3D=get_tree().get_first_node_in_group("player")
 if player==null:player=get_tree().root.find_child("Player",true,false)
 if player!=null and (player.get_meta("story_cinematic",false) or player.global_position.distance_to(global_position)>6):index=-1;subtitle.hide();return
 age+=delta
 if age>6:
  age=0;index+=1
  if index==lines.size():index=-1;subtitle.hide()
  else:subtitle.text=lines[index]
