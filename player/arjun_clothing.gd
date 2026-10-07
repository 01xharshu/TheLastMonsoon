extends Node3D
## Cloth surface response and named carrying points, independent of item art.
const CLOTH_SHADER = preload("res://characters/arjun/cloth_detail.gdshader")
var rig: Skeleton3D
var materials: Array[ShaderMaterial] = []
var moisture := 0.0
var belt: MeshInstance3D
var sockets: Dictionary = {}
var shoulder: MeshInstance3D
var leather: StandardMaterial3D
var fabric_sway := Vector2.ZERO
var fabric_velocity := Vector2.ZERO
var previous_velocity := Vector3.ZERO
var shoulder_stitches: MeshInstance3D
var thread: StandardMaterial3D
var tailored_meshes := 0

func setup(model: Node3D, skeleton: Skeleton3D) -> void:
 rig = skeleton
 process_priority = 15
 preload("res://player/arjun_trouser_fit.gd").apply(model)
 for node in model.find_children("*", "MeshInstance3D", true, false):
  for index in node.mesh.get_surface_count():
   var original = node.mesh.surface_get_material(index)
   if not original is BaseMaterial3D: continue
   if not ("cotton" in original.resource_name.to_lower() or "sash" in original.resource_name.to_lower() or "foundation" in original.resource_name.to_lower()): continue
   var cloth := ShaderMaterial.new()
   cloth.shader = CLOTH_SHADER
   cloth.set_shader_parameter("has_atlas", original.albedo_texture != null)
   cloth.set_shader_parameter("base_atlas", original.albedo_texture)
   cloth.set_shader_parameter("cloth_color", original.albedo_color)
   var kind := 1 if node.name == "Arjun_Kurta_SplitHem" else (2 if str(node.name).begins_with("Sash hanging tail") or node.name == "Arjun_Detail_Faded madder-red sash" else 0)
   cloth.set_shader_parameter("garment_kind", kind)
   node.set_surface_override_material(index, cloth)
   materials.append(cloth)
 _tailor_hem(model)
 thread = StandardMaterial3D.new()
 thread.albedo_color = Color(.25,.16,.085)
 thread.roughness = .96
 thread.cull_mode = BaseMaterial3D.CULL_DISABLED
 leather = StandardMaterial3D.new()
 leather.albedo_color = Color(0.065, 0.032, 0.016)
 leather.roughness = 0.78
 leather.cull_mode = BaseMaterial3D.CULL_DISABLED
 # Rest-space mounting points sit outside the eased waist, not inside the body.
 for entry in [["hip_left", Vector3(.22,1.065,.02)], ["hip_right", Vector3(-.22,1.065,.02)], ["back_upper", Vector3(0,1.39,-.205)]]:
  var socket := BoneAttachment3D.new()
  socket.name = str(entry[0]) + "Mount"
  socket.bone_name = "spine_03" if entry[0] == "back_upper" else "pelvis"
  rig.add_child(socket)
  var marker := Marker3D.new()
  marker.name = "ClothingMount"
  socket.add_child(marker)
  marker.transform = rig.get_bone_global_rest(rig.find_bone(socket.bone_name)).affine_inverse() * Transform3D(Basis.IDENTITY, entry[1])
  sockets[entry[0]] = marker
 var waist := BoneAttachment3D.new()
 waist.name = "ClothingCarryBelt"
 waist.bone_name = "pelvis"
 rig.add_child(waist)
 belt = MeshInstance3D.new()
 belt.name = "LeatherBeltWithRaisedEdges"
 waist.add_child(belt)
 belt.transform = rig.get_bone_global_rest(rig.find_bone("pelvis")).affine_inverse()
 belt.mesh = _belt_mesh()
 var stitches := MeshInstance3D.new()
 stitches.name = "BeltSaddleStitch"
 waist.add_child(stitches)
 stitches.transform = belt.transform
 stitches.mesh = _belt_stitches()
 var fittings := Node3D.new()
 fittings.name = "BuckleAndKeepers"
 waist.add_child(fittings)
 fittings.transform = belt.transform
 var brass := StandardMaterial3D.new()
 brass.albedo_color = Color(.23,.14,.055)
 brass.metallic = .7
 brass.roughness = .55
 for edge in [[Vector3(-.020,1.064,.198),Vector3(.004,.037,.004)], [Vector3(.020,1.064,.198),Vector3(.004,.037,.004)], [Vector3(0,1.083,.198),Vector3(.044,.004,.004)], [Vector3(0,1.045,.198),Vector3(.044,.004,.004)], [Vector3(0,1.064,.199),Vector3(.037,.002,.002)]]:
  var part := MeshInstance3D.new()
  var box := BoxMesh.new()
  box.size = edge[1]
  part.mesh = box
  part.position = edge[0]
  part.material_override = brass
  fittings.add_child(part)
 for sign_side in [-1.0,1.0]:
  var loop := MeshInstance3D.new()
  var box := BoxMesh.new()
  box.size = Vector3(.008,.054,.022)
  loop.mesh = box
  loop.position = Vector3(sign_side*.211,1.061,.02)
  loop.material_override = leather
  fittings.add_child(loop)
 shoulder = MeshInstance3D.new()
 shoulder.name = "LoadBearingShoulderStrap"
 rig.add_child(shoulder)
 shoulder.skeleton = shoulder.get_path_to(rig)
 shoulder.mesh = _shoulder_mesh()
 var skin := Skin.new()
 for bone_name in ["pelvis","spine_03"]:
  var index := rig.find_bone(bone_name)
  skin.add_bind(index, rig.get_bone_global_rest(index).affine_inverse())
 shoulder.skin = skin
 shoulder.hide()
 shoulder_stitches = MeshInstance3D.new()
 shoulder_stitches.name = "ShoulderSaddleStitch"
 rig.add_child(shoulder_stitches)
 shoulder_stitches.skeleton = shoulder_stitches.get_path_to(rig)
 shoulder_stitches.skin = skin
 shoulder_stitches.mesh = _shoulder_mesh(true)
 shoulder_stitches.hide()

