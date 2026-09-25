class_name CircularStat
extends Control
## Small engraved survival medallion. Existing survival signal contract is unchanged.
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
	custom_minimum_size = Vector2(56,58)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_stat_value(value: float, maximum: float) -> void:
	maximum_value = maxf(maximum,1.0)
	current_value = clampf(value,0.0,maximum_value)
	queue_redraw()

func _draw() -> void:
	var center := Vector2(size.x/2,20)
	var fraction: float = current_value/maximum_value
	var color: Color = critical_color if fraction<=0.2 else (low_color if fraction<=0.4 else healthy_color)
	draw_arc(center,17,0,TAU,64,empty_ring_color,1.5,true)
	if fraction > 0.0:
		draw_arc(center,17,-PI/2,-PI/2+TAU*fraction,64,color,ring_width,true)
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
			var crescent := PackedVector2Array()
			for step in 25:
				var angle: float = -PI * 0.5 + TAU * float(step) / 24.0
				crescent.append(center + Vector2(cos(angle),sin(angle)) * 10.0)
			for step in 25:
				var angle: float = PI * 1.5 - TAU * float(step) / 24.0
				crescent.append(center + Vector2(4, -2) + Vector2(cos(angle),sin(angle)) * 8.0)
			draw_colored_polygon(crescent,icon_color)
	var names: Array[String] = ["WATER","FOOD","STAMINA","REST"]
	var font: Font = ThemeDB.fallback_font
	draw_string(font,Vector2(0,54),names[icon_type],HORIZONTAL_ALIGNMENT_CENTER,size.x,10,Color(icon_color,0.9))
