extends Control


# =========================================================
# THE LAST MONSOON
# INTERACTION OVERLAY V3
#
# V3 CHANGES
#
# 1. Marker uses the authored interaction anchor.
# 2. Raycast is used only for visibility/occlusion.
# 3. Distant markers fade.
# 4. Focused marker is a small filled dot.
# 5. Interaction card is smaller.
# 6. Prompt stays close to the selected object.
# =========================================================


# =========================================================
# COLORS
# =========================================================

const IVORY := Color(
	0.96,
	0.95,
	0.91,
	1.0
)

const PANEL_COLOR := Color(
	0.018,
	0.018,
	0.018,
	0.86
)

const KEY_COLOR := Color(
	0.97,
	0.96,
	0.92,
	1.0
)

const KEY_TEXT_COLOR := Color(
	0.055,
	0.055,
	0.055,
	1.0
)

const HOLD_COLOR := Color(
	0.98,
	0.91,
	0.72,
	1.0
)

const GOLD := Color(
	0.76,
	0.63,
	0.39,
	1.0
)


const FONT = preload(
	"res://assets/ui/fonts/CormorantGaramond.ttf"
)


# =========================================================
# MARKER SETTINGS
# =========================================================

# No marker farther than this distance.
const MARKER_MAX_DISTANCE := 13.0

# Fully visible inside this distance.
const MARKER_FULL_VISIBILITY_DISTANCE := 5.0

# At interaction range the key card replaces the object marker.
const MARKER_HIDE_DISTANCE := 3.0

# Passive marker radius.
const PASSIVE_MARKER_RADIUS := 5.0

# Focused marker radius.
const FOCUSED_MARKER_RADIUS := 3.0


# =========================================================
# REFERENCES
# =========================================================

var actor: CharacterBody3D = null

var target: Interactable = null
var river_visible := false
var river_can_fill := false
var ride_prompt := ""


# =========================================================
# HOLD PROGRESS
# =========================================================

var progress: float = 0.0


# =========================================================
# WORLD MARKERS
# =========================================================

var markers: Array[Interactable] = []

# Instead of storing a physical raycast surface,
# we now store the object's intended UI anchor.
var marker_world_positions: Dictionary = {}


# =========================================================
# REWARD NOTIFICATIONS
# =========================================================

var rewards: Array = []

var reward_timer: float = 0.0


# =========================================================
# UI STYLES
# =========================================================

var panel_style: StyleBoxFlat

var key_background_style: StyleBoxFlat

var key_style: StyleBoxFlat


# =========================================================
# STARTUP
# =========================================================

func _ready() -> void:

	mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


	# InteractionOverlay
	# ↑ HUDRoot
	# ↑ UI
	# ↑ Player

	actor = (
		get_parent()
		.get_parent()
		.get_parent()
		as CharacterBody3D
	)


	# -----------------------------------------------------
	# MAIN PROMPT BACKGROUND
	# -----------------------------------------------------

	panel_style = StyleBoxFlat.new()

	panel_style.bg_color = PANEL_COLOR

	panel_style.set_corner_radius_all(
		8
	)


	# -----------------------------------------------------
	# BLACK BORDER AROUND KEY
	# -----------------------------------------------------

	key_background_style = StyleBoxFlat.new()

	key_background_style.bg_color = Color(
		0.008,
		0.008,
		0.008,
		0.97
	)

	key_background_style.set_corner_radius_all(
		6
	)


	# -----------------------------------------------------
	# IVORY KEY CAP
	# -----------------------------------------------------

	key_style = StyleBoxFlat.new()

	key_style.bg_color = KEY_COLOR

	key_style.set_corner_radius_all(
		4
	)


# =========================================================
# CURRENT TARGET
# =========================================================

func set_river_actions(visible: bool, can_fill: bool) -> void:
	river_visible = visible
	river_can_fill = can_fill
	queue_redraw()

