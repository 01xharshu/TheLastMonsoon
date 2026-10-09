extends Interactable
const LINES := [
	{"speaker":"Chacha","text":"Arjun, is there any news of your brother Dev?","seconds":5.5},
	{"speaker":"Arjun","text":"Still no word, Chacha. I have to find him.","seconds":5.0},
	{"speaker":"Chacha","text":"I worry about him too. But promise me you will be careful.","seconds":5.5},
	{"speaker":"Chacha","text":"If armed men stand in your way, bare hands will not protect you.","seconds":5.5},
	{"speaker":"Chacha","text":"Take my talwar, knife or spear from the inner room. Choose what you can handle.","seconds":6.0},
	{"speaker":"Chacha","text":"Take smoke pouches for your escape. Return here whenever you need to equip your weapons again.","seconds":7.0}
]
var current_speaker := ""
var speaking := false
var line := 0
var elapsed := 0.0
var subtitle: Label
var listener: CharacterBody3D
var listener_expression=preload("res://story/dialogue_expression.gd").new()
func _ready() -> void:
	interaction_text = "Speak with Chacha"
	interaction_icon = "hand"
	var layer:=CanvasLayer.new();add_child(layer)
	subtitle=Label.new();layer.add_child(subtitle)
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle.offset_left=60;subtitle.offset_right=-60;subtitle.offset_top=-135;subtitle.offset_bottom=-45
	subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size",23);subtitle.add_theme_color_override("font_outline_color",Color(.08,.07,.04));subtitle.add_theme_constant_override("outline_size",6)
	subtitle.hide()
func interact(actor: CharacterBody3D) -> void:
	if actor.global_position.distance_to(global_position)>3: return
	if speaking:return
	if actor.get_meta("document_busy",false) or actor.get_meta("opening_active",false):return
	var director: Node=get_parent().get_parent().get_node_or_null("DevStory")
	if director!=null and not director.first_chacha_seen:
		if director.begin_optional():return
	listener=actor
	listener_expression.configure(actor.get_node("VisualRoot/CharacterVisual"))
	speaking=true;line=0;elapsed=0;show_line();subtitle.show()
func show_line() -> void:
	current_speaker=LINES[line].speaker
	listener_expression.apply(.7 if line<3 else .15,0)
	subtitle.text=current_speaker+": "+str(LINES[line].text)
func _process(delta: float) -> void:
	if not speaking:return
	if not is_instance_valid(listener) or listener.health<=0 or listener.global_position.distance_to(global_position)>6:
		finish();return
	elapsed+=delta
	while speaking and elapsed>=float(LINES[line].seconds):
		elapsed-=float(LINES[line].seconds);line+=1
		if line==LINES.size():finish()
		else:show_line()
func finish() -> void:
	speaking=false;current_speaker="";subtitle.hide();listener_expression.restore()
func _exit_tree() -> void:
	listener_expression.restore()
