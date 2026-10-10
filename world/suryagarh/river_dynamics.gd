extends Node3D
## Shared river current and subdivided surface; terrain/water level remain authoritative.
const Startup=preload("res://systems/world_startup.gd")
var boat: Node3D
const Layout=preload('res://world/suryagarh/landscape_layout.gd')
const WATER_SHADER=preload('res://world/suryagarh/shaders/river.gdshader')
static var survey_layout:=Layout.new()
var layout:=Layout.new()
var materials: Array[ShaderMaterial]=[]
var elapsed:=0.0
static func current_at(at: Vector3) -> Vector3:
 var survey:=survey_layout
 var across:=absf(at.x-survey.river_x(at.z))/survey.river_width(at.z)
 if across>=1.0 or absf(at.z)>Layout.HALF:return Vector3.ZERO
 # The port/estuary lies at +Z. Flow tangent is the analytic centreline derivative.
 var tangent:=Vector3(.342*cos(at.z*.0045)+.242*cos(at.z*.011),0,1).normalized()
 var upstream:=1.0-smoothstep(350.0,750.0,at.z)
 var speed:=lerpf(.32,.85,upstream)*lerpf(1.0,.22,smoothstep(.45,1.0,across))
 return tangent*speed
static func surface_height(at: Vector3,seconds: float) -> float:
 var survey:=survey_layout
 var cross:=at.x-survey.river_x(at.z)
 var edge:=1.0-smoothstep(.75,1.05,absf(cross)/survey.river_width(at.z))
 var travel:=at.z-seconds*1.25
 return Layout.WATER_LEVEL+edge*(sin(travel*.52+cross*.16)*.065+sin(travel*.93-cross*.33)*.028)
func _ready() -> void:
 name='RiverDynamics'
 var task:=Startup.begin("River surface")
 var old:=get_parent().find_child('RiverSurface',true,false) as MeshInstance3D
 if old!=null:
  # Keep the distant estuary/horizon mesh; shader clips its playable reach.
  var distant:=ShaderMaterial.new();distant.shader=WATER_SHADER
  distant.set_shader_parameter('distant_surface',true)
  old.material_override=distant;materials.append(distant)
 await build_surface()
 if old!=null:
  var source:=old.mesh.surface_get_material(0) as ShaderMaterial
  if source!=null:
   for material in materials:
    material.set_shader_parameter('exclude_moored_ship',source.get_shader_parameter('exclude_moored_ship'))
    material.set_shader_parameter('moored_ship_center',source.get_shader_parameter('moored_ship_center'))
 Startup.finish(task)
 boat=get_parent().get_node_or_null("RiverBoat")

func build_surface() -> void:
 # Short strips allow frustum culling; maximum 3 m across the freshwater channel.
 var shared:=ShaderMaterial.new();shared.shader=WATER_SHADER;materials.append(shared)
 for start in range(-864,864,96):
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var rows:=32
  var columns:=maxi(48,int(ceil((layout.river_width(start+48)+36)*2/3)))
  columns=mini(columns,320)
  for row in range(rows+1):
   var z:=float(start)+row*3.0
   for col in range(columns+1):
    var side:=float(col)/columns*2.0-1.0
    var x:=layout.river_x(z)+side*(layout.river_width(z)+36)
    st.set_normal(Vector3.UP);st.set_uv(Vector2(x,z)/8)
    st.set_tangent(Plane(Vector3.RIGHT,1))
    st.add_vertex(Vector3(x,Layout.WATER_LEVEL,z))
  for row in rows:
   for col in columns:
    var a:=row*(columns+1)+col
    for id in [a,a+columns+1,a+1,a+1,a+columns+1,a+columns+2]:st.add_index(id)
  var material:=shared
  var mesh:=MeshInstance3D.new();mesh.name='FlowingReach_'+str(start);mesh.mesh=st.commit()
  mesh.material_override=material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  mesh.extra_cull_margin=.2;add_child(mesh)
  await Startup.checkpoint(self,"Preparing river reaches…")
func _process(delta: float) -> void:
 elapsed+=delta
 for material in materials:
  material.set_shader_parameter('flow_time',elapsed)
  if is_instance_valid(boat):
   material.set_shader_parameter('boat_center',Vector2(boat.global_position.x,boat.global_position.z))
   material.set_shader_parameter('boat_heading',boat.global_rotation.y)
   material.set_shader_parameter('boat_speed',boat.velocity.dot(-boat.global_basis.z))
   material.set_shader_parameter('boat_present',true)
 # The same wave clock is available to watercraft without changing bank collision.
 set_meta('flow_seconds',elapsed)