func set_ride_prompt(caption: String) -> void:
	ride_prompt = caption
	queue_redraw()

func set_target(
	value: Interactable,
	hold_fraction: float = 0.0
) -> void:

	target = value

	progress = clampf(
		hold_fraction,
		0.0,
		1.0
	)

	queue_redraw()


# =========================================================
# REWARD FEED
# =========================================================

func show_rewards(
	lines: Array
) -> void:

	rewards = lines.duplicate()

	reward_timer = 3.0

	queue_redraw()


# =========================================================
# UPDATE INTERACTION MARKERS
# =========================================================

func _physics_process(
	delta: float
) -> void:

	if actor == null:

		return


	if reward_timer > 0.0:

		reward_timer = maxf(
			0.0,
			reward_timer - delta
		)


	markers.clear()

	marker_world_positions.clear()


	var camera := (
		get_viewport()
		.get_camera_3d()
	)


	if camera == null:

		queue_redraw()

		return


	var world := actor.get_world_3d()


	if world == null:

		return


	var space := (
		world.direct_space_state
	)


	# =====================================================
	# FIND VISIBLE INTERACTABLES
	# =====================================================

	for node in (
		get_tree()
		.get_nodes_in_group(
			"interactables"
		)
	):

		var candidate := (
			node as Interactable
		)


		if candidate == null:

			continue


		if not candidate.interaction_available():

			continue


		# -------------------------------------------------
		# IMPORTANT
		#
		# This is now the UI position.
		#
		# NOT the raycast collision point.
		# -------------------------------------------------

		var anchor := (
			candidate.interaction_anchor()
		)


		var distance := (
			actor.global_position
			.distance_to(
				anchor
			)
		)


		if distance > MARKER_MAX_DISTANCE:

			continue


		if camera.is_position_behind(
			anchor
		):

			continue


		# -------------------------------------------------
		# OCCLUSION TEST
		#
		# Raycast decides:
		#
		# "Can the player actually see this object?"
		#
		# It does NOT decide where the marker is drawn.
		# -------------------------------------------------

		var query := (
			PhysicsRayQueryParameters3D
			.create(
				camera.global_position,
				anchor
			)
		)


		query.exclude = [
			actor.get_rid()
		]


		var hit := (
			space.intersect_ray(
				query
			)
		)


		if hit.is_empty() and candidate != target:

			continue


		var collider = (
			hit.get(
				"collider"
			)
		)


		if (
			candidate != target
			and
			collider != candidate
			and not candidate.is_ancestor_of(
				collider
			)
		):

			continue


		marker_world_positions[
			candidate
		] = anchor

		if distance > MARKER_HIDE_DISTANCE:
			markers.append(candidate)


	queue_redraw()


# =========================================================
# MARKER ALPHA BASED ON DISTANCE
# =========================================================

func _marker_alpha(
	candidate: Interactable
) -> float:

	if actor == null:

		return 1.0


	var distance := (
		actor.global_position
		.distance_to(
			candidate.interaction_anchor()
		)
	)


	if (
		distance
		<= MARKER_FULL_VISIBILITY_DISTANCE
	):

		return 0.90


	var fade_range := (
		MARKER_MAX_DISTANCE
		- MARKER_FULL_VISIBILITY_DISTANCE
	)


	var fade_position := (
		distance
		- MARKER_FULL_VISIBILITY_DISTANCE
	)


	var fraction := (
		fade_position
		/ fade_range
	)


	return lerpf(
		0.90,
		0.20,
		clampf(
			fraction,
			0.0,
			1.0
		)
	)


# =========================================================
# DRAW INTERACTION ICON
# =========================================================

func _shape(center: Vector2, offsets: Array[Vector2], color: Color) -> void:
	var points := PackedVector2Array()
	for offset in offsets: points.append(center + offset)
	draw_colored_polygon(points, color)

