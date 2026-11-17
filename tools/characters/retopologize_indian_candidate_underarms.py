"""Trial local cloth underarm retriangulation; body and original fabric retained."""
import bpy,bmesh,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from river_upper_self_fit import self_hits,points_of,regularize_upper
from street_female_garments import body_volume
from whole_body_contract import retain_complete_body
from mathutils import Matrix
args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
wide='--wide' in args
path=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend';bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
obj=bpy.data.objects['Street coherent cotton blouse and pallu'];old=obj.copy();old.data=obj.data.copy();old.name='Retained upper before underarm retopology';old['street_source_only']=True;old.hide_render=True;bpy.context.collection.objects.link(old);old.hide_set(True)
if obj.data.shape_keys:
 fitted=[v.co.copy() for v in obj.data.shape_keys.key_blocks['Basis'].data];obj.shape_key_clear()
 for v,p in zip(obj.data.vertices,fitted):v.co=p
bm=bmesh.new();bm.from_mesh(obj.data);selected=[]
for f in bm.faces:
 p=obj.matrix_world@f.calc_center_median()
 if (1.00<p.z<1.20 and .10<abs(p.x)<.23) if wide else (1.04<p.z<1.18 and .12<abs(p.x)<.21):selected.append(f)
if len(selected)<20:raise RuntimeError('Underarm region too small')
result=bmesh.ops.dissolve_faces(bm,faces=selected,use_verts=True)
regions=[f for f in result['region'] if isinstance(f,bmesh.types.BMFace) and f.is_valid]
if not regions:raise RuntimeError('No retriangulation regions')
bmesh.ops.triangulate(bm,faces=regions,quad_method='BEAUTY',ngon_method='BEAUTY');bm.normal_update();bm.to_mesh(obj.data);bm.free();obj.data.update()
obj.data.calc_loop_triangles();faces=[tuple(t.vertices) for t in obj.data.loop_triangles];hits=self_hits(points_of(obj),faces)
print('UNDERARM_RETOPOLOGY',slug,'selected',len(selected),'remaining_self_hits',hits,flush=True)
if hits:
 rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.animation_data_clear();rig.data.pose_position='POSE'
 for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
 body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
 for mod in body.modifiers:
  if mod.type=='MASK':mod.show_viewport=False
 bpy.context.view_layer.update();tree=body_volume(body);key=obj.shape_key_add(name='Basis')
 original=[v.co.copy() for v in key.data];regularize_upper(rig,obj,tree,key)
 maximum=max((v.co-p).length for v,p in zip(key.data,original))
 if maximum>.05:raise RuntimeError('Regularization exceeds 50mm; not saved')
 for v,k in zip(obj.data.vertices,key.data):v.co=k.co
 retain_complete_body(body)
 obj.data.calc_loop_triangles();faces=[tuple(t.vertices) for t in obj.data.loop_triangles];hits=self_hits(points_of(obj),faces)
 print('UNDERARM_REGULARIZED',slug,'hits',hits,'max_mm',maximum*1000,flush=True)
 if hits:raise RuntimeError('Retopology still self-crosses; candidate not saved')
bpy.ops.wm.save_as_mainfile(filepath=str(path))
