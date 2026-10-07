class_name CircularStat
extends Control
## Engraved diamond survival gauge. Existing survival signal contract is unchanged.
@export_enum("Hydration","Satiety","Stamina","Energy") var icon_type: int = 0:
	set(value):
		icon_type = value
		queue_redraw()
@export var ring_width: float = 2.0
@export var healthy_color := Color(0.87,0.81,0.66)
@export var low_color := Color(0.81,0.56,0.23)
@export var critical_color := Color(0.79,0.25,0.17)
@export var empty_ring_color := Color(0.69,0.59,0.39,0.22)
@export var icon_color := Color(0.91,0.86,0.72)
var current_value: float = 100.0
var maximum_value: float = 100.0

func _ready() -> void:
	custom_minimum_size = Vector2(48,48)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_stat_value(value: float, maximum: float) -> void:
	maximum_value = maxf(maximum,1.0)
	current_value = clampf(value,0.0,maximum_value)
	queue_redraw()

func _draw() -> void:
	var center := size*0.5
	var fraction: float = current_value/maximum_value
	var color: Color = critical_color if fraction<=0.2 else (low_color if fraction<=0.4 else healthy_color)
	var outline := PackedVector2Array([center+Vector2(0,-22),center+Vector2(22,0),center+Vector2(0,22),center+Vector2(-22,0),center+Vector2(0,-22)])
	draw_colored_polygon(outline,Color(0.035,0.042,0.035,0.76))
	draw_polyline(outline,Color(0.61,0.47,0.27,0.85),1,true)
	draw_line(outline[3],outline[0],Color(icon_color,0.65),1,true)
	draw_line(outline[0],outline[1],Color(icon_color,0.65),1,true)
	var inset := PackedVector2Array([center+Vector2(0,-19),center+Vector2(19,0),center+Vector2(0,19),center+Vector2(-19,0),center+Vector2(0,-19)])
	draw_polyline(inset,empty_ring_color,ring_width,true)
	# Clip the inset diamond at the level height, filling its interior from the bottom.
	var fill_y: float = center.y+19.0-fraction*38.0
	var filled := PackedVector2Array()
	for edge in 4:
		var a: Vector2 = inset[edge]
		var b: Vector2 = inset[edge+1]
		if a.y >= fill_y: filled.append(a)
		if (a.y >= fill_y) != (b.y >= fill_y):
			filled.append(a.lerp(b,(fill_y-a.y)/(b.y-a.y)))
	if fraction > 0.0 and filled.size() >= 3: draw_colored_polygon(filled,Color(color,0.38))
	# Solid ivory symbols stay distinct from the muted interior level.
	match icon_type:
		0:
			draw_colored_polygon(PackedVector2Array([center+Vector2(0,-11),center+Vector2(8,2),center+Vector2(7,7),center+Vector2(3,10),center+Vector2(-3,10),center+Vector2(-7,7),center+Vector2(-8,2)]),icon_color)
		1:
			draw_rect(Rect2(center+Vector2(-1.5,-10),Vector2(3,21)),icon_color)
			for row in 3:
				var y: float = -8.0 + float(row) * 5.0
				draw_colored_polygon(PackedVector2Array([center+Vector2(-2,y+5),center+Vector2(-9,y-1),center+Vector2(-8,y+4)]),icon_color)
				draw_colored_polygon(PackedVector2Array([center+Vector2(2,y+5),center+Vector2(9,y-1),center+Vector2(8,y+4)]),icon_color)
		2:
			draw_colored_polygon(PackedVector2Array([center+Vector2(1,-12),center+Vector2(-7,1),center+Vector2(-1,1),center+Vector2(-4,12),center+Vector2(8,-3),center+Vector2(2,-3)]),icon_color)
		3:
			draw_colored_polygon(PackedVector2Array([center+Vector2(1,-11),center+Vector2(-7,-8),center+Vector2(-11,0),center+Vector2(-7,8),center+Vector2(1,11),center+Vector2(7,7),center+Vector2(1,8),center+Vector2(-2,5),center+Vector2(-4,0),center+Vector2(-2,-5),center+Vector2(1,-8)]),icon_color)
