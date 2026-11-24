"""Isolated full-body civilian garment repair. Preserve original sources.
Blender --background --python tools/characters/repair_workplace_civilians.py
"""
import bpy, bmesh, math, json, hashlib, struct
from pathlib import Path
import sys
from mathutils import Vector
from mathutils.kdtree import KDTree
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT))
from tools.characters.cloth_signature import geometry_signature
OUT=ROOT/'WorkingAssets/NPCs/workplace_repair';OUT.mkdir(parents=True,exist_ok=True)
RUNTIME=ROOT/'characters/npcs/workplace_repair';RUNTIME.mkdir(parents=True,exist_ok=True)
def material(name,color):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=.88
 return m
def mesh_object(name,vertices,faces,weights,rig,mat):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
 obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);obj.data.materials.append(mat)
 for i,entries in enumerate(weights):
  for bone,weight in entries.items():
   (obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)).add([i],weight,'REPLACE')
 obj.parent=rig
 obj.modifiers.new('Fabric skin','ARMATURE').object=rig
 for face in mesh.polygons:face.use_smooth=True
 return obj
reports=[]
for slug in ['village_farmer','village_weaver_assistant','village_woman','village_fruit_seller']:
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs'/slug/(slug+'_mpfb.blend')))
 rig=bpy.data.objects[slug+'_rig'];body=bpy.data.objects[slug+'_MakeHuman_body']
 before=hashlib.sha256(b''.join(struct.pack('<3f',*v.co) for v in body.data.vertices)).hexdigest()
 female=slug in ['village_woman','village_fruit_seller']
 # Retain only helper exclusion. Covered anatomical skin is preserved in export.
 for mod in list(body.modifiers):
  if mod.type=='MASK' and mod.name!='Hide helpers':body.modifiers.remove(mod)
 rig.data.pose_position='REST';bpy.context.view_layer.update()
 def bake(obj,label):
  deps=bpy.context.evaluated_depsgraph_get();data=bpy.data.meshes.new_from_object(obj.evaluated_get(deps),preserve_all_data_layers=True,depsgraph=deps)
  copy=bpy.data.objects.new(label,data);bpy.context.collection.objects.link(copy)
  for group in obj.vertex_groups:copy.vertex_groups.new(name=group.name)
  copy.parent=rig;copy.matrix_world=obj.matrix_world.copy();copy.modifiers.new('Skin','ARMATURE').object=rig
  return copy
 skin=bake(body,'Complete anatomical skin')
 # Preserve identical triangle diagonals on body and fitted fabric. Independent
 # glTF tessellation of offset quads can cut a garment through its fitting surface.
 bm=bmesh.new();bm.from_mesh(skin.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(skin.data);bm.free();skin.data.update()
 # Anatomical membership comes from the authoritative rig, not height alone.
 # Lowered hands can occupy the same height as hips without being lower body.
 upper_limb_bones=set()
 for bone in rig.data.bones:
  ancestor=bone
  while ancestor:
   if ancestor.name.startswith(('upperarm','lowerarm','clavicle','hand','finger','thumb')):
    upper_limb_bones.add(bone.name);break
   ancestor=ancestor.parent
 def lower_anatomy(vertex):
  return (skin.matrix_world@vertex.co).z<.96 and not any(skin.vertex_groups[g.group].name in upper_limb_bones and g.weight>.00001 for g in vertex.groups)
 lower_ids={v.index for v in skin.data.vertices if lower_anatomy(v)}
 lower_faces=[p for p in skin.data.polygons if all(i in lower_ids for i in p.vertices)]
 assert lower_faces,'Missing anatomical lower-body fitting surface'
 lower_points=[skin.matrix_world@v.co for v in skin.data.vertices]
 lower_surface=BVHTree.FromPolygons(lower_points,[list(p.vertices) for p in lower_faces])
 lower_weights=KDTree(len(lower_ids))
 for i in lower_ids:lower_weights.insert(lower_points[i],i)
 lower_weights.balance()
 top=bpy.data.objects['Fitted cotton upper base'];reference=bake(top,'Upper coverage reference')
 reference_tree=BVHTree.FromPolygons([reference.matrix_world@v.co for v in reference.data.vertices],[list(p.vertices) for p in reference.data.polygons])
 selected=[]
 for face in skin.data.polygons:
  centre=sum((skin.matrix_world@skin.data.vertices[i].co for i in face.vertices),Vector())/len(face.vertices)
  near,normal,index,distance=reference_tree.find_nearest(centre)
  if distance<.045 and centre.z>(.90 if female else .86):selected.append(face)
 indices=sorted({i for face in selected for i in face.vertices});mapping={old:new for new,old in enumerate(indices)}
 vertices=[]
 for i in indices:
  v=skin.data.vertices[i]
  groups={skin.vertex_groups[g.group].name:g.weight for g in v.groups}
  # The underarm seam is compressed between arm and torso. A full outward
  # normal offset there expands fabric into the adjacent anatomical surface.
  arm=sum(w for name,w in groups.items() if name.startswith('upperarm'))
  torso=sum(w for name,w in groups.items() if name.startswith('spine') or name=='clavicle_l' or name=='clavicle_r')
  seam=min(1.0,min(arm,torso)/.15)
  ease=.005*(1-seam)+.0015*seam
  vertices.append(tuple(skin.matrix_world@(v.co+v.normal*ease)))
 weights=[{skin.vertex_groups[g.group].name:g.weight for g in skin.data.vertices[i].groups} for i in indices]
 upper=mesh_object('Fitted cotton upper repaired',vertices,[tuple(mapping[i] for i in face.vertices) for face in selected],weights,rig,reference.data.materials[0])
 bpy.data.objects.remove(reference,do_unlink=True)
 foundation=material('Opaque cotton foundation',(.25,.19,.13))
 def foundation_piece(label,filter_face):
  selected=[p for p in skin.data.polygons if filter_face(sum((skin.matrix_world@skin.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)) and all(not any(skin.vertex_groups[g.group].name in upper_limb_bones and g.weight>.00001 for g in skin.data.vertices[i].groups) for i in p.vertices)]
  indices=sorted({i for p in selected for i in p.vertices});mapping={old:new for new,old in enumerate(indices)}
  vertices=[];weights=[]
  for i in indices:
   v=skin.data.vertices[i];vertices.append(tuple(skin.matrix_world@(v.co+v.normal*.001)))
   weights.append({skin.vertex_groups[g.group].name:g.weight for g in v.groups})
  return mesh_object(label,vertices,[tuple(mapping[i] for i in p.vertices) for p in selected],weights,rig,foundation)
 foundation_piece('Opaque fitted foundation bottom',lambda p:.65<p.z<.89 and (not female or p.z>.81 or abs(p.x)<.045))
 if female:foundation_piece('Opaque fitted foundation top',lambda p:1.03<p.z<1.24)
 if not female:
  for name in ['Knee length wrapped dhoti','Dhoti woven border']:
   obj=bpy.data.objects.get(name)
   if obj:bpy.data.objects.remove(obj,do_unlink=True)
  cotton=material('Wrapped dhoti cotton',(.76,.73,.65))
  # One continuous fitting surface includes the waist and crotch. The old
  # overlapping leg-cylinder tops cut through the pelvis even while idle.
  faces=[p for p in lower_faces if .38<sum(skin.data.vertices[i].co.z for i in p.vertices)/len(p.vertices)<.87]
  ids=sorted({i for p in faces for i in p.vertices});mapping={i:j for j,i in enumerate(ids)}
  edge_counts={}
  for face in faces:
   for a,b in zip(face.vertices,list(face.vertices[1:])+[face.vertices[0]]):
    edge=tuple(sorted((a,b)));edge_counts[edge]=edge_counts.get(edge,0)+1
  hem_ids={i for edge,count in edge_counts.items() if count==1 for i in edge if (skin.matrix_world@skin.data.vertices[i].co).z<.5}
  vertices=[];weights=[]
  for i in ids:
   v=skin.data.vertices[i];point=skin.matrix_world@v.co
   # Loose outer cotton folds, compressed inner-leg fabric, gathered waist.
   inner=v.normal.x*(1 if point.x>=0 else -1)<-.15
   waist=max(0,min(1,(point.z-.71)/.14))
   ease=(.004 if inner else .032)*(1-waist)+.012*waist
   if not inner:ease+=.004*(.5+.5*math.cos(math.atan2(point.y,abs(point.x)-.1)*10))*(1-waist)
   cloth_point=skin.matrix_world@(v.co+v.normal*ease)
   if i in hem_ids:cloth_point.z=.38
   vertices.append(tuple(cloth_point))
   weights.append({skin.vertex_groups[g.group].name:g.weight for g in v.groups})
  mesh_object('Tucked dhoti leg folds',vertices,[tuple(mapping[i] for i in p.vertices) for p in faces],weights,rig,cotton)
 else:
  for name in ['Wrapped sari lower drape','Sari lower border']:
   obj=bpy.data.objects.get(name)
   if obj:
    for v in obj.data.vertices:
     v.co.x*=1.17;v.co.y*=1.22
    # Follow the anatomical legs through knee bends rather than keeping 88%
    # of the whole skirt rigidly attached to the pelvis. Blend nearby body
    # weights to avoid a hard left/right seam through the wrapped cloth.
    tree=lower_weights
    obj.vertex_groups.clear()
    for v in obj.data.vertices:
     world_point=obj.matrix_world@v.co;entries={};total=0.0
     for point,index,distance in tree.find_n(world_point,4):
      influence=1/max(.01,distance)**2;total+=influence
      for group in skin.data.vertices[index].groups:
       bone=skin.vertex_groups[group.group].name
       if bone in rig.data.bones:entries[bone]=entries.get(bone,0)+group.weight*influence
     norm=sum(entries.values())
     for bone,weight in entries.items():
      (obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)).add([v.index],weight/norm,'REPLACE')
 # Fit headwear to this body's crown rather than a common world height.
 cap=bpy.data.objects.get('Soft cotton head wrap')
 if cap:
  crown=max((skin.matrix_world@v.co).z for v in skin.data.vertices)
  bottom=min((cap.matrix_world@v.co).z for v in cap.data.vertices)
  drop=min(0.0,crown-.10-bottom)
  assert drop>=-.15,'Headwear requires a new construction rather than an excessive shift'
  for name in ['Soft cotton head wrap','Head wrap fold']:
   piece=bpy.data.objects.get(name)
   if piece:
    local=piece.matrix_world.inverted().to_3x3()@Vector((0,0,drop))
    for v in piece.data.vertices:v.co+=local
  print('HEADWEAR_CROWN_ANCHOR',slug,drop,flush=True)
 # Carried props must be authored/attached by the task-specific runtime activity.
 for obj in list(bpy.data.objects):
  if 'folded cloth' in obj.name.lower() or 'basket' in obj.name.lower():bpy.data.objects.remove(obj,do_unlink=True)
 # Fit exported fabric against the retained anatomical surface in rest space.
 # Original covered-body masks hid these intersections; do not restore masks.
 skin_points=[skin.matrix_world@v.co for v in skin.data.vertices]
 skin_tree=BVHTree.FromPolygons(skin_points,[list(p.vertices) for p in skin.data.polygons])
 weight_tree=KDTree(len(skin_points))
 for index,point in enumerate(skin_points):weight_tree.insert(point,index)
 weight_tree.balance()
 for cloth in list(bpy.data.objects):
  if cloth.type!='MESH' or cloth in [body,top,skin,upper] or 'foundation' in cloth.name.lower() or 'hair' in cloth.name.lower() or 'eye' in cloth.name.lower():continue
  if not any(m.type=='ARMATURE' for m in cloth.modifiers):continue
  if cloth.name=='Tucked dhoti leg folds':continue
  # Add surface resolution before fitting. Sparse skirt quads can have
  # outside vertices while their triangle centres cut through bent knees.
  bpy.context.view_layer.objects.active=cloth
  resolution=cloth.modifiers.new('Fabric contact resolution','SUBSURF');resolution.subdivision_type='SIMPLE';resolution.levels=2 if 'sari' in cloth.name.lower() else 1
  bpy.ops.object.modifier_apply(modifier=resolution.name)
  lower_garment=cloth.name in ['Wrapped sari lower drape','Sari lower border','Kurta loose lower panel']
  fitting_surface=lower_surface if lower_garment else skin_tree
  fitting_weights=lower_weights if lower_garment else weight_tree
  weight_points=[cloth.matrix_world@v.co for v in cloth.data.vertices]
  for v in cloth.data.vertices:
   point=cloth.matrix_world@v.co;near,normal,polygon,distance=fitting_surface.find_nearest(point)
   signed=(point-near).dot(normal)
   clearance=.005 if 'head wrap' in cloth.name.lower() else .020
   if signed<clearance and distance<.15:v.co=cloth.matrix_world.inverted()@(point+normal*(clearance-signed))
  # The divided dhoti already has explicit side-specific leg bindings.
  # A nearest-surface reassignment can bind an inner fold to the opposite leg.
  if cloth.name=="Tucked dhoti leg folds":continue
  # Blend lower wrap correspondence across neighbouring anatomical vertices.
  cloth.vertex_groups.clear()
  for v in cloth.data.vertices:
   entries={}
   for point,index,distance in fitting_weights.find_n(weight_points[v.index],4 if "sari" in cloth.name.lower() else 1):
    influence=1/max(.01,distance)**2
    for group in skin.data.vertices[index].groups:
     bone=skin.vertex_groups[group.group].name
     if bone in rig.data.bones:entries[bone]=entries.get(bone,0)+group.weight*influence
   norm=sum(entries.values())
   entries={bone:weight/norm for bone,weight in entries.items()}
   if cloth.name=='Kurta loose lower panel':
    # The sewn waist edge follows the pelvis; its lower fabric can follow legs.
    seam=max(0.0,min(1.0,((cloth.matrix_world@v.co).z-.82)/.07))
    entries={bone:weight*(1-seam) for bone,weight in entries.items()}
    entries['pelvis']=entries.get('pelvis',0)+seam
   for bone,weight in entries.items():
    if weight>0:(cloth.vertex_groups.get(bone) or cloth.vertex_groups.new(name=bone)).add([v.index],weight,'REPLACE')
 # This is a construction gate, not a visual/motion approval.
 for name in ['Tucked dhoti leg folds','Wrapped sari lower drape','Sari lower border','Kurta loose lower panel']:
  cloth=bpy.data.objects.get(name)
  if cloth:
   for vertex in cloth.data.vertices:
    assert not any(cloth.vertex_groups[g.group].name in upper_limb_bones and g.weight>.00001 for g in vertex.groups),'Lower cloth contains arm anatomy/weights: '+slug+' '+name
   print('LOWER_ANATOMY_GATE',slug,name,len(cloth.data.vertices),'zero arm influence',flush=True)
 # Native-pose contact corrections are garment-only, indexed against the
 # deterministic post-subdivision fabric topology. Body/source hashes remain.
 corrections=OUT/'contact_fit.json'
 if corrections.exists():
  for name,vertices in json.loads(corrections.read_text()).get(slug,{}).items():
   cloth=bpy.data.objects.get(name)
   if cloth is None:raise RuntimeError('Missing fitted garment '+name)
   for index,delta in vertices.items():cloth.data.vertices[int(index)].co+=Vector(delta)
 pose_fit=OUT/'pose_fit.json'
 if pose_fit.exists():
  fitted=json.loads(pose_fit.read_text()).get(slug,{})
  for name,samples in fitted.get('garments',{}).items():
   cloth=bpy.data.objects.get(name)
   if cloth is None:raise RuntimeError('Missing corrective garment '+name)
   expected=fitted.get('source_signature',{}).get(name)
   if expected is not None and geometry_signature(cloth)!=expected:raise RuntimeError('Corrective bank geometry/weights changed; recapture and refit '+slug+' '+name)
   basis=cloth.shape_key_add(name='Basis',from_mix=False)
   for sample,vertices in samples.items():
    key=cloth.shape_key_add(name='Contact_'+sample,from_mix=False)
    # Never initialize from the active previous corrective: every target is
    # an independent displacement from the one authoritative fabric basis.
    for i,point in enumerate(basis.data):key.data[i].co=point.co.copy()
    for index,delta in vertices.items():key.data[int(index)].co=basis.data[int(index)].co+Vector(delta)
    expected=max((Vector(delta).length for delta in vertices.values()),default=0.0)
    actual=max((point.co-basis.data[i].co).length for i,point in enumerate(key.data))
    assert abs(actual-expected)<.00001 and actual<=.15,'Corrective accumulation or excessive displacement: '+sample
 # Morph import needs a valid UV channel for tangent construction. Give
 # generated fabric continuous cylindrical coordinates, split only at its seam.
 for obj in bpy.data.objects:
  if obj.type!='MESH' or obj in [body,top,skin] or obj.data.uv_layers:continue
  uv=obj.data.uv_layers.new(name='FabricUV')
  for face in obj.data.polygons:
   coordinates=[]
   for loop in face.loop_indices:
    v=obj.data.vertices[obj.data.loops[loop].vertex_index].co
    coordinates.append([math.atan2(v.x,-v.y)/math.tau+.5,v.z])
   if max(p[0] for p in coordinates)-min(p[0] for p in coordinates)>.5:
    for coordinate in coordinates:
     if coordinate[0]<.5:coordinate[0]+=1
   for loop,coordinate in zip(face.loop_indices,coordinates):uv.data[loop].uv=coordinate
 texture_dir=OUT/'textures'/slug;texture_dir.mkdir(parents=True,exist_ok=True)
 payload=(ROOT/'characters/npcs'/(slug+'.glb')).read_bytes()
 json_len=struct.unpack_from('<I',payload,12)[0];document=json.loads(payload[20:20+json_len]);binary=payload[28+json_len:]
 recovered={}
 for entry in document.get('images',[]):
  if 'bufferView' not in entry:continue
  view=document['bufferViews'][entry['bufferView']];start=view.get('byteOffset',0)
  path=texture_dir/(entry.get('name','image')+'.png');path.write_bytes(binary[start:start+view['byteLength']]);recovered[entry.get('name','')]=path
 for image in bpy.data.images:
  if image.source!='FILE':continue
  key=Path(image.name).stem
  match=recovered.get(key)
  if match:
   if image.packed_file:image.unpack(method='REMOVE')
   image.filepath=str(match);image.reload();image.pack()
 bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
 for obj in bpy.data.objects:
  if obj.type=='MESH' and obj not in [body,top]:obj.select_set(True)
 bpy.context.view_layer.objects.active=rig
 # Complete editable original body, repaired garments and foundation remain in blend.
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(slug+'.blend')))
 bpy.ops.export_scene.gltf(filepath=str(RUNTIME/(slug+'.glb')),export_format='GLB',use_selection=True,export_skins=True,export_animations=False,export_apply=False)
 after=hashlib.sha256(b''.join(struct.pack('<3f',*v.co) for v in body.data.vertices)).hexdigest()
 assert before==after,'Authoritative body changed'
 reports.append({'role':slug,'body_vertices_unchanged':before==after,'body_hash':after,'skin_export_vertices':len(skin.data.vertices),'status':'REPAIR_CANDIDATE_REQUIRES_NATIVE_MOTION_REVIEW'})
(OUT/'manifest.json').write_text(json.dumps(reports,indent=2))
print('CIVILIAN_REPAIR_EXPORT',json.dumps(reports))
