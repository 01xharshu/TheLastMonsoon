extends Node3D
## Small hanging oil lantern, held by an existing full-body resident.
var actor: Node3D
var light: OmniLight3D
var elapsed := 0.0
var hand_error := 0.0
var held := false
func configure(person: Node3D) -> void:
 actor=person;name="CarriedNightLantern";actor.add_child(self)
 add_to_group("village_carried_lantern")
 var iron:=StandardMaterial3D.new();iron.albedo_color=Color(.12,.10,.08);iron.metallic=.45;iron.roughness=.65
 var glass:=StandardMaterial3D.new();glass.albedo_color=Color(.65,.49,.28,.18);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.roughness=.15
 _cylinder("OilReservoir",.08,.055,-.36,iron)
 _cylinder("GlassEnclosure",.074,.20,-.235,glass)
 _cylinder("VentedCap",.09,.03,-.12,iron)
 for index in 4:
  var angle: float=index*PI*.5
  var rod:=_cylinder("ProtectiveFrame",.006,.22,-.235,iron)
  rod.position.x=cos(angle)*.076;rod.position.z=sin(angle)*.076
 var handle:=MeshInstance3D.new();handle.name="CarryingHandle"
 var ring:=TorusMesh.new();ring.inner_radius=.055;ring.outer_radius=.065;ring.rings=16;ring.ring_segments=6
 handle.mesh=ring;handle.material_override=iron;handle.position.y=-.065;handle.rotation.x=PI*.5;add_child(handle)
 var flame:=MeshInstance3D.new();flame.name="OilFlame"
 var sphere:=SphereMesh.new();sphere.radius=.5;sphere.height=1;sphere.radial_segments=8;sphere.rings=4
 flame.mesh=sphere;flame.scale=Vector3(.018,.045,.018);flame.position.y=-.26
 var material:=ShaderMaterial.new();material.shader=preload("res://world/suryagarh/settlements/village_flame.gdshader")
 flame.material_override=material;flame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(flame)
 light=OmniLight3D.new();light.position.y=-.23;light.light_color=Color(1,.61,.29);light.light_energy=.65;light.omni_range=3.5
 light.distance_fade_enabled=true;light.distance_fade_begin=25;light.distance_fade_length=10;add_child(light)
 visible=false
func _cylinder(label: String,radius: float,height: float,y: float,material: Material) -> MeshInstance3D:
 var node:=MeshInstance3D.new();node.name=label
 var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=12
 node.mesh=mesh;node.material_override=material;node.position.y=y;add_child(node);return node
func update(delta: float,active: bool) -> void:
 elapsed+=delta
 if held and not active:actor.set_grip("r",0.0)
 held=active;visible=active
 if not active:return
 position=Vector3(-.34,1.02,.30)
 rotation=Vector3(.025*sin(elapsed*3.1)*minf(actor.travel_speed,1.0),0,0)
 var target:=to_global(Vector3.ZERO)
 actor.solve_hand_contact("r",target);actor.set_grip("r",.6)
 global_position+=actor.palm_world("r")-target
 hand_error=actor.palm_world("r").distance_to(global_position)
 if actor.drape!=null:actor.drape.update()
 light.light_energy=.65+.025*sin(elapsed*6.1)
