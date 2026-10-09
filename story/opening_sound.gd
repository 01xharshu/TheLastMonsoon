extends Node
## Spatial original foley synchronized to the live cinematic, not video timing.
var actor: Node3D
var lamp: Node3D
var players: Dictionary = {}
var played: Dictionary = {}
var previous := 0.0
var last_steps: Dictionary = {}
var step_count := 0
var cues := [[.12,"match_strike"],[5.5,"wick_catch"],[6.12,"match_exhale"],
	[.7,"cloth_rustle"],[6.0,"cloth_rustle"],[24.3,"cloth_rustle"],[26.0,"cloth_rustle"],
	[24.5,"cot_creak"],[26.3,"cot_creak"]]

func configure(target: Node3D, prop: Node3D) -> void:
	actor = target
	lamp = prop
	for name in ["match_strike","wick_catch","match_exhale","room_step","cot_creak","cloth_rustle"]:
		var player := AudioStreamPlayer3D.new()
		player.max_polyphony = 4
		var stream: AudioStreamWAV = preload("res://systems/audio_edges.gd").prepare(load("res://assets/audio/opening/"+name+".wav"))
		if name.ends_with("room"):
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = stream.data.size()/2
		player.stream = stream
		player.max_distance = 10
		player.volume_db = -18 if name in ["room_step","cloth_rustle"] else (-6 if name.ends_with("room") else -12)
		add_child(player)
		players[name] = player

func update(t: float) -> void:
	for name in players:
		var player: AudioStreamPlayer3D = players[name]
		if name == "room_step": continue # Foot planting supplies its actual location.
		player.global_position = actor.global_position+Vector3.UP*.6
		if name in ["match_strike","wick_catch"]: player.global_position = lamp.global_position+Vector3.UP*.035
		elif name == "room_step": player.global_position = actor.global_position-Vector3.UP*.9
		elif name == "cot_creak": player.global_position = actor.global_position-Vector3.UP*.2
	for i in cues.size():
		var cue: Array = cues[i]
		if not played.has(i) and previous < cue[0] and t >= cue[0]:
			played[i] = true
			# Seeking validators must not burst all skipped footsteps at once.
			if t-float(cue[0]) < .6:
				players[cue[1]].pitch_scale = 1.0+(float(i%3)-1.0)*.035 if cue[1] == "room_step" else 1.0
				players[cue[1]].play()
	previous = t

func play_step(side: String, t: float, at: Vector3) -> void:
	if t-float(last_steps.get(side,-1.0)) < .2: return
	last_steps[side] = t
	step_count += 1
	players.room_step.global_position = at
	players.room_step.pitch_scale = .965 if side == "l" else 1.035
	players.room_step.play()

func morning() -> void:
	for player in players.values(): player.stop()

func rise() -> void:
	players.cot_creak.play()

func stop_all() -> void:
	for player in players.values(): player.stop()
