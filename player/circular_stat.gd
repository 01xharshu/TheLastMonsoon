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
	custom_minimum_size = Vector2(64,68)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_stat_value(value: float, maximum: float) -> void:
	maximum_value = maxf(maximum,1.0)
	current_value = clampf(value,0.0,maximum_value)
	queue_redraw()

func _draw() -> void:
	var center := Vector2(size.x/2,25)
	var fraction: float = current_value/maximum_value
	var color: Color = critical_color if fraction<=0.2 else (low_color if fraction<=0.4 else healthy_color)
	draw_arc(center,20,0,TAU,64,empty_ring_color,1,true)
	draw_arc(center,20,-PI/2,-PI/2+TAU*fraction,64,color,ring_width,true)
	for i in 4:
		var dir := Vector2.from_angle(PI*0.5*i)
		draw_line(center+dir*23,center+dir*26,Color(icon_color,0.45),1,true)
	match icon_type:
		0:
			var points := PackedVector2Array([center+Vector2(0,-10),center+Vector2(7,2),center+Vector2(5,8),center+Vector2(0,10),center+Vector2(-5,8),center+Vector2(-7,2),center+Vector2(0,-10)])
			draw_polyline(points,icon_color,1.5,true)
		1:
			draw_line(center+Vector2(-2,11),center+Vector2(2,-10),icon_color,1.4,true)
			for i in 3:
				var y: float = -6+i*5
				draw_line(center+Vector2(1,y+3),center+Vector2(7,y-2),icon_color,2,true)
				draw_line(center+Vector2(0,y+2),center+Vector2(-6,y-3),icon_color,2,true)
		2:
			draw_arc(center+Vector2(-4,2),4,0,TAU,20,icon_color,1.5,true)
			draw_arc(center+Vector2(5,-5),3,0,TAU,20,icon_color,1.5,true)
			draw_line(center+Vector2(-6,8),center+Vector2(-3,11),icon_color,2,true)
		3:
			draw_arc(center,9,PI*0.25,PI*1.72,32,icon_color,1.5,true)
			draw_arc(center+Vector2(5,-3),8,PI*0.38,PI*1.45,24,icon_color,1.5,true)
	var names: Array[String] = ["WATER","FOOD","STAMINA","REST"]
	var font: Font = ThemeDB.fallback_font
	draw_string(font,Vector2(0,62),names[icon_type],HORIZONTAL_ALIGNMENT_CENTER,size.x,10,Color(icon_color,0.85))
