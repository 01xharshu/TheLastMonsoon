extends Label
## Screen-space location discovery using the current surveyed world plots.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const TITLES := {"Bhairavpur":"Bhairavpur", "BhairavpurEstate":"Estate Office", "TownHall":"Government Office", "DistrictPolice":"Thana", "CompanyCompound":"Company Compound", "GovernmentHouse":"Government House", "OldFort":"Old Fort · Company Outpost"}
var current_area := ""
var candidate_area := ""
var candidate_time := 0.0
var animation: Tween
var actor: Node3D

func _ready() -> void:
	actor = get_parent().get_parent().get_parent() as Node3D
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_override("font", preload("res://assets/ui/fonts/MFBOldstyle-Regular.otf"))
	add_theme_font_size_override("font_size", 28)
	add_theme_color_override("font_color", Color(0.92, 0.88, 0.76))
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	add_theme_constant_override("shadow_offset_y", 2)
	modulate.a = 0.0
	get_parent().resized.connect(_layout)
	_layout()

func _layout() -> void:
	position = Vector2(0, 108)
	size = Vector2(get_parent().size.x, 42)

func area_at(point: Vector2) -> String:
	# Retain the active area within an extra 8 m to avoid edge jitter.
	if not current_area.is_empty() and _contains(current_area, point, 20.0):
		# A smaller office inside the village must still override its parent.
		if current_area == "Bhairavpur" and _contains("BhairavpurEstate", point, 12.0):
			return "BhairavpurEstate"
		return current_area
	for key: String in ["BhairavpurEstate", "DistrictPolice", "TownHall", "GovernmentHouse", "CompanyCompound", "OldFort", "Bhairavpur"]:
		if _contains(key, point, 12.0): return key
	return ""

func _contains(key: String, point: Vector2, margin: float) -> bool:
	var plot: Dictionary = Layout.PLOTS[key]
	var offset: Vector2 = (point - plot.center).abs()
	return offset.x <= plot.half.x + margin and offset.y <= plot.half.y + margin

func _process(delta: float) -> void:
	# Isolated character/fort fixtures do not use Suryagarh world coordinates.
	if not is_instance_valid(actor) or actor.get_parent() == null or not actor.get_parent().has_method("move_to_review_point"): return
	# Discovery titles join the compass only after its existing tutorial reveal.
	var hud := get_parent()
	if "tutorial_reveal" in hud and hud.tutorial_reveal < 9:
		visible = false
		return
	visible = true
	var point := Vector2(actor.global_position.x, actor.global_position.z)
	update_area(point, delta)

func update_area(point: Vector2, delta: float) -> void:
	var next := area_at(point)
	if next != candidate_area:
		candidate_area = next
		candidate_time = 0.0
	candidate_time += delta
	if candidate_time < 0.25 or next == current_area: return
	current_area = next
	if animation and animation.is_valid(): animation.kill()
	if next.is_empty():
		animation = create_tween()
		animation.tween_property(self, "modulate:a", 0.0, 0.25)
		return
	text = TITLES[next]
	modulate.a = 0.0
	animation = create_tween()
	animation.tween_property(self, "modulate:a", 1.0, 0.35)
	animation.tween_interval(1.0)
	animation.tween_property(self, "modulate:a", 0.0, 0.55)