func _belt_mesh() -> ArrayMesh:
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 # Closed 3 mm thick leather band: raised edges and a slightly recessed face.
 var profile := [Vector2(-.017,0),Vector2(-.014,.003),Vector2(.014,.003),Vector2(.017,0),Vector2(.017,-.001),Vector2(-.017,-.001)]
 const SEGMENTS = 96
 for segment in SEGMENTS + 1:
  var angle := TAU * float(segment) / SEGMENTS
  for section in profile:
   surface.set_uv(Vector2(float(segment)/SEGMENTS, (section.x+.017)/.034))
   surface.add_vertex(Vector3((.205+section.y)*cos(angle), 1.064+section.x,  .02+(.170+section.y)*sin(angle)))
 for segment in SEGMENTS:
  for section in profile.size():
   var a := segment * profile.size() + section
   var b := segment * profile.size() + (section+1)%profile.size()
   var c := a + profile.size()
   var d := b + profile.size()
   for index in [a,b,c,b,d,c]: surface.add_index(index)
 surface.generate_normals()
 surface.set_material(leather)
 return surface.commit()

func _shoulder_mesh(stitching := false) -> ArrayMesh:
 var path := [Vector3(-.14,1.07,.17),Vector3(-.08,1.18,.18),Vector3(.02,1.31,.18),Vector3(.12,1.42,.14),Vector3(.15,1.435,.08),Vector3(.15,1.445,0),Vector3(.15,1.435,-.08),Vector3(.10,1.39,-.18),Vector3(0,1.28,-.20),Vector3(-.10,1.15,-.17),Vector3(-.17,1.07,-.11),Vector3(-.21,1.07,0),Vector3(-.14,1.07,.17)]
 var smooth_path: Array[Vector3] = []
 for segment in path.size()-1:
  var a: Vector3 = path[maxi(segment-1,0)]
  var b: Vector3 = path[segment]
  var c: Vector3 = path[segment+1]
  var d: Vector3 = path[mini(segment+2,path.size()-1)]
  for step in 6:
   smooth_path.append(b.cubic_interpolate(c,a,d,float(step)/6.0))
 smooth_path.append(path[-1])
 path = smooth_path
 if stitching: return _strap_stitches(path)
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in path.size():
  var point: Vector3 = path[i]
  var tangent: Vector3 = path[mini(i+1,path.size()-1)] - path[maxi(i-1,0)]
  var normal := Vector3(point.x,0,point.z).normalized()
  if point.y > 1.42: normal = normal.lerp(Vector3.UP, smoothstep(1.42,1.45,point.y)).normalized()
  var across := tangent.normalized().cross(normal).normalized()
  var upper_weight := smoothstep(1.07,1.40,point.y)
  for section in [Vector2(-1,0),Vector2(1,0),Vector2(1,-.0025),Vector2(-1,-.0025)]:
   var side: float = section.x
   surface.set_normal(-normal if section.y == 0.0 else normal)
   surface.set_bones(PackedInt32Array([0,1,0,0]))
   surface.set_weights(PackedFloat32Array([1.0-upper_weight,upper_weight,0,0]))
   surface.set_uv(Vector2((side+1)/2,float(i)/path.size()))
   surface.add_vertex(point + across * side * .018 + normal * section.y)
 for i in path.size()-1:
  for section in 4:
   var a := i*4+section
   var b := i*4+(section+1)%4
   for index in [a,b,a+4,b,b+4,a+4]: surface.add_index(index)
 surface.set_material(leather)
 return surface.commit()

