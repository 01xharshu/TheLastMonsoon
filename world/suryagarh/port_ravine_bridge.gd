extends RefCounted
const Uplands=preload("res://world/suryagarh/port_village_uplands.gd")
const Layout=preload("res://world/suryagarh/landscape_layout.gd")
static func build() -> Node3D:
 var root:=Node3D.new();root.name="PortRavineBridge"
 var wood:=ShaderMaterial.new();wood.shader=preload("res://world/suryagarh/shaders/bridge_timber.gdshader");wood.set_shader_parameter("wood_color",Color(.29,.22,.14))
 var p:Vector2=Uplands.BRIDGE[0];var q:Vector2=Uplands.BRIDGE[1]
 var a:=Vector3(p.x,Uplands.BRIDGE_GRADES[0],p.y);var b:=Vector3(q.x,Uplands.BRIDGE_GRADES[1],q.y)
 var side:=Vector3(-(b.z-a.z),0,b.x-a.x).normalized()
 # One uninterrupted deck and a nearly level alignment; no corner in the span.
 beam(root,a-Vector3.UP*.22,b-Vector3.UP*.22,Vector2(8,.44),wood,true)
 var count:=ceili(a.distance_to(b)/.45)
 for plank in count:
  var at:=a.lerp(b,(float(plank)+.5)/count)
  beam(root,at-side*4.0,at+side*4.0,Vector2(.44,.05),wood)
 for sign in [-1.0,1.0]:
  var edge:Vector3=side*sign*4.3
  beam(root,a+edge+Vector3.UP*.8,b+edge+Vector3.UP*.8,Vector2(.24,.28),wood,true)
  beam(root,a+edge+Vector3.UP*3.8,b+edge+Vector3.UP*3.8,Vector2(.32,.4),wood)
  beam(root,a+side*sign*2.8-Vector3.UP*.6,b+side*sign*2.8-Vector3.UP*.6,Vector2(.45,.75),wood)
  var panels:=ceili(a.distance_to(b)/4.2)
  for panel in panels:
   var lo:Vector3=a.lerp(b,float(panel)/panels)+edge
   var hi:Vector3=a.lerp(b,float(panel+1)/panels)+edge
   beam(root,lo-Vector3.UP*.4,lo+Vector3.UP*3.8,Vector2(.3,.3),wood,true)
   beam(root,lo+Vector3.UP*.8,hi+Vector3.UP*3.8,Vector2(.24,.28),wood)
   beam(root,lo+Vector3.UP*3.8,hi+Vector3.UP*.8,Vector2(.24,.28),wood)
  beam(root,b+edge-Vector3.UP*.4,b+edge+Vector3.UP*3.8,Vector2(.3,.3),wood,true)
 # Four support bents; the two inner bents flank the dry road below.
 var layout:=Layout.new()
 for z in [409.0,397.0,373.0,361.0]:
  var t:float=(z-a.z)/(b.z-a.z)
  var at:=a.lerp(b,t)
  for sign in [-1.0,1.0]:
   var top:Vector3=at+side*sign*3.8-Vector3.UP*.5
   var bottom:=Vector3(top.x,layout.height(top.x,top.z)-.6,top.z)
   if top.y>bottom.y:beam(root,bottom,top,Vector2(.65,.65),wood,true)
  beam(root,at+side*4.1-Vector3.UP*.55,at-side*4.1-Vector3.UP*.55,Vector2(.65,.7),wood)
 var batch:=SurfaceTool.new();batch.begin(Mesh.PRIMITIVE_TRIANGLES)
 for part:MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
  batch.append_from(part.mesh,0,part.transform);part.mesh=null
 batch.set_material(wood)
 var merged:=MeshInstance3D.new();merged.name="BridgeTimber";merged.mesh=batch.commit();root.add_child(merged)
 for node in root.find_children("*","",true,false):node.owner=root
 return root
static func beam(root:Node3D,a:Vector3,b:Vector3,width:Vector2,wood:Material,solid:=false) -> void:
 var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(width.x,width.y,a.distance_to(b)+.06);node.mesh=mesh;node.material_override=wood
 root.add_child(node);node.position=(a+b)*.5
 node.basis=Basis.looking_at(b-a,Vector3.FORWARD if absf((b-a).normalized().y)>.99 else Vector3.UP)
 if solid:
  var body:=StaticBody3D.new();body.collision_layer=1
  if width.x>=8.0:body.name="GroundCollision";body.collision_layer|=1<<30
  node.add_child(body)
  var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=mesh.size;shape.shape=box;body.add_child(shape)
