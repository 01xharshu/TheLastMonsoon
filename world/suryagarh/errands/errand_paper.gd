extends Control
## Original procedural paper; the supplied screenshot is a layout reference only.
var title := "WORK NOTICE"
var body := ""
const FONT = preload("res://assets/ui/fonts/MFBOldstyle-Regular.otf")

func _draw() -> void:
	var r := Rect2(Vector2(10,8),size-Vector2(20,16))
	draw_style_box(_paper_style(),r)
	var random := RandomNumberGenerator.new(); random.seed = 1857
	for i in 170:
		var at := r.position+Vector2(random.randf()*r.size.x,random.randf()*r.size.y)
		draw_line(at,at+Vector2(random.randf_range(3,22),random.randf_range(-3,3)),Color(.40,.28,.16,.055),1)
	for i in 14:
		var y := random.randf_range(20,size.y-20)
		var x := 10.0 if i%2 == 0 else size.x-10
		var inward := 1.0 if i%2 == 0 else -1.0
		draw_polyline(PackedVector2Array([Vector2(x,y),Vector2(x+inward*11,y+3),Vector2(x+inward*18,y+1)]),Color(.38,.26,.15,.19),1)
	var center := Vector2(size.x*.5,58)
	draw_arc(center,37,0,TAU,48,Color(.28,.19,.10),1.2)
	draw_string(FONT,Vector2(center.x-25,64),"WORK",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(.28,.19,.10))
	draw_line(Vector2(35,122),Vector2(size.x-35,122),Color(.28,.19,.10),1)
	draw_line(Vector2(35,126),Vector2(size.x-35,126),Color(.28,.19,.10),1)
	draw_string(FONT,Vector2(35,size.y-48),"Bhairavpur market office",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(.28,.19,.10))

func _paper_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color = Color(.77,.66,.49)
	style.corner_radius_top_left = 4; style.corner_radius_bottom_right = 7
	style.shadow_color = Color(0,0,0,.6); style.shadow_size = 8
	return style
