"""Trial seam-aware cloth-only self-intersection repair on an isolated candidate."""
import bpy,sys
from pathlib import Path
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from river_upper_self_fit import regularize_upper
from purpose_cloth_volume import VolumeSurface
from whole_body_contract import retain_complete_body
args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1];path=Path(args[args.index('--source')+1]).expanduser().resolve() if '--source' in args else ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.animation_data_clear();rig.data.pose_position='POSE'
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
for m in body.modifiers:
 if m.type=='MASK':m.show_viewport=False
bpy.context.view_layer.update();ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh();mesh.calc_loop_triangles();group=body.vertex_groups['body'].index
human={v.index for v in body.data.vertices if any(g.group==group and g.weight>.5 for g in v.groups)}
points=[ev.matrix_world@v.co for v in mesh.vertices];faces=[tuple(t.vertices) for t in mesh.loop_triangles if all(i in human for i in t.vertices)];tree=VolumeSurface.FromPolygons(points,faces,all_triangles=True,strict=True);ev.to_mesh_clear()
name=args[args.index('--garment')+1] if '--garment' in args else 'Street coherent cotton blouse and pallu'
obj=bpy.data.objects[name]
if not obj.data.shape_keys:obj.shape_key_add(name='Basis')
key=obj.data.shape_keys.key_blocks['Basis'];initial=[p.co.copy() for p in key.data]
passes=regularize_upper(rig,obj,tree,key);maximum=max((p.co-q).length for p,q in zip(key.data,initial))
if maximum>.05:raise RuntimeError('Cloth correction exceeds 50mm; candidate not saved')
if passes or maximum>.000001:
 backup=obj.copy();backup.data=obj.data.copy();backup.name='Candidate upper before self repair';backup['street_source_only']=True;backup.hide_render=True;bpy.context.collection.objects.link(backup);backup.hide_set(True)
 for v,k in zip(obj.data.vertices,key.data):v.co=k.co
 retain_complete_body(body);bpy.ops.wm.save_as_mainfile(filepath=str(path));
print('SELF_CLOTH_REPAIR',slug,'passes',passes,'max_mm',maximum*1000,flush=True)
