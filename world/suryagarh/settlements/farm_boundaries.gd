extends Node3D
## Terrain-rooted rural additions; chunked static batches, no frame callbacks.
signal built
const Density = preload("res://world/suryagarh/settlements/countryside_density.gd")
const Terrain = preload("res://world/suryagarh/tree_trunk_collision.gd")
var NEW_FIELDS: Array[Vector2] = Density.additional_fields()
var survey: RefCounted
var timber: StandardMaterial3D
var member_mesh: CylinderMesh
var fence_segments: Array[Dictionary] = []
var ready_for_exploration := false
func _ready() -> void:
 name="FarmBoundaries"
 survey=preload("res://world/suryagarh/terrain_surface_survey.gd").new()
 survey.configure(get_parent())
 await get_tree().physics_frame
 timber=StandardMaterial3D.new()
 timber.albedo_texture=preload("res://assets/architecture/materials/dark_wood_Diffuse.jpg")
 timber.albedo_color=Color(.78,.67,.48);timber.roughness=.95
 member_mesh=CylinderMesh.new();member_mesh.top_radius=.85;member_mesh.bottom_radius=1.0;member_mesh.height=1.0;member_mesh.radial_segments=6
 var centers: Array = Density.fields()
 centers.append_array(NEW_FIELDS)
 for i in centers.size():
  var center: Vector2=centers[i]
  build_boundary(center,i)
  if center in NEW_FIELDS:
   var plot:=Node3D.new();plot.name="AdditionalField%d"%i;plot.position=ground(center);add_child(plot)
   preload("res://world/suryagarh/settlements/farm_visuals.gd").build(plot,survey,Density.FIELD_SIZE,1857+i,false,28,1.0)
   # Match established farm visibility rather than allowing an abrupt empty plot.
   plot.get_node("FarmPlants").visibility_range_end=220
   plot.get_node("FarmFurrows").visibility_range_end=500
   plot.get_node("FarmFurrows").visibility_range_end_margin=40
  if i%4==3:await get_tree().process_frame
 build_tracks()
 clear_field_grass()
 ready_for_exploration=true
 built.emit()
func ground(p: Vector2) -> Vector3:
 return Vector3(p.x,survey.height(p.x,p.y),p.y)
func boundary_clear(p:Vector2) -> bool:
 for route:Array in preload("res://world/suryagarh/landscape_layout.gd").ROUTES.values():
  for i in route.size()-1:
   if p.distance_to(Geometry2D.get_closest_point_to_segment(p,route[i],route[i+1]))<8.0:return false
 for lane:Array in Density.lanes():
  for i in lane.size()-1:
   if p.distance_to(Geometry2D.get_closest_point_to_segment(p,lane[i],lane[i+1]))<4.5:return false
 return true
func build_boundary(center: Vector2,index: int) -> void:
 var chunk:=Node3D.new();chunk.name="PlotTimber%02d"%index;add_child(chunk)
 var members: Array[Transform3D]=[]
 var solid_faces:=PackedVector3Array()
 var body:=StaticBody3D.new();body.name="TimberBoundaryCollision";chunk.add_child(body)
 # Eastern access remains a clear 5m opening for workers and farm carts.
 var corners: Array[Vector2]=[center+Vector2(21,-15),center+Vector2(-21,-15),center+Vector2(-21,15),center+Vector2(21,15)]
 var lines: Array=[ [corners[0],corners[1]],[corners[1],corners[2]],[corners[2],corners[3]],[corners[3],center+Vector2(21,2.5)],[center+Vector2(21,-2.5),corners[0]] ]
 for line: Array in lines:
  var a: Vector2=line[0];var b: Vector2=line[1]
  var steps:=maxi(1,ceili(a.distance_to(b)/2.8))
  for j in range(steps+1):
   var point:Vector2=a.lerp(b,float(j)/steps)
   if not boundary_clear(point):continue
   var p:=ground(point)
   members.append(Transform3D(Basis.IDENTITY.scaled(Vector3(.065,.97,.065)),p+Vector3.UP*.46))
  # Short terrain-following sections, with solid rails matching visible timber.
  for j in steps:
   var start:Vector2=a.lerp(b,float(j)/steps);var end:Vector2=a.lerp(b,float(j+1)/steps)
   if not boundary_clear(start) or not boundary_clear(end) or not boundary_clear((start+end)*.5):continue
   var p:=ground(start);var q:=ground(end)
   for height: float in [.38,.75]:
    var from:=p+Vector3.UP*height;var to:=q+Vector3.UP*height
    var basis:=Basis(Quaternion(Vector3.UP,(to-from).normalized()))
    members.append(Transform3D(basis.scaled(Vector3(.042,from.distance_to(to),.042)),(from+to)*.5))
    var form:=BoxMesh.new();form.size=Vector3(.085,from.distance_to(to),.085)
    var frame:=Transform3D(basis,(from+to)*.5)
    for vertex:Vector3 in form.get_faces():solid_faces.append(frame*vertex)
   fence_segments.append({"a":p,"b":q})
 var collision:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.set_faces(solid_faces);collision.shape=shape;body.add_child(collision)
 var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=member_mesh;mm.instance_count=members.size()
 for i in members.size():mm.set_instance_transform(i,members[i])
 var visual:=MultiMeshInstance3D.new();visual.multimesh=mm;visual.material_override=timber
 visual.visibility_range_end=320;visual.visibility_range_end_margin=40;chunk.add_child(visual)
