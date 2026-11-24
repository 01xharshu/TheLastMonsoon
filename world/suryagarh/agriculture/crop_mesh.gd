extends RefCounted
## Original closed culms and curved leaf ribbons; no alpha billboard sheets.
var surface: SurfaceTool
func tri(a: Vector3,b: Vector3,c: Vector3,tint: Color) -> void:
 surface.set_color(tint)
 surface.add_vertex(a); surface.add_vertex(b); surface.add_vertex(c)
func tube(at: Vector3,height: float,radius: float,tint: Color,tip_radius:=0.0) -> void:
 for i in 6:
  var angle:=float(i)*TAU/6.0; var next:=float(i+1)*TAU/6.0
  var a:=at+Vector3(cos(angle)*radius,0,sin(angle)*radius)
  var b:=at+Vector3(cos(next)*radius,0,sin(next)*radius)
  var c:=at+Vector3(cos(angle)*tip_radius,height,sin(angle)*tip_radius)
  var d:=at+Vector3(cos(next)*tip_radius,height,sin(next)*tip_radius)
  tri(a,c,b,tint); tri(b,c,d,tint)
func leaf(at: Vector3,angle: float,length: float,width: float,tint: Color) -> void:
 var direction:=Vector3(cos(angle),0,sin(angle))
 var sideways:=Vector3(-sin(angle),0,cos(angle))
 for i in 4:
  var t:=float(i)/4; var u:=float(i+1)/4
  var p:=at+direction*length*t+Vector3.UP*(sin(t*PI)*0.44-t*t*0.32)
  var q:=at+direction*length*u+Vector3.UP*(sin(u*PI)*0.44-u*u*0.32)
  var aw:=width*sin(PI*(0.05+t*0.95))*0.5
  var bw:=width*sin(PI*(0.05+u*0.95))*0.5
  tri(p-sideways*aw,p+sideways*aw,q-sideways*bw,tint)
  tri(p+sideways*aw,q+sideways*bw,q-sideways*bw,tint)
func build(kind: String) -> ArrayMesh:
 surface=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var green:=Color(0.28,0.43,0.10)
 if kind=="sugarcane":
  for stalk in 2:
   var root:=Vector3(float(stalk)*0.13,0,float(stalk)*0.10)
   var height:=2.95+float(stalk)*0.22
   for node in 9:
    var y:=float(node)*height/9
    tube(root+Vector3(0,y,0),height/9,0.033,Color(0.47,0.51,0.20),0.032)
    tube(root+Vector3(0,y,0),0.022,0.038,Color(0.31,0.38,0.12),0.038)
   for i in 6: leaf(root+Vector3(0,1.5+float(i)*0.29,0),float(i)*2.4+stalk,1.12,0.09,green.lightened(float(i)*0.018))
 elif kind=="maize":
  tube(Vector3.ZERO,2.15,0.025,green,0.012)
  for i in 7: leaf(Vector3(0,0.4+float(i)*0.23,0),float(i)*2.8,0.78,0.16,green)
  tube(Vector3(0.10,1.05,0),0.32,0.075,Color(0.44,0.49,0.14),0.02)
  for i in 5: tube(Vector3(0,2.02,0),0.35,0.015,Color(0.62,0.57,0.26),0.002)
 elif kind=="sorghum":
  tube(Vector3.ZERO,1.85,0.019,green,0.01)
  for i in 6: leaf(Vector3(0,0.4+float(i)*0.22,0),float(i)*2.7,0.59,0.10,green)
  tube(Vector3(0,1.80,0),0.24,0.105,Color(0.62,0.51,0.28),0.03)
 else:
  tube(Vector3.ZERO,1.05,0.015,green,0.006)
  for i in 6:
   var y:=0.3+float(i)*0.11
   leaf(Vector3(0,y,0),float(i)*2.6,0.24,0.09,Color(0.28,0.42,0.16))
   tube(Vector3(0.035,y,0),0.065,0.016,Color(0.48,0.50,0.24),0.009)
 surface.generate_normals()
 var mesh:=surface.commit()
 var mat:=ShaderMaterial.new(); mat.shader=preload("res://world/suryagarh/agriculture/crop_wind.gdshader")
 mesh.surface_set_material(0,mat)
 return mesh
