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
	var body := [Vector3(0,0,-.36),Vector3(-.1,.065,0),Vector3(.1,.065,0),Vector3(-.1,-.065,0),Vector3(.1,-.065,0),Vector3(0,0,.25)]
	for tri in [[0,1,2],[0,4,3],[0,3,1],[0,2,4],[5,2,1],[5,3,4],[5,1,3],[5,4,2]]:
		for idx in tri: st.add_vertex(body[idx])
	for tri in [[Vector3(0,0,.25),Vector3(-.15,.13,.46),Vector3(-.15,-.13,.46)],[Vector3(0,0,.25),Vector3(.15,-.13,.46),Vector3(.15,.13,.46)]]:
		for v in tri: st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color=Color(.19,.25,.18)
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
	school.visibility_range_end=75
	add_child(school)
	var rng := RandomNumberGenerator.new()
	rng.seed=1857
	for i in COUNT:
		var z: float = rng.randf_range(231,239) if i<12 else (rng.randf_range(215,295) if i<28 else rng.randf_range(-380,-330))
		var center: float=layout.river_x(z)
		var x: float=(layout.river_x(235)-layout.river_width(235)+rng.randf_range(-3,6)) if i<12 else center+rng.randf_range(-layout.river_width(z)*.58,layout.river_width(z)*.58)
		var bed: float=layout.height(x,z)
		fish.append({"x":x,"z":z,"y":maxf(bed+.5,-.52 if i<12 else -2.1),"speed":rng.randf_range(.35,.85),"phase":rng.randf_range(0,TAU),"scale":rng.randf_range(1.4,2.1) if i<12 else rng.randf_range(.6,1.15)})
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