func build_tracks() -> void:
 for lane: Array in Density.lanes():
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for j in lane.size()-1:
   var a:Vector2=lane[j];var b:Vector2=lane[j+1];var length:=a.distance_to(b);var direction:Vector2=(b-a).normalized();var side:=Vector2(-direction.y,direction.x)*2.1
   var steps:=maxi(1,ceili(length/1.5))
   for k in steps:
    var start:Vector2=a.lerp(b,float(k)/steps);var end:Vector2=a.lerp(b,float(k+1)/steps)
    var points: Array[Vector2]=[start-side,start+side,end-side,end+side]
    for n in [0,2,1,1,2,3]:
     st.set_uv(Vector2(0.0 if n in [0,2] else 1.0,(float(k)+(1.0 if n>=2 else 0.0))*length/steps))
     st.add_vertex(ground(points[n])+Vector3.UP*.065)
  st.generate_normals()
  var mesh:=MeshInstance3D.new();mesh.name="RuttedFarmTrack";mesh.mesh=st.commit()
  var material:=ShaderMaterial.new();material.shader=preload("res://world/suryagarh/shaders/farm_track.gdshader")
  material.set_shader_parameter("earth_texture",preload("res://assets/nature/materials/brown_mud_dry_diff_1k.jpg"))
  material.set_shader_parameter("earth_normal",preload("res://assets/nature/materials/brown_mud_dry_nor_gl_1k.jpg"))
  mesh.material_override=material;mesh.visibility_range_end=450;mesh.visibility_range_end_margin=40;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(mesh)
func clear_field_grass() -> void:
 # Local shader overrides preserve shared grass instance buffers and their LOD.
 var rect:=Rect2(Vector2(-658,-370),Vector2(204,720))
 var image:=Image.create(512,2048,false,Image.FORMAT_R8)
 image.fill(Color.BLACK)
 var texel:Vector2=rect.size/Vector2(512,2048)
 for center:Vector2 in NEW_FIELDS:
  var lower:=Vector2i((center-Density.FIELD_SIZE*.5-Vector2.ONE-rect.position)/texel)
  var upper:=Vector2i((center+Density.FIELD_SIZE*.5+Vector2.ONE-rect.position)/texel)
  for y in range(maxi(0,lower.y),mini(2047,upper.y)+1):
   for x in range(maxi(0,lower.x),mini(511,upper.x)+1):image.set_pixel(x,y,Color.WHITE)
 for lane:Array in Density.lanes():
  for i in lane.size()-1:
   var a:Vector2=lane[i];var b:Vector2=lane[i+1]
   var lower:=Vector2i((a.min(b)-Vector2.ONE*2.2-rect.position)/texel)
   var upper:=Vector2i((a.max(b)+Vector2.ONE*2.2-rect.position)/texel)
   for y in range(maxi(0,lower.y),mini(2047,upper.y)+1):
    for x in range(maxi(0,lower.x),mini(511,upper.x)+1):
     var p:Vector2=rect.position+(Vector2(x,y)+Vector2.ONE*.5)*texel
     var value:=1.0-smoothstep(1.65,2.1,p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b)))
     if value>image.get_pixel(x,y).r:image.set_pixel(x,y,Color(value,0,0))
 var texture:=ImageTexture.create_from_image(image)
 for batch:MultiMeshInstance3D in get_parent().find_children("Grass*","MultiMeshInstance3D",true,false):
  var bounds:AABB=batch.global_transform*batch.get_aabb()
  if not rect.intersects(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))):continue
  var source:Material=batch.material_override
  if source==null:source=batch.multimesh.mesh.surface_get_material(0)
  if not source is ShaderMaterial or source.shader.resource_path!="res://world/suryagarh/shaders/grass_blades.gdshader":continue
  var copy:ShaderMaterial=source.duplicate()
  copy.set_shader_parameter("worn_path_enabled",true);copy.set_shader_parameter("worn_path_mask",texture)
  copy.set_shader_parameter("worn_path_rect",Vector4(rect.position.x,rect.position.y,rect.size.x,rect.size.y))
  batch.material_override=copy
