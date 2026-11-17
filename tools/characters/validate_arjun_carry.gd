extends SceneTree
## Actual player, final stance and selected carried weapon under real input.
class PoseProbe extends Node:
 signal sampled
 func _process(_delta:float)->void:sampled.emit()

var failures:Array[String]=[]
var actor:CharacterBody3D
var visual:Node3D
var camera:Camera3D
var worst_angle:=0.0
var cover_wall:StaticBody3D
func check(ok:bool,label:String)->void:
 print(("PASS " if ok else "FAIL ")+label)
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var stage:=Node3D.new();root.add_child(stage);current_scene=stage
 var clock:Node=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";stage.add_child(clock)
 var environment:=WorldEnvironment.new();stage.add_child(environment);environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.25,.29,.32)
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-30,0);light.shadow_enabled=true;stage.add_child(light)
 var floor:=StaticBody3D.new();stage.add_child(floor)
 var shape:=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(150,.4,150);shape.position.y=-.2;floor.add_child(shape)
 var floor_mesh:=MeshInstance3D.new();floor_mesh.mesh=BoxMesh.new();floor_mesh.mesh.size=shape.shape.size;floor_mesh.position=shape.position;floor.add_child(floor_mesh)
 var ground_material:=StandardMaterial3D.new();ground_material.albedo_color=Color(.30,.32,.31);ground_material.roughness=1;floor_mesh.material_override=ground_material
 actor=load("res://player/player.tscn").instantiate();stage.add_child(actor);actor.position=Vector3(0,1,0)
 for frame in 60:await physics_frame
 visual=actor.get_node("VisualRoot/CharacterVisual")
 if OS.get_environment("TLM_CARRY_OPENING")=="1":
  load("res://player/arjun_complete_fit.gd").new().apply(visual)
  for frame in 3:await physics_frame
 var equipment:Node3D=visual.equipment
 var carry:Node3D=equipment.carry_motion
 var garments:Array[Dictionary]=[]
 for node:MeshInstance3D in carry.support_nodes:
  garments.append({"node":node,"mesh":node.mesh})
  node.mesh=null
 carry.refresh_support()
 check(carry.support.is_empty(),"Missing garment meshes leave carry support empty")
 for garment in garments:garment.node.mesh=garment.mesh
 carry.refresh_support()
 check(not garments.is_empty() and not carry.support.is_empty(),"Carry support recovers after garment meshes return")
 camera=Camera3D.new();stage.add_child(camera);camera.fov=42
 actor.get_node("UI").hide()
 actor.get_node("InventoryComponent").add_item("enfield",1)
 actor.get_node("InventoryComponent").add_item("talwar",1)
 actor.get_node("InventoryComponent").add_item("double_gun",1)
 var stance:Node=actor.get_node("StealthStance")
 var pose_probe:=PoseProbe.new();pose_probe.process_priority=1000;stage.add_child(pose_probe)
 for weapon in [0,1,5]:
  # Keep cadence sweeps on the same physical floor rather than accumulating
  # three long 30 Hz routes past the edge of this isolated stage.
  actor.position=Vector3(0,1,0);actor.velocity=Vector3.ZERO
  for frame in 10:await physics_frame
  equipment.selected=weapon;equipment.stowed=true;equipment._refresh()
  for mode in ["idle","run","turn","stop","crouch","crouch_walk","rise","cover","peek","lose_cover","recover","prone","crawl","stand"]:
   Input.action_release("move_left");Input.action_release("move_forward");Input.action_release("sprint");Input.action_release("aim")
   if mode in ["run","turn"]:Input.action_press("move_forward");Input.action_press("sprint")
   if mode=="turn":Input.action_press("move_left")
   if mode=="crouch":stance.enter_crouch()
   if mode=="crouch_walk":Input.action_press("move_forward")
   if mode in ["rise","recover","stand"]:stance.stand()
   if mode=="cover":
    cover_wall=StaticBody3D.new();stage.add_child(cover_wall)
    var forward:Vector3=-actor.get_node("CameraPivot").global_basis.z;forward.y=0;forward=forward.normalized()
    cover_wall.global_position=actor.global_position+forward*.9-Vector3.UP*.35
    cover_wall.look_at(cover_wall.global_position+forward,Vector3.UP)
    var wall_shape:=CollisionShape3D.new();wall_shape.shape=BoxShape3D.new();wall_shape.shape.size=Vector3(2,1.1,.2);cover_wall.add_child(wall_shape)
    var wall_mesh:=MeshInstance3D.new();wall_mesh.mesh=BoxMesh.new();wall_mesh.mesh.size=wall_shape.shape.size;cover_wall.add_child(wall_mesh)
    await physics_frame;check(stance.try_cover(),"real solid cover acquired")
   if mode=="peek":Input.action_press("aim")
   if mode=="lose_cover":cover_wall.queue_free()
   if mode=="prone":stance.enter_prone()
   if mode=="crawl":Input.action_press("move_forward")
   var layer_worst:=0;var layer_samples:=0;var layer_depth:=0.0;var hand_worst:=0
   var low_drifts:Array[float]=[];var last_feet:Dictionary={};var last_support:Dictionary={}
   for frame in 75:
    await physics_frame
    await pose_probe.sampled
    worst_angle=maxf(worst_angle,equipment.carry_motion.angles.length())
    if weapon==0 and mode=="crouch_walk" and frame>15:
     var contact:Node=visual.get_node("LocomotionFootContact")
     for side in ["l","r"]:
      var bone:int=visual.skeleton.find_bone("foot_"+side)
      var foot:Vector3=visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(bone).origin)
      var supported:bool=contact.contacts.has(side) and contact.plant_weights.get(side,0.0)>.9
      if supported and last_support.get(side,false):
       var prior:Vector3=last_feet[side]
       low_drifts.append(Vector2(foot.x-prior.x,foot.z-prior.z).length())
      last_feet[side]=foot;last_support[side]=supported
    if weapon==0 and mode in ["idle","run","turn","crouch_walk"] and frame>=15 and frame%10==0:
     var layers:=inspect_front_layers()
     layer_worst=maxi(layer_worst,layers.intersections);layer_samples+=layers.samples;hand_worst=maxi(hand_worst,layers.hand_inside)
     layer_depth=maxf(layer_depth,layers.worst_m)
     if not layers.roles.is_empty():print("ARJUN LAYER ROLES ",mode," ",layers.roles)
   if weapon==0 and mode=="crouch_walk":
    low_drifts.sort()
    var p90:float=low_drifts[floori((low_drifts.size()-1)*.9)] if not low_drifts.is_empty() else INF
    var maximum:float=low_drifts.back() if not low_drifts.is_empty() else INF
    print("ARJUN CROUCH CONTACT samples=",low_drifts.size()," p90_m=",p90," max_m=",maximum)
    check(low_drifts.size()>=4 and p90<.025 and maximum<.08,"crouch support feet stay planted during travel")
   var item:Node3D=equipment.talwar_waist if weapon==0 else equipment.enfield_back if weapon==1 else equipment.double_back
   check(item.visible and not equipment.talwar_hand.visible and not equipment.enfield_hand.visible and not equipment.double_hand.visible,"single stowed copy "+str(weapon)+" "+mode)
   check(equipment.carry_motion.angles.is_finite() and equipment.carry_motion.angular_velocity.is_finite(),"finite carry response")
   check(equipment.carry_motion.suspension_error<.001,"weapon remains attached at suspension")
   check(equipment.carry_motion.support.size()>10,"cached cloth supports available")
   var support_top:float=-INF
   for sample:Dictionary in equipment.carry_motion.support:support_top=maxf(support_top,sample.point.y)
   check(support_top>1.4,"sling reaches actual shoulder cloth rather than only the hem")
   if mode=="stop":check(equipment.carry_motion.angles.length()<.015,"carry settles after stop")
   if mode=="lose_cover":check(stance.stance=="crouch","lost cover remains crouched")
   if mode=="crawl":check(stance.stance=="prone","real crawl stance retained")
   if mode in ["crouch","prone"]:check(stance.camera_height()<stance.base_height,"low camera follows lowered body")
   if stance.is_low():check(visual.get_node("LocomotionFootContact").last_stance_low==(stance.cover_blend>.01 and stance.prone_blend<.01),"low stance uses its own fresh foot contact state")
   if weapon==0 and mode in ["idle","run","turn","crouch_walk"]:
    print("ARJUN CLOTH LAYERS ",mode," samples=",layer_samples," worst_intersections=",layer_worst," depth_m=",layer_depth," hand_inside=",hand_worst)
    check(hand_worst==0,"relaxed fingers remain outside hem "+mode)
    check(layer_samples>500 and layer_worst==0,"covered body/foundation/trousers remain beneath hem "+mode)
   await capture(str(weapon)+"_"+mode)
  equipment.stowed=false;equipment._refresh();await process_frame
  check(not equipment.enfield_back.visible and not equipment.talwar_waist.visible and not equipment.double_back.visible,"drawing removes stowed copy")
  equipment.stowed=true;equipment._refresh();await process_frame
  actor.position+=Vector3(10,0,0);await process_frame
  check(equipment.carry_motion.angular_velocity.length()<.01,"teleport resets carry inertia")
 Input.action_release("move_left");Input.action_release("move_forward");Input.action_release("sprint");Input.action_release("aim")
 check(worst_angle<.12,"restrained carry angular displacement")
 print("ARJUN CARRY: ","PASS" if failures.is_empty() else "FAIL"," max_angle=",worst_angle)
 root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
