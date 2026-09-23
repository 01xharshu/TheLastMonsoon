extends SceneTree
## One-time terrain raster; opening the map performs no height/noise generation.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const OUT := "res://world/suryagarh/generated/field_map.res"
var layout := Layout.new()

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	const PIXELS := 1024
	var image := Image.create(PIXELS,PIXELS,false,Image.FORMAT_RGB8)
	for y in PIXELS:
		for x in PIXELS:
			var p := (Vector2(x+0.5,y+0.5)/PIXELS-Vector2.ONE*0.5)*Layout.SIZE
			var h: float = layout.height(p.x,p.y)
			var color := Color(0.77,0.72,0.55)
			if h < 0.0:
				color = Color(0.36,0.53,0.54)
			elif h > 18.0:
				color = Color(0.43,0.49,0.33).lerp(Color(0.68,0.61,0.46),clampf(h/140.0,0.0,1.0))
			elif layout.field_mask(p.x,p.y)>0.5:
				color = Color(0.65,0.65,0.43)
			var contour: float = absf(fposmod(h,10.0)-5.0)
			if h > 5.0 and contour > 4.68: color = color.darkened(0.09)
			image.set_pixel(x,y,color)
	var texture := ImageTexture.create_from_image(image)
	assert(ResourceSaver.save(texture,OUT,ResourceSaver.FLAG_COMPRESS)==OK)
	print("FIELD MAP BAKE PASS ",OUT," ",PIXELS,"x",PIXELS)
	quit()
