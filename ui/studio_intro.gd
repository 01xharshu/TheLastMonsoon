extends Control
## One-shot startup ident. Returning to the menu bypasses this scene.
const MENU := "res://ui/main_menu.tscn"
const ATMOSPHERE := preload("res://ui/studio_atmosphere.gdshader")
const GOLD := Color("c8ac72")
const IVORY := Color("eee5d4")
const DURATION := 7.8
var elapsed := 0.0
var leaving := false
var fade := 1.0
var sound: AudioStreamPlayer
var atmosphere: ShaderMaterial
var wordmark: SystemFont

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	get_tree().paused = false
	wordmark = SystemFont.new()
	wordmark.font_names = PackedStringArray(["Arial", "Helvetica Neue", "sans-serif"])
	wordmark.font_weight = 700
	atmosphere = ShaderMaterial.new()
	atmosphere.shader = ATMOSPHERE
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.material = atmosphere
	backdrop.show_behind_parent = true
	add_child(backdrop)
	# Quiet original two-note signature; no downloaded or licensed recording.
	sound = AudioStreamPlayer.new()
	sound.bus = "Master"
	sound.volume_db = -15.0
	sound.stream = _signature()
	add_child(sound)

func _process(delta: float) -> void:
	var previous := elapsed
	elapsed += delta
	if previous < 1.65 and elapsed >= 1.65 and not leaving:
		sound.play()
	if elapsed >= DURATION and not leaving:
		_finish()
	atmosphere.set_shader_parameter("phase", elapsed)
	atmosphere.set_shader_parameter("visibility", fade)
	atmosphere.set_shader_parameter("canvas_size", size)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if elapsed < 0.35 or leaving:
		return
	var skip: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]
	skip = skip or (event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_START, JOY_BUTTON_B])
	skip = skip or (event is InputEventScreenTouch and event.pressed)
	skip = skip or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if skip:
		get_viewport().set_input_as_handled()
		_finish()

func _finish() -> void:
	if leaving:
		return
	leaving = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "fade", 0.0, 0.45)
	tween.tween_property(sound, "volume_db", -60.0, 0.45)
	await tween.finished
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var error := get_tree().change_scene_to_file(MENU)
	if error != OK:
		push_error("Studio intro could not open the title menu: %s" % error)
		leaving = false
		fade = 1.0

func _reveal(start: float, duration: float) -> float:
	return smoothstep(start, start + duration, elapsed) * fade

func _text(text: String, font: Font, font_size: int, y: float, color: Color, spacing: float = 0.0) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing * (text.length() - 1)
	var x := (1280.0 - width) * 0.5
	for character in text:
		draw_string(font, Vector2(x, y), character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		x += font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing

func _metal_polygon(points: PackedVector2Array, brightness: float, alpha: float, sweep: float) -> void:
	var colors := PackedColorArray()
	for point in points:
		var glint := exp(-pow((point.x - sweep) / 44.0, 2.0))
		var shading := 0.5 + (350.0 - point.y) / 220.0
		colors.append(Color(GOLD.lerp(IVORY, glint * 0.85) * (shading * brightness), alpha))
	draw_polygon(points, colors)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Color(IVORY, alpha * 0.38), 1.0, true)