func mount_item(item: Node3D, point: String, local_fit: Transform3D = Transform3D.IDENTITY) -> bool:
 if not sockets.has(point): return false
 if item.get_parent() != null: item.reparent(sockets[point], false)
 else: sockets[point].add_child(item)
 item.transform = local_fit
 if point == "back_upper":
  shoulder.show()
  shoulder_stitches.show()
 return true

func _process(delta: float) -> void:
 var actor = get_parent().actor
 var wet: bool = actor.is_swimming if actor != null else false
 moisture = move_toward(moisture, 1.0 if wet else 0.0, delta * (0.65 if wet else 0.025))
 var local_velocity: Vector3 = rig.global_basis.orthonormalized().inverse() * actor.velocity
 var acceleration := (local_velocity - previous_velocity) / maxf(delta,.001)
 previous_velocity = local_velocity
 var goal := Vector2(-acceleration.x,-acceleration.z) * .0007 + Vector2(0,-local_velocity.z) * .0012
 var breeze: Vector3 = rig.global_basis.orthonormalized().inverse() * WindSystem.sample(actor.global_position) * WindSystem.exposure
 goal += Vector2(breeze.x,breeze.z) * .0015
 goal = goal.limit_length(.014) * (1.0-moisture*.4)
 # Substep a damped spring so frame stalls cannot throw fabric through the body.
 var remaining := minf(delta,.1)
 while remaining > .00001:
  var step := minf(remaining,1.0/120.0)
  fabric_velocity += ((goal-fabric_sway)*90.0-fabric_velocity*18.0)*step
  fabric_sway = (fabric_sway+fabric_velocity*step).limit_length(.018)
  remaining -= step
 for material in materials:
  material.set_shader_parameter("wetness", moisture)
  material.set_shader_parameter("fabric_sway", fabric_sway)
 shoulder.visible = sockets.back_upper.get_child_count() > 0
 shoulder_stitches.visible = shoulder.visible

