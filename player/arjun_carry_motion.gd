extends Node3D
## One selected stowed weapon, supported by a visible sling on the final pose.
## Small damped angular lag stays around the suspension point, never the root.
var equipment: Node3D
var actor: CharacterBody3D
var rig: Skeleton3D
var item: Node3D
var rest := Transform3D.IDENTITY
var angles := Vector3.ZERO
var angular_velocity := Vector3.ZERO
var previous_velocity := Vector3.ZERO
var previous_heading := 0.0
var previous_position := Vector3.ZERO
var initialized := false
var sling: MeshInstance3D
var sheath: MeshInstance3D
var leather: StandardMaterial3D
var suspension_error := 0.0
var support:Array[Dictionary]=[]
var support_nodes:Array[MeshInstance3D]=[]
var support_meshes:Array[Mesh]=[]
var ribbon_mesh:=ImmediateMesh.new()
const PIVOT := Vector3(0,1.35,-.18)
const LIMIT := .065

func setup(owner_equipment: Node3D) -> void:
 equipment=owner_equipment;rig=equipment.skeleton
 actor=equipment.inventory.get_parent()
 process_priority=25
 leather=StandardMaterial3D.new()
 leather.albedo_color=Color(.095,.055,.026);leather.roughness=.87
 leather.cull_mode=BaseMaterial3D.CULL_DISABLED
 sling=MeshInstance3D.new();sling.name="CarryingSling";add_child(sling)
 sling.material_override=leather;sling.mesh=ribbon_mesh
 _cache_support()
 sheath=MeshInstance3D.new();sheath.name="TalwarScabbard";add_child(sheath)
 # The scabbard follows the curved source blade rather than a straight box.
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var points:=[Vector3(.015,0,0),Vector3(.25,.008,0),Vector3(.50,.035,0),Vector3(.70,.085,0),Vector3(.82,.14,0)]
 for i in points.size()-1:
  var a:Vector3=points[i];var b:Vector3=points[i+1]
  var ra:=.034 if i<3 else .026
  var rb:=.034 if i<2 else .026
  for side in 8:
   var t:=TAU*side/8.0;var u:=TAU*(side+1)/8.0
   var p:=a+Vector3(0,cos(t)*ra,sin(t)*.017)
   var q:=a+Vector3(0,cos(u)*ra,sin(u)*.017)
   var r:=b+Vector3(0,cos(t)*rb,sin(t)*.017)
   var s:=b+Vector3(0,cos(u)*rb,sin(u)*.017)
   for vertex:Vector3 in [p,r,q,q,r,s]:surface.add_vertex(vertex)
 surface.generate_normals();sheath.mesh=surface.commit();sheath.material_override=leather

func reset_motion() -> void:
 angles=Vector3.ZERO;angular_velocity=Vector3.ZERO
 previous_velocity=actor.velocity;previous_heading=actor.get_node("VisualRoot").global_rotation.y
 previous_position=actor.global_position;initialized=true

func _process(delta: float) -> void:
 for index in support_nodes.size():
  if not is_instance_valid(support_nodes[index]) or support_nodes[index].mesh!=support_meshes[index]:
   refresh_support();break
 var selected_item:Node3D
 if equipment.stowed and not equipment.swimming and equipment.owns(equipment.selected):
  match int(equipment.selected):
   0:selected_item=equipment.talwar_waist
   1:selected_item=equipment.enfield_back
   2:selected_item=equipment.bow_back
   3:selected_item=equipment.pistol_hip
   4:selected_item=equipment.knife_hip
   5:selected_item=equipment.double_back
 if selected_item!=item:
  if is_instance_valid(item):item.transform=rest
  item=selected_item
  if is_instance_valid(item):rest=item.transform
  reset_motion()
 visible=is_instance_valid(item)
 if not visible:return
 if not initialized or delta<=0 or delta>.12 or actor.global_position.distance_to(previous_position)>2.0:reset_motion()
 var dt:=minf(delta,.05)
 var acceleration:=rig.global_basis.orthonormalized().inverse()*(actor.velocity-previous_velocity)/maxf(delta,.001)
 var heading:float=actor.get_node("VisualRoot").global_rotation.y
 var turn:=clampf(angle_difference(previous_heading,heading)/maxf(delta,.001),-4,4)
 var low:float=clampf(actor.get_node("StealthStance").blend,0,1)
 # Acceleration/turn lag, subdued when creeping; no perpetual idle sine wave.
 var target:=Vector3(clampf(-acceleration.z*.002,-.035,.035),clampf(-turn*.012,-.045,.045),clampf(acceleration.x*.002,-.035,.035))*(1.0-low*.65)
 var steps:=maxi(1,ceili(dt/.008))
 for step in steps:
  var h:=dt/steps
  angular_velocity+=(target-angles)*105.0*h-angular_velocity*19.0*h
  angles+=angular_velocity*h
  angles=angles.clamp(Vector3.ONE*-LIMIT,Vector3.ONE*LIMIT)
 previous_velocity=actor.velocity;previous_heading=heading;previous_position=actor.global_position
 var bone:=rig.find_bone("spine_03" if int(equipment.selected) in [0,1,2,5] else "pelvis")
 var bone_rest:=rig.get_bone_global_rest(bone)
 var pivot:=PIVOT if int(equipment.selected) in [0,1,2,5] else Vector3(-.25,1.02,-.05)
 var fit_angles:=angles
 # Redistribute a long weapon across the shoulders when staying low, rather
 # than leaving its muzzle pointing vertically above the crouched head.
 if int(equipment.selected) in [1,5]:fit_angles.z+=low*.75
 var turn_basis:=Basis.from_euler(fit_angles)
 var movement:=Transform3D(turn_basis,pivot-turn_basis*pivot)
 item.transform=bone_rest.affine_inverse()*movement*bone_rest*rest
 rig.force_update_all_bone_transforms()
 var current:=rig.get_bone_global_pose(bone)
 # Compute directly from evaluated skeleton, avoiding one-frame attachment lag.
 var item_pose:=current*item.transform
 sheath.visible=int(equipment.selected)==0
 sheath.global_transform=rig.global_transform*item_pose
 sling.visible=int(equipment.selected) in [0,1,5]
 if sling.visible:
  var lower:=item_pose*Vector3(-.32,0,0) if int(equipment.selected)!=0 else item_pose*Vector3(-.07,0,0)
  var upper:=item_pose*Vector3(.36,0,0) if int(equipment.selected)!=0 else item_pose*Vector3(.32,0,0)
  var points:Array[Vector3]=[lower]
  for sample in support:points.append(_support_point(sample))
  points.append(upper)
  _ribbon(points)
 var rest_pivot:=bone_rest.affine_inverse()*pivot
 suspension_error=(current*rest_pivot).distance_to(current*(item.transform*rest.affine_inverse()*rest_pivot))