func _draw() -> void:
	var scale_factor := minf(size.x / 1280.0, size.y / 720.0)
	var origin := (size - Vector2(1280, 720) * scale_factor) * 0.5
	var arrive := smoothstep(0.45, 2.35, elapsed)
	var zoom := 1.0 + (1.0 - arrive) * 0.12
	draw_set_transform(origin + Vector2(640, 285) * scale_factor * (1.0 - zoom), 0.0, Vector2.ONE * scale_factor * zoom)
	var alpha := _reveal(0.45, 1.6)
	var center := Vector2(640, 285)
	var sweep := lerpf(480.0, 830.0, smoothstep(1.7, 3.4, elapsed))
	# Cut metal twin-H symbol: broad verticals, angular bridge and negative-space seam.
	var left := PackedVector2Array([Vector2(533, 199), Vector2(569, 199), Vector2(569, 266), Vector2(623, 266), Vector2(623, 199), Vector2(641, 181), Vector2(641, 371), Vector2(623, 353), Vector2(623, 300), Vector2(569, 300), Vector2(569, 353), Vector2(533, 353)])
	var right := PackedVector2Array([Vector2(652, 181), Vector2(670, 199), Vector2(670, 266), Vector2(724, 266), Vector2(724, 199), Vector2(760, 199), Vector2(760, 353), Vector2(724, 353), Vector2(724, 300), Vector2(670, 300), Vector2(670, 353), Vector2(652, 371)])
	# Ghost edges converge before the solid face resolves.
	for offset in [-1.0, 1.0]:
		var distance: float = (1.0 - arrive) * 48.0 * offset
		var edge := left.duplicate() if offset < 0 else right.duplicate()
		for i in edge.size(): edge[i].x += distance
		edge.append(edge[0])
		draw_polyline(edge, Color(GOLD, alpha * (1.0 - arrive)), 1.0, true)
	_metal_polygon(left, 1.0, alpha * arrive, sweep)
	_metal_polygon(right, 1.0, alpha * arrive, sweep)
	# Warm seam flare, then an expanding shock of light that quickly dissipates.
	var impact := exp(-pow((elapsed - 2.35) * 4.0, 2.0))
	for i in range(7, 0, -1):
		draw_line(Vector2(646.5, 182), Vector2(646.5, 370), Color(IVORY, impact * 0.045 * fade), float(i) * 3.0, true)
	var progress := smoothstep(0.7, 2.2, elapsed)
	draw_line(Vector2(487, 389), Vector2(487 + 306 * progress, 389), Color(GOLD, alpha * 0.22), 1.0, true)
	# Sparse sparks drift out of the forging seam; deterministic and cheap.
	for i in 22:
		var t := maxf(elapsed - 2.25, 0.0)
		var angle := float(i) * 2.39996
		var distance := t * (27.0 + float(i % 5) * 16.0)
		var point := center + Vector2(cos(angle), sin(angle)) * distance
		var spark_alpha := exp(-t * 1.5) * smoothstep(2.2, 2.4, elapsed) * fade * 0.5
		draw_circle(point, 0.8, Color(GOLD, spark_alpha))
	draw_set_transform(origin, 0.0, Vector2.ONE * scale_factor)
	var text_alpha := _reveal(2.45, 0.75)
	var drift := (1.0 - smoothstep(2.45, 3.3, elapsed)) * 12.0
	_text("HeyaHarshu", wordmark, 54, 467 + drift, Color(IVORY, text_alpha), -1.4)
	_text("CREATIVE STUDIO", ThemeDB.fallback_font, 13, 504 + drift, Color(GOLD, text_alpha * 0.9), 6.0)
	_text("visit: heyaharshu.vercel.app", ThemeDB.fallback_font, 16, 572, Color(IVORY, _reveal(3.4, 0.8) * 0.65), 0.5)
	_text("SPACE / ENTER / A / TAP TO SKIP", ThemeDB.fallback_font, 10, 678, Color(IVORY, _reveal(4.5, 0.8) * 0.38), 1.1)
	draw_set_transform(Vector2.ZERO)

func _signature() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 4.8
	var data := PackedByteArray()
	data.resize(int(rate * seconds) * 2)
	for i in int(rate * seconds):
		var t := float(i) / rate
		var attack := smoothstep(0.0, 0.65, t)
		var tail := exp(-t * 0.85) * (1.0 - smoothstep(seconds - 1.1, seconds, t))
		var note := sin(TAU * 146.832 * t) * 0.42 + sin(TAU * 220.0 * t) * 0.23
		var upper := maxf(t - 0.65, 0.0)
		note += sin(TAU * 293.665 * upper) * 0.16 * smoothstep(0.65, 1.15, t)
		# A soft rising air texture leads into the seam impact at 2.35s.
		var air := (sin(TAU * 731.0 * t) + sin(TAU * 1117.0 * t) + sin(TAU * 1879.0 * t)) / 3.0
		var rise := sin(PI * clampf(t / 0.7, 0.0, 1.0)) * 0.08
		var hit_time := maxf(t - 0.7, 0.0)
		var hit := sin(TAU * 55.0 * hit_time) * exp(-hit_time * 4.5) * smoothstep(0.7, 0.73, t) * 0.38
		var shimmer := sin(TAU * 880.0 * hit_time) * exp(-hit_time * 2.6) * smoothstep(0.7, 0.76, t) * 0.07
		data.encode_s16(i * 2, int(clampf(note * attack * tail + air * rise + hit + shimmer, -1.0, 1.0) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream
