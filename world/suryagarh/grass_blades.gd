extends RefCounted
## Shared nested grass LOD: six core blades + eighteen nearby detail blades.
## No physics/process nodes or transparent foliage cards.
static var habitat_noise: FastNoiseLite

static func habitat_height(layout: RefCounted, point: Vector2, road_distance: float) -> float:
	# Dry bank grass and uncultivated verge patches; paths/crops stay short.
	var bank_distance: float = absf(point.x-layout.river_x(point.y))-layout.river_width(point.y)
	var bank: float = smoothstep(5.0,16.0,bank_distance)*(1.0-smoothstep(42.0,72.0,bank_distance))
	var verge: float = smoothstep(6.0,11.0,road_distance)*(1.0-smoothstep(30.0,55.0,road_distance))
	var wild: float = 1.0-smoothstep(.15,.45,layout.field_mask(point.x,point.y))
	if habitat_noise == null:
		habitat_noise = FastNoiseLite.new()
		habitat_noise.seed = 1857
		habitat_noise.frequency = .035
		habitat_noise.fractal_octaves = 3
	var patch: float = smoothstep(-.32,.30,habitat_noise.get_noise_2d(point.x,point.y))
	# Smaller variations break up the height of blades within the same patch.
	patch *= .8+.2*smoothstep(-.4,.4,habitat_noise.get_noise_2d(point.x*3.7,point.y*3.7))
	return 1.0+wild*patch*maxf(bank*4.0,verge*2.5)

static func placement_allowed(layout: RefCounted, point: Vector2, height: float, road_distance: float) -> bool:
	# Reserve whole surveyed plots, plus a buffer for tips, wind and vehicle bending.
	if layout.plot_clearance(point.x,point.y) < 10.0 or layout.built_area(point.x,point.y): return false
	if road_distance < 6.5 or height < 1.8 or height > 95.0: return false
	# Crops occupy cultivated interiors; wild grass can grow only along field margins.
	if layout.field_mask(point.x,point.y) > .45: return false
	if point.distance_to(Vector2(-310,230)) < 70.0: return false
	return true

static func habitat_density(layout: RefCounted, point: Vector2, road_distance: float) -> float:
	var growth: float = habitat_height(layout,point,road_distance)
	var patch: float = smoothstep(-.4,.4,habitat_noise.get_noise_2d(point.x*1.8,point.y*1.8))
	var field_edge: float = 1.0-smoothstep(.1,.45,layout.field_mask(point.x,point.y))
	# Moist banks/verges fill out, with sparse edges rather than a uniform carpet.
	return clampf((.50+.32*patch+.16*(growth-1.0)/4.0)*field_edge,.08,.98)

static func make_mesh(detail := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blades := RandomNumberGenerator.new()
	blades.seed = 1857 if not detail else 1858
	for i in (18 if detail else 6):
		var angle := blades.randf_range(0,TAU)
		var across := Vector3(cos(angle),0,sin(angle))
		var radius := blades.randf_range(.012,.075)
		var base := Vector3(cos(angle)*radius,0,sin(angle)*radius)
		var height := blades.randf_range(.10,.27) if detail else blades.randf_range(.09,.23)
		var width := blades.randf_range(.002,.005)
		var bend := Vector3(-sin(angle),0,cos(angle))*height*blades.randf_range(.16,.42)
		var green := Color(.32,.46,.19).lerp(Color(.43,.50,.25),blades.randf()*.75).srgb_to_linear()
		var strips: Array[Vector3] = []
		for segment in 4:
			var t := float(segment)/3.0
			var center := base+Vector3.UP*height*t+bend*t*t
			var half_width := width*(1.0-t)*(.8+.2*sin(t*PI))
			strips.append(center-across*half_width)
			strips.append(center+across*half_width)
		for segment in 3:
			var a := segment*2
			var indices := [a,a+1,a+3,a,a+3,a+2] if segment < 2 else [a,a+1,a+2]
			for index in indices:
				var v: Vector3 = strips[index]
				st.set_color(green)
				st.set_uv(Vector2(float(i)/16.0,v.y/height))
				st.add_vertex(v)
	st.generate_normals()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://world/suryagarh/shaders/grass_blades.gdshader")
	mat.set_shader_parameter("fade_start",18.0 if detail else 48.0)
	mat.set_shader_parameter("fade_end",30.0 if detail else 70.0)
	st.set_material(mat)
	return st.commit()

static func surface_frame(layout: RefCounted, origin: Vector2, point: Vector2, step: float) -> Transform3D:
	# Same a,b,c / b,d,c triangles as the terrain bake, rather than analytic height.
	var cell := ((point-origin)/step).floor()*step+origin
	var uv := (point-cell)/step
	var a: float = layout.height(cell.x,cell.y)
	var b: float = layout.height(cell.x+step,cell.y)
	var c: float = layout.height(cell.x,cell.y+step)
	var d: float = layout.height(cell.x+step,cell.y+step)
	var h := a+(b-a)*uv.x+(c-a)*uv.y if uv.x+uv.y <= 1.0 else d+(c-d)*(1.0-uv.x)+(b-d)*(1.0-uv.y)
	var dx := (b-a)/step if uv.x+uv.y <= 1.0 else (d-c)/step
	var dz := (c-a)/step if uv.x+uv.y <= 1.0 else (d-b)/step
	# Shear the root plane onto the slope, keeping growth aligned with gravity.
	return Transform3D(Basis(Vector3(1,dx,0),Vector3.UP,Vector3(0,dz,1)),Vector3(point.x,h,point.y))

static func baked_frame(vertices: PackedVector3Array,origin: Vector2,point: Vector2,step: float,tile_size: float) -> Transform3D:
	var local := (point-origin)/step
	var cell := local.floor()
	var uv := local-cell
	var stride := int(round(tile_size/step))+1
	var index := int(cell.y)*stride+int(cell.x)
	var a := vertices[index].y
	var b := vertices[index+1].y
	var c := vertices[index+stride].y
	var d := vertices[index+stride+1].y
	var first := uv.x+uv.y <= 1.0
	var h := a+(b-a)*uv.x+(c-a)*uv.y if first else d+(c-d)*(1.0-uv.x)+(b-d)*(1.0-uv.y)
	var dx := (b-a)/step if first else (d-c)/step
	var dz := (c-a)/step if first else (d-b)/step
	return Transform3D(Basis(Vector3(1,dx,0),Vector3.UP,Vector3(0,dz,1)),Vector3(point.x,h,point.y))