func _tailor_hem(model: Node3D) -> void:
 var node := model.find_child("Arjun_Kurta_SplitHem",true,false) as MeshInstance3D
 if node == null: return
 var result := ArrayMesh.new()
 var binds := {}
 for bind in node.skin.get_bind_count():
  binds[str(node.skin.get_bind_name(bind))] = bind
 for index in node.mesh.get_surface_count():
  var arrays := node.mesh.surface_get_arrays(index)
  var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
  var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
  var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
  var influences: int = weights.size()/vertices.size()
  for i in vertices.size():
   var point := vertices[i]
   # Shared hip transition keeps the split hem over the trouser opening.
   var waist := smoothstep(.96,1.04,point.y)
   var left := clampf(.5+point.x/.10,0.0,1.0)
   for slot in influences:
    bones[i*influences+slot] = 0
    weights[i*influences+slot] = 0.0
   bones[i*influences] = binds["pelvis"]
   bones[i*influences+1] = binds["thigh_l"]
   bones[i*influences+2] = binds["thigh_r"]
   weights[i*influences] = waist
   weights[i*influences+1] = (1.0-waist)*left
   weights[i*influences+2] = (1.0-waist)*(1.0-left)
   var loose := 1.0-smoothstep(.74,1.025,point.y)
   var angle := atan2(point.z-.02,point.x)
   # Unequal hanging folds with the gathered waist pinned; preserve side splits.
   var fold := (.0035*sin(angle*7.0+.6)+.002*sin(angle*11.0-point.y*4.0))*loose
   point.x += cos(angle)*fold
   point.z += sin(angle)*fold
   point.y += .002*sin(angle*5.0)*loose
   vertices[i] = point
  arrays[Mesh.ARRAY_VERTEX] = vertices
  arrays[Mesh.ARRAY_BONES] = bones
  arrays[Mesh.ARRAY_WEIGHTS] = weights
  var mesh := ArrayMesh.new()
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},node.mesh.surface_get_format(index)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
  var surface := SurfaceTool.new()
  surface.create_from(mesh,0)
  surface.generate_normals()
  surface.set_material(node.mesh.surface_get_material(index))
  surface.commit(result)
 node.mesh = result
 tailored_meshes += 1

func _stitch(surface: SurfaceTool, centre: Vector3, tangent: Vector3, across: Vector3, weight: float = -1.0) -> void:
 if weight >= 0:
  surface.set_bones(PackedInt32Array([0,1,0,0]))
  surface.set_weights(PackedFloat32Array([1.0-weight,weight,0,0]))
 for offset in [Vector2(-1,-1),Vector2(1,1),Vector2(-1,1),Vector2(-1,-1),Vector2(1,-1),Vector2(1,1)]:
  surface.add_vertex(centre+tangent*offset.x*.002+across*offset.y*.00035)

func _belt_stitches() -> ArrayMesh:
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in 220:
  var angle := TAU*float(i)/220.0
  for height in [-.012,.012]:
   var point := Vector3(.209*cos(angle),1.064+height,.02+.174*sin(angle))
   _stitch(surface,point,Vector3(-sin(angle),0,cos(angle)),Vector3.UP)
 surface.generate_normals()
 surface.set_material(thread)
 return surface.commit()

func _strap_stitches(path: Array) -> ArrayMesh:
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(1,path.size()-1):
  var point: Vector3 = path[i]
  var tangent: Vector3 = (path[i+1]-path[i-1]).normalized()
  var normal := Vector3(point.x,0,point.z).normalized()
  if point.y > 1.42: normal = normal.lerp(Vector3.UP,smoothstep(1.42,1.45,point.y)).normalized()
  var across := tangent.cross(normal).normalized()
  for side in [-1.0,1.0]:
   _stitch(surface,point+across*side*.014+normal*.0007,tangent,across,smoothstep(1.07,1.40,point.y))
 surface.generate_normals()
 surface.set_material(thread)
 return surface.commit()
