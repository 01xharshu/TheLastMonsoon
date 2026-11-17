extends SceneTree

class Speaker:
 extends Node3D
 var movement_profile: StringName = &"male"

func _initialize() -> void:
 run.call_deferred()

func run() -> void:
 var room:=Node3D.new()
 root.add_child(room)
 current_scene=room
 var player:=CharacterBody3D.new()
 player.name="Player"
 room.add_child(player)
 for profile in [&"male", &"female"]:
  var person:=Speaker.new()
  person.movement_profile=profile
  person.set_meta("world_role","student" if profile==&"male" else "printer")
  room.add_child(person)
  var social: Node=load("res://story/community_social.gd").new()
  person.add_child(social)
 var talk: Node=load("res://story/community_conversation.gd").new()
 room.add_child(talk)
 talk.lines.assign(["Reader: We compare accounts here. An official's answer is not always the whole truth.","Patron: Sit with us. News travels with the merchants and the people returning from the cantonment."])
 var errors: Array[String]=[]
 talk.interact(player)
 if not talk.dialogue_voice.playing or talk.speaking_person.movement_profile!=&"male":errors.append("first participant and male voice")
 var first: AudioStream=talk.dialogue_voice.stream
 talk._process(talk.line_duration+.1)
 if not talk.dialogue_voice.playing or talk.speaking_person.movement_profile!=&"female" or talk.dialogue_voice.stream==first:errors.append("second participant and female voice")
 player.set_meta("story_cinematic",true)
 talk._process(.01)
 if talk.index!=-1 or talk.dialogue_voice.playing or talk.subtitle.visible:errors.append("cinematic interruption")
 player.set_meta("story_cinematic",false)
 talk.lines.assign(["Printer: Among the students we can compare news without drawing every guard's attention."])
 talk.interact(player)
 if not talk.dialogue_voice.playing or talk.speaking_person.movement_profile!=&"female":errors.append("printer role selects the actual speaker")
 talk._process(talk.line_duration+.1)
 if talk.index!=-1 or talk.dialogue_voice.playing or talk.subtitle.visible:errors.append("conversation completion releases voice")
 print("COMMUNITY VOICE ","PASS" if errors.is_empty() else "FAIL",errors)
 await preload("res://tools/test_audio_cleanup.gd").finish(self,0 if errors.is_empty() else 1)
