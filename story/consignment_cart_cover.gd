extends Node3D
## Covered wagon with a concealing rear curtain and a torn firing aperture.
var director:Node
var curtain:MeshInstance3D
var curtain_body:StaticBody3D
var torn_edges: Array[Node3D] = []
var swivel_support: MeshInstance3D
var openness=0.0
var cart:Node3D
var tailgate:Node3D
var step_hinge:Node3D
var step_collision:CollisionShape3D
var step_clearance:CollisionShape3D
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
 for column in 48:
  var left:=lerpf(-HALF,HALF,float(column)/48)
  var right:=lerpf(-HALF,HALF,float(column+1)/48)
  for row in 8:
   var low:=float(row)/8
   var high:=float(row+1)/8
   quad(rear,curtain_point(left,low),curtain_point(right,low),curtain_point(right,high),curtain_point(left,high))
 var rear_panel:=panel("RearConcealmentCurtain",rear,cloth,true);curtain=rear_panel.get_node("Fabric");curtain_body=rear_panel.get_node("CoverCollision")
 # The chase rips out the centre of the rear curtain, leaving the side
 # fastenings and uneven hanging remnants around the firing aperture.
 for side: float in [-1.0,1.0]:
  var outside := side*HALF
  var edge := PackedVector3Array([
   Vector3(outside,arch(outside,BACK),BACK+.02),
   Vector3(side*.69,arch(side*.69,BACK),BACK+.02),
   Vector3(side*.79,2.36,BACK+.09),
   Vector3(side*.88,2.52,BACK+.01),
   Vector3(side*.94,2.05,BACK+.12),
   Vector3(outside,1.92,BACK+.05)])
  var faces := PackedVector3Array()
  for j in range(1,edge.size()-1):faces.append_array([edge[0],edge[j],edge[j+1]])
  var remnant := panel("TornRearCanvas",faces,cloth,false)
  remnant.hide();torn_edges.append(remnant)
 var swivel := Marker3D.new()
 swivel.name="ChaseGunPivot";swivel.position=Vector3(-.12,1.87,3.94);cart.add_child(swivel)
 swivel_support=MeshInstance3D.new();swivel_support.name="RearGunSwivel"
 var post:=CylinderMesh.new();post.height=.64;post.top_radius=.035;post.bottom_radius=.065;post.radial_segments=10
 swivel_support.mesh=post;swivel_support.position=Vector3(-.12,1.54,3.94)
 var iron:=StandardMaterial3D.new();iron.albedo_color=Color(.13,.12,.10);iron.metallic=.7;iron.roughness=.66
 swivel_support.material_override=iron;add_child(swivel_support);swivel_support.hide()
 # Fold the low boarding tread clear of steep roads once the rider is inside.
 step_hinge=Node3D.new();step_hinge.name="LowerStepHinge";cart.add_child(step_hinge);step_hinge.position=Vector3(0,.95,4.0)
 var tread:Node3D=cart.get_node("RearBoardingStep");tread.reparent(step_hinge);tread.position=Vector3(0,-.50,.55)
 step_collision=tread.find_children("*","CollisionShape3D",true,false)[0]
 step_clearance=cart.get_meta("consignment_step_clearance")
 step_hinge.rotation.x=-PI*.5
 step_clearance.transform=cart.global_transform.affine_inverse()*step_collision.global_transform
 # The goods wagon's original rear board becomes a real hinged tailgate.
 for board in cart.visual_root.get_children():
  if board is MeshInstance3D and board.mesh is BoxMesh and is_equal_approx(board.position.z,3.95) and is_equal_approx(board.position.y,1.43):
   tailgate=Node3D.new();tailgate.name="RearTailgateHinge";cart.visual_root.add_child(tailgate);tailgate.position=Vector3(0,1.195,3.95)
   board.reparent(tailgate);board.position=Vector3(0,.235,0)
   var body:=StaticBody3D.new();tailgate.add_child(body)
   var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(1.7,.47,.09);collider.shape=shape;collider.position=Vector3(0,.235,0);body.add_child(collider)
   cart.boarding.cart_handle_rids.append(body.get_rid())
 # The full roof/side envelope participates in actual swept vehicle clearance.
 cart.boarding._add_clearance(Vector3(0,2.27,(FRONT+BACK)*.5),Vector3(HALF*2+.1,1.68,BACK-FRONT+.1))
 for body in find_children("*","CollisionObject3D",true,false):cart.boarding.cart_handle_rids.append(body.get_rid())
func curtain_point(x: float, height: float) -> Vector3:
 var span:=x/HALF
 var free_edge:=1.0-span*span
 var hanging:=1.0-height
 var hem:=1.30+.025*cos(span*TAU*1.5)*free_edge
 var fold: float=(.037*cos(span*TAU*3.0+height*.8)+.018*sin(span*TAU*1.1))*free_edge
 return Vector3(x,lerpf(hem,arch(x,BACK),height),BACK+.018+fold*hanging)

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
 var boarding:bool=cart.boarding.seat_name=="ConsignmentRearSeat" and not cart.boarding.transition.is_empty()
 step_hinge.rotation.x=move_toward(step_hinge.rotation.x,0.0 if boarding else -PI*.5,delta*5)
 step_clearance.transform=cart.global_transform.affine_inverse()*step_collision.global_transform
 var open:bool=boarding or (is_instance_valid(director) and director.stage in ["chase","celebration","complete"])
 openness=move_toward(openness,1.0 if open else 0.0,delta*1.8)
 var amount:=lerpf(1.0,.045,smoothstep(0,1,openness))
 curtain.scale.y=amount;curtain.position.y=3.11*(1-amount)
 var torn: bool = is_instance_valid(director) and director.stage in ["chase","celebration","complete"] and openness>.90
 curtain.visible=not torn
 for remnant in torn_edges:remnant.visible=torn
 swivel_support.visible=torn
 curtain_body.collision_layer=0 if openness>.90 else 1
 if is_instance_valid(tailgate):tailgate.rotation.x=PI*smoothstep(0,1,openness)
