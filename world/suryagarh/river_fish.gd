extends Node3D
## Sparse, original low-poly fish. One draw call; schools stay below the surface and off the riverbed.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const COUNT := 36
var layout := Layout.new()
var school: MultiMeshInstance3D
var fish: Array[Dictionary] = []
var elapsed := 0.0

func _ready() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[Vector2]=[Vector2(-.34,.012),Vector2(-.27,.065),Vector2(-.13,.10),Vector2(.04,.105),Vector2(.17,.064),Vector2(.28,.022)]
	for ring in range(rings.size()-1):
		for side in 8:
			var a: float=TAU*side/8.0
			var b: float=TAU*(side+1)/8.0
			var ra: Vector2=rings[ring]
			var rb: Vector2=rings[ring+1]
			var a0:=Vector3(cos(a)*ra.y,sin(a)*ra.y*.65,ra.x)
			var a1:=Vector3(cos(b)*ra.y,sin(b)*ra.y*.65,ra.x)
			var b0:=Vector3(cos(a)*rb.y,sin(a)*rb.y*.65,rb.x)
			var b1:=Vector3(cos(b)*rb.y,sin(b)*rb.y*.65,rb.x)
			for v in [a0,a1,b1,a0,b1,b0]: st.add_vertex(v)
	for tri in [[Vector3(0,0,.27),Vector3(-.12,.10,.45),Vector3(0,0,.39)],[Vector3(0,0,.27),Vector3(0,0,.39),Vector3(-.12,-.10,.45)],[Vector3(0,0,.27),Vector3(0,0,.39),Vector3(.12,.10,.45)],[Vector3(0,0,.27),Vector3(.12,-.10,.45),Vector3(0,0,.39)],
		[Vector3(0,.06,-.11),Vector3(0,.13,.02),Vector3(0,.06,.07)]]:
		for v in tri: st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color=Color(.42,.47,.34)
	mat.roughness=.75
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0,mat)
	var mm := MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.mesh=mesh
	mm.instance_count=COUNT
	school=MultiMeshInstance3D.new()
	school.name="FishSchools"
	school.multimesh=mm
	school.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	school.visibility_range_end=0
	add_child(school)
	var rng := RandomNumberGenerator.new()
	rng.seed=1857
	for i in COUNT:
		var z: float = rng.randf_range(231,239) if i<12 else (rng.randf_range(215,295) if i<28 else rng.randf_range(-380,-330))
		var center: float=layout.river_x(z)
		var x: float=(layout.river_x(235)-layout.river_width(235)+rng.randf_range(-3,6)) if i<12 else center+rng.randf_range(-layout.river_width(z)*.58,layout.river_width(z)*.58)
		var bed: float=layout.height(x,z)
		fish.append({"x":x,"z":z,"y":maxf(bed+.5,-.52 if i<12 else -2.1),"speed":rng.randf_range(.35,.85),"phase":rng.randf_range(0,TAU),"scale":rng.randf_range(.78,1.12) if i<12 else rng.randf_range(.62,1.02)})
	_update_fish()

func _process(delta: float) -> void:
	elapsed+=delta
	_update_fish()

func _update_fish() -> void:
	for i in COUNT:
		var f: Dictionary=fish[i]
		var t: float=elapsed*f.speed+f.phase
		var x: float=f.x+sin(t*.48+i)*2.6
		var z: float=f.z+cos(t*.37+i)*3.5
		var y: float=minf(-.35,f.y+sin(t*1.9)*.11)
		var direction := atan2(cos(t*.48+i)*.7,-sin(t*.37+i))
		var scale: float=f.scale
		var transform := Transform3D(Basis(Vector3.UP,direction).scaled(Vector3.ONE*scale),Vector3(x,y,z))
		school.multimesh.set_instance_transform(i,transform)