func capture(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 for view in ["back","side","front"]:
  var offset:=Vector3(2.4,.8,-3.4) if view=="back" else Vector3(3.8,.5,.8) if view=="side" else Vector3(-1.8,.7,3.6)
  camera.global_position=actor.global_position+actor.get_node("VisualRoot").global_basis*offset
  camera.look_at(actor.global_position+Vector3.UP*.1);camera.make_current()
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("TLM_STORY_TEST_DIR").path_join("carry_"+label+"_"+view+".png"))

func inspect_front_layers()->Dictionary:
 # Project actual evaluated front triangles into XY and compare the underlying
 # trouser vertices only where an overlying hem triangle exists (splits remain).
 var rig:Skeleton3D=visual.skeleton
 var hem:MeshInstance3D=visual.model.find_child("Arjun_Kurta_SplitHem",true,false)
 var triangles:Array[PackedVector3Array]=[]
 var front_faces:Array[bool]=[]
 var bins:Dictionary={}
 for surface in hem.mesh.get_surface_count():
  var arrays:=hem.mesh.surface_get_arrays(surface)
  var points:=skin_points(hem,arrays)
  var original:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
  if indices.is_empty():indices=PackedInt32Array(range(points.size()))
  for face in range(0,indices.size(),3):
   var a:int=indices[face];var b:int=indices[face+1];var c:int=indices[face+2]
   var triangle:=PackedVector3Array([points[a],points[b],points[c]])
   var index:=triangles.size();triangles.append(triangle)
   front_faces.append((original[a].z+original[b].z+original[c].z)/3.0>.07)
   var minimum:=Vector2(minf(points[a].x,minf(points[b].x,points[c].x)),minf(points[a].y,minf(points[b].y,points[c].y)))
   var maximum:=Vector2(maxf(points[a].x,maxf(points[b].x,points[c].x)),maxf(points[a].y,maxf(points[b].y,points[c].y)))
   for x in range(floori(minimum.x/.04),floori(maximum.x/.04)+1):
    for y in range(floori(minimum.y/.04),floori(maximum.y/.04)+1):
     var key:=Vector2i(x,y)
     if not bins.has(key):bins[key]=[]
     bins[key].append(index)
 var samples:=0;var intersections:=0;var worst:=0.0;var roles:Dictionary={};var hand_inside:=0;var hand_samples:=0
 var underlayers:Array[Node]=[]
 for mesh:MeshInstance3D in visual.model.find_children("*","MeshInstance3D",true,false):
  if mesh.skin!=null and (mesh.name=="Arjun_MakeHuman_Body" or "DrapedTrousers" in str(mesh.name) or "foundation" in str(mesh.name).to_lower() or mesh.has_meta("fitting_source")):
   underlayers.append(mesh)
 for pants:MeshInstance3D in underlayers:
  for surface in pants.mesh.get_surface_count():
   var arrays:=pants.mesh.surface_get_arrays(surface)
   var points:=skin_points(pants,arrays)
   var original:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   for vertex in points.size():
    var skin_bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
    var skin_weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
    var slots:int=skin_weights.size()/points.size();var amount:=0.0;var slot_id:=0
    for slot in slots:
     if skin_weights[vertex*slots+slot]>amount:amount=skin_weights[vertex*slots+slot];slot_id=skin_bones[vertex*slots+slot]
    var role:=str(pants.skin.get_bind_name(slot_id))
    var free_hand:bool=pants.name=="Arjun_MakeHuman_Body" and (role.begins_with("upperarm_") or role.begins_with("lowerarm_") or role.begins_with("hand_") or role.begins_with("thumb_") or role.begins_with("index_") or role.begins_with("middle_") or role.begins_with("ring_") or role.begins_with("pinky_"))
    if not free_hand and (original[vertex].y<.80 or original[vertex].y>1.02):continue
    var point:=points[vertex];var outer:float=-INF;var inner:float=INF
    for index:int in bins.get(Vector2i(floori(point.x/.04),floori(point.y/.04)),[]):
     var t:PackedVector3Array=triangles[index]
     var a:=Vector2(t[0].x,t[0].y);var b:=Vector2(t[1].x,t[1].y);var c:=Vector2(t[2].x,t[2].y);var p:=Vector2(point.x,point.y)
     var area:float=(b-a).cross(c-a)
     if absf(area)<.0000001:continue
     var u:float=(p-a).cross(c-a)/area;var v:float=(b-a).cross(p-a)/area
     if u<0 or v<0 or u+v>1:continue
     var height:float=t[0].z*(1-u-v)+t[1].z*u+t[2].z*v
     if front_faces[index]:outer=maxf(outer,height)
     inner=minf(inner,height)
    if not is_finite(outer):continue
    if free_hand:
     hand_samples+=1
     if outer-inner>.015 and point.z>inner+.003 and point.z<outer-.003:hand_inside+=1
     continue
    samples+=1;worst=maxf(worst,point.z-outer)
    if point.z>outer+.003:
     intersections+=1
     roles[role]=int(roles.get(role,0))+1
 return {"samples":samples,"intersections":intersections,"worst_m":worst,"roles":roles,"hand_inside":hand_inside,"hand_samples":hand_samples}

func skin_points(mesh:MeshInstance3D,arrays:Array)->PackedVector3Array:
 var rig:Skeleton3D=visual.skeleton
 var palette:Array[Transform3D]=[]
 for bind in mesh.skin.get_bind_count():
  var bone:=rig.find_bone(mesh.skin.get_bind_name(bind))
  if bone<0:bone=mesh.skin.get_bind_bone(bind)
  palette.append(rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var count:int=weights.size()/vertices.size()
 var result:=PackedVector3Array();result.resize(vertices.size())
 for vertex in vertices.size():
  var point:=Vector3.ZERO
  for slot in count:
   var index:=vertex*count+slot
   if weights[index]>.00001:point+=(palette[bones[index]]*vertices[vertex])*weights[index]
  result[vertex]=point
 return result