func _icon(center: Vector2, kind: String, color: Color) -> void:
	match kind:
		"water":
			_shape(center, [Vector2(0,-9),Vector2(7,2),Vector2(6,7),Vector2(2,9),Vector2(-2,9),Vector2(-6,7),Vector2(-7,2)], color)
		"food", "mango":
			draw_circle(center + Vector2(-3,2), 5.0, color)
			draw_circle(center + Vector2(3,2), 5.0, color)
			_shape(center + Vector2(1,-7), [Vector2(0,0),Vector2(7,-2),Vector2(4,2)], color)
		"ammo", "chest", "crate":
			draw_rect(Rect2(center + Vector2(-8,-3),Vector2(16,11)), color)
			draw_rect(Rect2(center + Vector2(-9,-7),Vector2(18,4)), color)
			draw_rect(Rect2(center + Vector2(-1,-6),Vector2(2,14)), KEY_TEXT_COLOR)
		"weapon":
			_shape(center, [Vector2(-9,3),Vector2(3,-3),Vector2(8,-3),Vector2(8,-1),Vector2(1,0),Vector2(-1,5),Vector2(-5,5),Vector2(-5,7),Vector2(-9,7)], color)
		"medicine":
			draw_rect(Rect2(center+Vector2(-2,-8),Vector2(4,16)),color)
			draw_rect(Rect2(center+Vector2(-8,-2),Vector2(16,4)),color)
		"gate":
			draw_rect(Rect2(center+Vector2(-7,-8),Vector2(14,16)),color)
			draw_circle(center+Vector2(3,1),1.5,KEY_TEXT_COLOR)
		"horse", "vehicle":
			_shape(center,[Vector2(-8,-3),Vector2(5,-3),Vector2(8,3),Vector2(4,3),Vector2(3,8),Vector2(0,8),Vector2(-1,3),Vector2(-6,3)],color)
		_:
			draw_circle(center,5.0,color)
			draw_rect(Rect2(center+Vector2(-2,3),Vector2(4,6)),color)

func _draw_action(at: Vector2, key: String, kind: String, count: int = 0) -> void:
	_draw_key(at, key)
	var key_width := 64.0 if key.length() > 2 else 27.0
	_icon(at + Vector2(key_width+15.0,13), kind, IVORY)
	if count > 0:
		draw_string(ThemeDB.fallback_font, at + Vector2(key_width+29.0,19), "×%d" % count, HORIZONTAL_ALIGNMENT_LEFT, 46, 14, IVORY)

# =========================================================
# DRAW OVERLAY
# =========================================================

