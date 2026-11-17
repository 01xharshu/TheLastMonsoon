extends Node3D
## Physical forecourt alarm. Actual identified violence supplies the trigger.
var voice: AudioStreamPlayer3D
var bell: MeshInstance3D
var ringing: Tween

func _ready() -> void:
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(.42,.30,.13)
	bronze.metallic = .64
	bronze.roughness = .57
	var form := CylinderMesh.new()
	form.top_radius = .11
	form.bottom_radius = .22
	form.height = .32
	form.radial_segments = 24
	bell = MeshInstance3D.new()
	bell.mesh = form
	bell.material_override = bronze
	add_child(bell)
	var lip := TorusMesh.new()
	lip.inner_radius = .18
	lip.outer_radius = .23
	var rim := MeshInstance3D.new()
	rim.mesh = lip
	rim.material_override = bronze
	rim.position.y = -.15
	bell.add_child(rim)
	voice = AudioStreamPlayer3D.new()
	voice.unit_size = 12.0
	voice.max_distance = 105.0
	voice.volume_db = -9.0
	add_child(voice)

func ring() -> void:
	if ringing != null and ringing.is_running():
		return
	if voice.stream == null:
		voice.stream = strike_sound()
	ringing = create_tween()
	for count in 3:
		ringing.tween_callback(voice.play)
		ringing.tween_property(bell,"rotation:z",.12,.13)
		ringing.tween_property(bell,"rotation:z",-.08,.16)
		ringing.tween_property(bell,"rotation:z",0.0,.21)

func strike_sound() -> AudioStreamWAV:
	const RATE := 22050
	var pcm := PackedByteArray()
	pcm.resize(RATE*2)
	for sample in RATE:
		var t := float(sample)/RATE
		var pitch := sin(TAU*385.0*t)*.54 + sin(TAU*814.0*t)*.24 + sin(TAU*1297.0*t)*.12
		var envelope := minf(t/.003,1.0)*exp(-4.8*t)
		pcm.encode_s16(sample*2,roundi(pitch*envelope*28000))
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = RATE
	result.data = pcm
	return result
