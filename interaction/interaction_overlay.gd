extends Control
## Small world marker, contextual key card, hold arc, and short reward notices.
const IVORY := Color(.94,.92,.84)
const GOLD := Color(.76,.63,.39)
const INK := Color(.055,.064,.055,.88)
const FONT = preload("res://assets/ui/fonts/CormorantGaramond.ttf")
var actor: CharacterBody3D
var target: Interactable
var progress := 0.0
var markers: Array[Interactable] = []
var surface_points: Dictionary = {}
var panel_style: StyleBoxFlat
var key_style: StyleBoxFlat
var key_shadow: StyleBoxFlat
var focus_light: OmniLight3D
var rewards: Array = []
var reward_timer := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	actor = get_parent().get_parent().get_parent() as CharacterBody3D
	panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(.035,.034,.034,.76)
	panel_style.set_corner_radius_all(9)
	key_shadow = StyleBoxFlat.new()
	key_shadow.bg_color = Color(.015,.015,.016,.94)
	key_shadow.set_corner_radius_all(8)
	key_style = StyleBoxFlat.new()
	key_style.bg_color = Color(.98,.97,.94,.98)
	key_style.set_corner_radius_all(4)
	focus_light = OmniLight3D.new()
	focus_light.name = "InteractionSurfaceGlint"
	focus_light.light_color = Color(.96,.84,.63)
	focus_light.light_energy = .18
	focus_light.omni_range = .65
	focus_light.shadow_enabled = false
	focus_light.visible = false
	actor.add_child.call_deferred(focus_light)

func set_target(value: Interactable, hold_fraction := 0.0) -> void:
	target = value
	progress = clampf(hold_fraction,0.0,1.0)
	queue_redraw()

func show_rewards(lines: Array) -> void:
	rewards = lines.duplicate()
	reward_timer = 3.4
	queue_redraw()

func _physics_process(delta: float) -> void:
	if actor == null: return
	if reward_timer > 0.0:
		reward_timer = maxf(0.0,reward_timer-delta)
	markers.clear()
	surface_points.clear()
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var space := actor.get_world_3d().direct_space_state
	for node in get_tree().get_nodes_in_group("interactables"):
		var candidate := node as Interactable
		if candidate == null or not candidate.interaction_available(): continue
		var anchor := candidate.interaction_anchor()
		if actor.global_position.distance_to(anchor) > 18.0 or camera.is_position_behind(anchor): continue
		var query := PhysicsRayQueryParameters3D.create(camera.global_position,anchor)
		query.exclude = [actor.get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and hit.collider != candidate and not candidate.is_ancestor_of(hit.collider): continue
		if hit.is_empty(): continue
		surface_points[candidate] = hit.position + hit.normal * .025
		if actor.global_position.distance_to(candidate.global_position) > 2.6:
			markers.append(candidate)
	if focus_light.is_inside_tree():
		focus_light.visible = is_instance_valid(target) and surface_points.has(target)
		if focus_light.visible: focus_light.global_position = surface_points[target]
	queue_redraw()

func _icon(center: Vector2, kind: String, color: Color) -> void:
	match kind:
		"chest":
			draw_rect(Rect2(center-Vector2(7,4),Vector2(14,10)),color,false,1.5)
			draw_line(center+Vector2(-6,-5),center+Vector2(6,-5),color,1.5)
			draw_circle(center+Vector2(0,1),1.5,color)
		"weapon":
			draw_line(center+Vector2(-6,5),center+Vector2(6,-7),color,2)
			draw_line(center+Vector2(-7,1),center+Vector2(-3,5),color,2)
		"gate":
			draw_rect(Rect2(center-Vector2(6,7),Vector2(12,14)),color,false,1.5)
			draw_circle(center+Vector2(3,1),1.2,color)
		"loot":
			draw_circle(center,5,color)
			draw_line(center+Vector2(-7,7),center+Vector2(7,7),color,1.5)
		_:
			draw_circle(center,3,color)
			draw_line(center+Vector2(-6,6),center+Vector2(6,6),color,1.5)

func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	for candidate in markers:
		if not is_instance_valid(candidate) or not candidate.interaction_available(): continue
		var point := camera.unproject_position(surface_points[candidate])
		if not Rect2(Vector2.ZERO,size).has_point(point): continue
		draw_circle(point,9.0,Color(.96,.95,.91,.09))
		draw_circle(point,5.0,Color(.035,.034,.034,.69))
		draw_arc(point,5.0,0.0,TAU,24,Color(.96,.95,.91,.86),1.3,true)
		draw_circle(point+Vector2(-1.4,-1.4),1.2,Color.WHITE)
	if is_instance_valid(target) and target.interaction_available() and surface_points.has(target):
		var anchor := camera.unproject_position(surface_points[target])
		var alternate := target.has_secondary_interaction()
		var width := 220.0 if alternate else 140.0
		var left := clampf(anchor.x-width*.5,12.0,size.x-width-12.0)
		var top := clampf(anchor.y-83.0,72.0,size.y-105.0)
		var box := Rect2(left,top,width,58)
		draw_style_box(panel_style,box)
		var key := "□" if SaveManager.active_input_device == "controller" else "E"
		var key_x := left+14.0 if not alternate else left+91.0
		if alternate:
			_icon(Vector2(left+24,top+29),"hand",IVORY)
			_draw_key(Vector2(left+42,top+8),"L1" if SaveManager.active_input_device == "controller" else "Q")
		_draw_key(Vector2(key_x,top+8),key)
		_icon(Vector2(key_x+70,top+29),target.interaction_icon,IVORY)
		if target.hold_duration > 0.0:
			draw_arc(Vector2(key_x+22,top+29),26.0,-PI*.5,-PI*.5+TAU*progress,40,Color(.98,.94,.80),3.0,true)
	if reward_timer > 0.0:
		var width := 254.0
		var left := size.x-width-24.0
		for i in rewards.size():
			var y := size.y*.45+float(i)*36.0
			draw_rect(Rect2(left,y,width,31),INK)
			draw_rect(Rect2(left,y,width,31),Color(GOLD,.62),false,1.0)
			draw_string(FONT,Vector2(left+13,y+22),rewards[i],HORIZONTAL_ALIGNMENT_LEFT,int(width-25),20,IVORY)

func _draw_key(at: Vector2, label: String) -> void:
	draw_style_box(key_shadow,Rect2(at,Vector2(44,43)))
	draw_style_box(key_style,Rect2(at+Vector2(5,4),Vector2(34,33)))
	draw_string(ThemeDB.fallback_font,at+Vector2(5,29),label,HORIZONTAL_ALIGNMENT_CENTER,34,19 if label.length()>1 else 23,Color(.07,.07,.07))
