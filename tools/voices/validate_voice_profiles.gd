extends SceneTree

class Speaker:
 extends Node3D
 var movement_profile: StringName = &"male"

func _initialize() -> void:
 run.call_deferred()

func run() -> void:
 var actor := Speaker.new()
 var viewer := Node3D.new()
 root.add_child(actor)
 root.add_child(viewer)
 var audio: Node = root.get_node("WorldAudio")
 audio.set_opening_quiet(false)
 root.get_node("SaveManager").pending_slot = -1
 var failures: Array[String] = []
 var streams: Array[AudioStream] = []
 var profiles: Array = [["british", &"male"], ["british", &"female"]]
 if OS.get_environment("TLM_BRITISH_VOICES_ONLY") != "1":
  profiles.append_array([["indian", &"male"], ["indian", &"female"]])
 for profile in profiles:
  for player in audio.voices: player.stop()
  audio.next_social_voice = 0
  actor.set_meta("combat_faction", profile[0])
  actor.movement_profile = profile[1]
  if not audio.play_social_voice(actor, viewer, 0):
   failures.append("voice did not play: " + str(profile))
   continue
  var playing: AudioStreamPlayer3D
  for player in audio.voices:
   if player.playing:
    playing = player
    break
  if playing == null:
   failures.append("no active pooled stream: " + str(profile))
  else:
   streams.append(playing.stream)
  if audio.play_social_voice(actor, viewer, 0): failures.append("cooldown did not limit playback")
 if streams.size() == profiles.size():
  for left in range(streams.size()):
   for right in range(left + 1, streams.size()):
    if streams[left] == streams[right]: failures.append("profiles share a voice stream")
 for player in audio.voices: player.stop()
 audio.next_social_voice = 0
 viewer.position = Vector3(20, 0, 0)
 if audio.play_social_voice(actor, viewer, 0): failures.append("distant voice played")
 print("VOICE PROFILES ", "PASS" if failures.is_empty() else "FAIL", " ", failures)
 actor.queue_free()
 viewer.queue_free()
 await preload("res://tools/test_audio_cleanup.gd").finish(self, 0 if failures.is_empty() else 1)