func _draw() -> void:

	var camera := (
		get_viewport()
		.get_camera_3d()
	)


	if camera == null:

		return


	# =====================================================
	# WORLD MARKERS
	# =====================================================

	for candidate in markers:


		if not is_instance_valid(
			candidate
		):

			continue


		if not marker_world_positions.has(
			candidate
		):

			continue


		var world_position: Vector3 = (
			marker_world_positions[
				candidate
			]
		)


		var point := (
			camera.unproject_position(
				world_position
			)
		)


		if not Rect2(
			Vector2.ZERO,
			size
		).has_point(
			point
		):

			continue


		# -------------------------------------------------
		# SELECTED OBJECT
		# -------------------------------------------------

		if candidate == target:

			# Small soft halo.

			draw_circle(
				point,
				5.3,
				Color(
					0.96,
					0.95,
					0.91,
					0.10
				)
			)


			# Small filled reference-style dot.

			draw_circle(
				point,
				FOCUSED_MARKER_RADIUS,
				IVORY
			)


		# -------------------------------------------------
		# PASSIVE OBJECT
		# -------------------------------------------------

		else:

			var alpha := (
				_marker_alpha(
					candidate
				)
			)


			draw_circle(point,PASSIVE_MARKER_RADIUS * 0.55,Color(0.96,0.95,0.91,alpha))


	# =====================================================
	# FOCUSED INTERACTION CARD
	# =====================================================

	if (
		is_instance_valid(target)
		and target.interaction_available()
		and marker_world_positions.has(target)
	):

		var anchor := (
			camera.unproject_position(
				marker_world_positions[
					target
				]
			)
		)


		var secondary := (
			target.has_secondary_interaction()
		)


		var secondary_key := "L1+□" if SaveManager.active_input_device == "controller" else "Shift+E"
		var primary_key := "□" if SaveManager.active_input_device == "controller" else "E"
		var row_count := 2 if secondary else 1
		var panel_width := 127.0 if secondary else (98.0 if target.get("count") != null and int(target.get("count")) > 0 else 69.0)
		var panel_height := 8.0 + 30.0 * row_count
		var left := clampf(anchor.x + 12.0, 10.0, size.x-panel_width-10.0)
		var top := clampf(anchor.y-panel_height*0.5,10.0,size.y-panel_height-10.0)
		draw_style_box(panel_style,Rect2(left,top,panel_width,panel_height))
		var item_count: int = target.get("count") if target.get("count") != null else 0
		_draw_action(Vector2(left+5,top+4),primary_key,target.interaction_icon,item_count)
		if secondary:
			_draw_action(Vector2(left+5,top+34),secondary_key,target.interaction_icon)
		if target.hold_duration > 0.0:
			draw_arc(Vector2(left+18,top+17),17.0,-PI*0.5,-PI*0.5+TAU*progress,32,HOLD_COLOR,2.0,true)
	elif ride_prompt != "":
		var ride_top := size.y * 0.62
		var ride_left := size.x * 0.5 - 34.5
		draw_style_box(panel_style,Rect2(ride_left,ride_top,69.0,38.0))
		_draw_action(Vector2(ride_left+5,ride_top+4),"△" if SaveManager.active_input_device == "controller" else "F","horse")
	elif river_visible:
		var river_top := size.y * 0.62
		var river_left := size.x * 0.5 - 34.5
		draw_style_box(panel_style,Rect2(river_left,river_top,69.0,38.0))
		_draw_action(Vector2(river_left+5,river_top+4),"□" if SaveManager.active_input_device == "controller" else "E","water")


	# =====================================================
	# REWARD FEED
	# =====================================================

	if (
		reward_timer > 0.0
		and not rewards.is_empty()
	):

		var start_y := (
			size.y * 0.43
		)


		for i in range(
			rewards.size()
		):

			var text_value := str(
				rewards[i]
			)


			var position := Vector2(
				size.x - 300.0,
				start_y
				+ float(i) * 31.0
			)


			# Shadow

			draw_string(
				FONT,
				position
				+ Vector2(
					1.5,
					1.5
				),
				text_value,
				HORIZONTAL_ALIGNMENT_RIGHT,
				260.0,
				20,
				Color(
					0,
					0,
					0,
					0.72
				)
			)


			# Main reward text

			draw_string(
				FONT,
				position,
				text_value,
				HORIZONTAL_ALIGNMENT_RIGHT,
				260.0,
				20,
				IVORY
			)


# =========================================================
# KEY CAP
# =========================================================

func _draw_key(
	at: Vector2,
	label: String
) -> void:
	var key_width := 64.0 if label.length() > 2 else 27.0

	# Outer black backing.

	draw_style_box(
		key_background_style,
		Rect2(
			at,
			Vector2(
				key_width,
				26
			)
		)
	)


	# Inner ivory button.

	draw_style_box(
		key_style,
		Rect2(
			at
			+ Vector2(
				3,
				3
			),
			Vector2(
				key_width-6.0,
				20
			)
		)
	)


	var font_size := (
		11
		if label.length() > 1
		else 16
	)


	draw_string(
		ThemeDB.fallback_font,
		at
		+ Vector2(
			3,
			19
		),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		key_width-6.0,
		font_size,
		KEY_TEXT_COLOR
	)