func refresh_support()->void:
 support.clear();support_nodes.clear();support_meshes.clear();_cache_support()

func _cache_support()->void:
 var cloths:Array[MeshInstance3D]=[]
 for name in ["Arjun_Kurta_SplitHem","Arjun_Kurta_Upper"]:
  var cloth:MeshInstance3D=rig.find_child(name,true,false)
  if cloth!=null and cloth.mesh!=null and cloth.skin!=null:
   cloths.append(cloth);support_nodes.append(cloth);support_meshes.append(cloth.mesh)
 if cloths.is_empty():return
 # Choose fixed surface samples once. Runtime evaluates only their skin binds.
 var targets:Array[Vector3]=[]
 var path:Array[Vector3]=[Vector3(.20,1.04,-.17),Vector3(.25,1.10,.10),Vector3(.16,1.22,.20),Vector3(-.02,1.37,.18),Vector3(-.18,1.48,.04),Vector3(-.19,1.45,-.16)]
 for i in path.size()-1:
  for t in 4:targets.append(path[i].lerp(path[i+1],t/4.0))
 targets.append(path.back())
 for target in targets:
  var nearest:=INF;var chosen:Dictionary={}
  for cloth in cloths:
   for surface in cloth.mesh.get_surface_count():
    var arrays:=cloth.mesh.surface_get_arrays(surface)
    if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
     continue
    if not arrays[Mesh.ARRAY_BONES] is PackedInt32Array or not arrays[Mesh.ARRAY_WEIGHTS] is PackedFloat32Array:
     continue
    var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
    var indices:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
    var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
    if vertices.is_empty() or normals.size()!=vertices.size() or weights.size()!=indices.size() or weights.size()%vertices.size()!=0:
     continue
    var count:int=weights.size()/vertices.size()
    for index in vertices.size():
     var distance:=vertices[index].distance_squared_to(target)
     if distance>=nearest:continue
     var binds:Array[Transform3D]=[];var bones:Array[int]=[];var amounts:Array[float]=[]
     var valid:=true
     for slot in count:
      var amount:=weights[index*count+slot]
      if amount<.001:continue
      var bind:=indices[index*count+slot]
      if bind<0 or bind>=cloth.skin.get_bind_count():
       valid=false;break
      var bone:=rig.find_bone(cloth.skin.get_bind_name(bind))
      if bone<0:bone=cloth.skin.get_bind_bone(bind)
      if bone<0 or bone>=rig.get_bone_count():
       valid=false;break
      bones.append(bone);binds.append(cloth.skin.get_bind_pose(bind));amounts.append(amount)
     if not valid or bones.is_empty():continue
     nearest=distance
     chosen={"point":vertices[index],"normal":normals[index],"bones":bones,"binds":binds,"weights":amounts}
  if not chosen.is_empty():support.append(chosen)

func _support_point(sample:Dictionary)->Vector3:
 var point:=Vector3.ZERO;var normal:=Vector3.ZERO
 for slot in sample.bones.size():
  var pose:Transform3D=rig.get_bone_global_pose(sample.bones[slot])*sample.binds[slot]
  point+=(pose*sample.point)*sample.weights[slot]
  normal+=(pose.basis*sample.normal)*sample.weights[slot]
 sample["posed_normal"]=normal.normalized()
 return point+normal.normalized()*.004

func _ribbon(points:Array[Vector3])->void:
 ribbon_mesh.clear_surfaces();ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in points.size()-1:
  var a:=points[i];var b:=points[i+1]
  var outward:Vector3=support[clampi(i-1,0,support.size()-1)].get("posed_normal",Vector3.BACK) if not support.is_empty() else Vector3.BACK
  var width:Vector3=(b-a).cross(outward).normalized()*.014
  if width.length_squared()<.00001:width=Vector3.RIGHT*.014
  var normal:Vector3=(b-a).cross(width).normalized()
  for vertex:Vector3 in [a-width,b-width,a+width,a+width,b-width,b+width]:
   ribbon_mesh.surface_set_normal(normal);ribbon_mesh.surface_add_vertex(vertex)
 ribbon_mesh.surface_end()
 sling.global_transform=rig.global_transform
