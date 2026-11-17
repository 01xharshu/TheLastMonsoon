"""Trial a sewn cotton blouse surface on the retained MPFB body."""
import bpy,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from river_upper_self_fit import self_hits,points_of,regularize_upper
from street_female_garments import body_volume
from mathutils import Matrix
from whole_body_contract import retain_complete_body
args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
path=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend';bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='REST';body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
for mod in body.modifiers:
 if mod.type=='MASK':mod.show_viewport=False
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();ev=body.evaluated_get(dg);skin=ev.to_mesh();skin.calc_loop_triangles()
core=body.vertex_groups['body'].index;arms={g.index for g in body.vertex_groups if g.name.startswith(('lowerarm_','hand_','thumb_','index_','middle_','ring_','pinky_'))}
upperarms={g.index for g in body.vertex_groups if g.name.startswith('upperarm_')}
def allowed(i):
 v=skin.vertices[i];p=ev.matrix_world@v.co;weights={g.group:g.weight for g in v.groups}
 return weights.get(core,0)>.5 and .94<p.z<1.255 and sum(weights.get(g,0) for g in arms)<.05 and sum(weights.get(g,0) for g in upperarms)<.25
faces=[tuple(t.vertices) for t in skin.loop_triangles if all(allowed(i) for i in t.vertices)]
ids=sorted({i for face in faces for i in face});mapping={i:j for j,i in enumerate(ids)}
if len(ids)<1000:raise RuntimeError('Blouse surface too small')
normal_matrix=ev.matrix_world.to_3x3().inverted().transposed();inverse=rig.matrix_world.inverted();coords=[]
for i in ids:
 p=ev.matrix_world@skin.vertices[i].co;n=(normal_matrix@skin.vertices[i].normal).normalized();coords.append(inverse@(p+n*.015))
mesh=bpy.data.meshes.new('MPFB fitted cotton surface');mesh.from_pydata(coords,[],[tuple(mapping[i] for i in f) for f in faces]);mesh.update()
old=bpy.data.objects['Street coherent cotton blouse and pallu'];backup=old.copy();backup.data=old.data.copy();backup.name='Retained previous street upper';backup['street_source_only']=True;backup.hide_render=True;bpy.context.collection.objects.link(backup);backup.hide_set(True)
material=old.data.materials[0];bpy.data.objects.remove(old,do_unlink=True)
obj=bpy.data.objects.new('Street coherent cotton blouse and pallu',mesh);bpy.context.collection.objects.link(obj);obj.parent=rig
for group in body.vertex_groups:obj.vertex_groups.new(name=group.name)
for j,i in enumerate(ids):
 for g in skin.vertices[i].groups:
  name=body.vertex_groups[g.group].name
  if name in rig.data.bones:obj.vertex_groups[g.group].add([j],g.weight,'REPLACE')
ev.to_mesh_clear();obj.modifiers.new('Same MPFB body weights','ARMATURE').object=rig;mesh.materials.append(material)
color=mesh.color_attributes.new(name='StreetCotton',type='FLOAT_COLOR',domain='POINT');mesh.color_attributes.active_color_index=0;mesh.color_attributes.render_color_index=0
blouse=Vector((.23,.25,.16));sari=Vector((.39,.23,.11))
for v in mesh.vertices:
 p=rig.matrix_world@v.co;centre=.14-(p.z-.85)*.29/.39;edge=min(p.z-.83,1.34-p.z,.02-p.y,.085-abs(p.x-centre));t=max(0,min(1,edge/.015+.5));color.data[v.index].color=(*blouse.lerp(sari,t),1)
for f in mesh.polygons:f.use_smooth=True
obj['construction']='MPFB-fitted cotton with retained separate source and body skin weights'
retain_complete_body(body);bpy.context.view_layer.update();mesh.calc_loop_triangles();hits=self_hits(points_of(obj),[tuple(t.vertices) for t in mesh.loop_triangles]);print('MPFB_UPPER_TRIAL',slug,'vertices',len(ids),'triangles',len(faces),'idle_self',hits,flush=True)
if hits:
 rig.data.pose_position='POSE';rig.animation_data_clear()
 for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
 for mod in body.modifiers:
  if mod.type=='MASK':mod.show_viewport=False
 bpy.context.view_layer.update();tree=body_volume(body);key=obj.shape_key_add(name='Basis');initial=[v.co.copy() for v in key.data]
 regularize_upper(rig,obj,tree,key);maximum=max((v.co-p).length for v,p in zip(key.data,initial))
 if maximum>.05:raise RuntimeError('Blouse correction exceeds 50mm; not saved')
 for v,k in zip(obj.data.vertices,key.data):v.co=k.co
 retain_complete_body(body);mesh.calc_loop_triangles();hits=self_hits(points_of(obj),[tuple(t.vertices) for t in mesh.loop_triangles])
 print('MPFB_UPPER_REGULARIZED',slug,'hits',hits,'max_mm',maximum*1000,flush=True)
 if hits:raise RuntimeError('Trial upper self-crosses; not saved')
bpy.ops.wm.save_as_mainfile(filepath=str(path))
