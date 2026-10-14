extends Node3D
## Authored covered-wagon construction; the rear fabric rolls above the firing aperture.
var director:Node
var curtain:MeshInstance3D
var curtain_body:StaticBody3D
var openness=0.0
var cart:Node3D
const FRONT=1.05
const BACK=4.12
const HALF=1.13
func _ready() -> void:
 name="RebelCoveredWagon";cart=get_parent()
 var cloth:=StandardMaterial3D.new();cloth.albedo_color=Color(.61,.53,.37);cloth.roughness=1;cloth.cull_mode=BaseMaterial3D.CULL_DISABLED
 var wood:=StandardMaterial3D.new();wood.albedo_color=Color(.21,.12,.055);wood.roughness=.95
 var roof:=PackedVector3Array()
 for z in 16:
  var a:=lerpf(FRONT,BACK,float(z)/16);var b:=lerpf(FRONT,BACK,float(z+1)/16)
  for x in 16:
   var left:=lerpf(-HALF,HALF,float(x)/16);var right:=lerpf(-HALF,HALF,float(x+1)/16)
   quad(roof,Vector3(left,arch(left,a),a),Vector3(right,arch(right,a),a),Vector3(right,arch(right,b),b),Vector3(left,arch(left,b),b))
 panel("StitchedCanvasRoof",roof,cloth,true)
 for sign_side in [-1.0,1.0]:
  var sides:=PackedVector3Array()
  quad(sides,Vector3(sign_side*HALF,1.40,FRONT),Vector3(sign_side*HALF,2.63,FRONT),Vector3(sign_side*HALF,2.63,BACK),Vector3(sign_side*HALF,1.40,BACK))
  panel("CanvasSideCurtain",sides,cloth,true)
 for z in [FRONT,2.05,3.05,BACK]:
  for x in 12:
   var a:=lerpf(-HALF,HALF,float(x)/12);var b:=lerpf(-HALF,HALF,float(x+1)/12)
   beam(Vector3(a,arch(a,z)-.035,z),Vector3(b,arch(b,z)-.035,z),wood)
  for sign_side in [-1.0,1.0]:beam(Vector3(sign_side*HALF,1.25,z),Vector3(sign_side*HALF,2.63,z),wood)
 var rear:=PackedVector3Array()
 for i in 16:
  var a:=lerpf(-HALF,HALF,float(i)/16);var b:=lerpf(-HALF,HALF,float(i+1)/16)
  quad(rear,Vector3(a,1.30,BACK+.018),Vector3(b,1.30,BACK+.018),Vector3(b,arch(b,BACK),BACK+.018),Vector3(a,arch(a,BACK),BACK+.018))
 var rear_panel:=panel("RearConcealmentCurtain",rear,cloth,true);curtain=rear_panel.get_node("Fabric");curtain_body=rear_panel.get_node("CoverCollision")
 # The full roof/side envelope participates in actual swept vehicle clearance.
 cart.boarding._add_clearance(Vector3(0,2.27,(FRONT+BACK)*.5),Vector3(HALF*2+.1,1.68,BACK-FRONT+.1))
 for body in find_children("*","CollisionObject3D",true,false):cart.boarding.cart_handle_rids.append(body.get_rid())
func arch(x:float,z:float) -> float:
 return 2.63+.48*sqrt(maxf(0,1-pow(x/HALF,2)))-.025*pow(sin((z-FRONT)*PI),2)
func quad(faces:PackedVector3Array,a:Vector3,b:Vector3,c:Vector3,d:Vector3) -> void:
 faces.append_array(PackedVector3Array([a,b,c,a,c,d]))
func panel(label:String,faces:PackedVector3Array,material:Material,solid:bool) -> Node3D:
 var root:=Node3D.new();root.name=label;add_child(root)
 var build:=SurfaceTool.new();build.begin(Mesh.PRIMITIVE_TRIANGLES)
 for at in faces:build.set_uv(Vector2(at.x,at.z+at.y));build.add_vertex(at)
 build.generate_normals()
 var mesh:=MeshInstance3D.new();mesh.name="Fabric";mesh.mesh=build.commit();mesh.material_override=material;mesh.visibility_range_end=180;root.add_child(mesh)
 if solid:
  var body:=StaticBody3D.new();body.name="CoverCollision";root.add_child(body)
  var collider:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.set_faces(faces);shape.backface_collision=true;collider.shape=shape;body.add_child(collider)
 return root
func beam(a:Vector3,b:Vector3,material:Material) -> void:
 var wood:=MeshInstance3D.new();var shape:=CylinderMesh.new();shape.top_radius=.025;shape.bottom_radius=.025;shape.height=a.distance_to(b);shape.radial_segments=6;wood.mesh=shape;wood.material_override=material;wood.position=(a+b)*.5;add_child(wood)
 var along:Vector3=(b-a).normalized();var right:=along.cross(Vector3.FORWARD).normalized()
 if right.length_squared()<.01:right=Vector3.RIGHT
 wood.basis=Basis(right,along,right.cross(along).normalized());wood.visibility_range_end=150
func _process(delta:float) -> void:
 var open:bool=is_instance_valid(director) and director.stage in ["chase","celebration","complete"]
 openness=move_toward(openness,1.0 if open else 0.0,delta*1.8)
 var amount:=lerpf(1.0,.045,smoothstep(0,1,openness))
 curtain.scale.y=amount;curtain.position.y=3.11*(1-amount)
 curtain_body.collision_layer=0 if openness>.90 else 1
