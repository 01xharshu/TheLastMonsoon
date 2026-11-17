"""Fit an isolated candidate garment to its full MPFB body in rest pose."""
import bpy,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from purpose_cloth_volume import VolumeSurface
from river_coherent_cloth import fit_key
from whole_body_contract import retain_complete_body
args=sys.argv[sys.argv.index('--')+1:]
slug=args[args.index('--identity')+1]
name=args[args.index('--garment')+1]
path=Path(args[args.index('--source')+1]).expanduser().resolve() if '--source' in args else ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='POSE';rig.animation_data_clear()
from mathutils import Matrix
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
for modifier in body.modifiers:
 if modifier.type=='MASK':modifier.show_viewport=False
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();skin=body.evaluated_get(dg);mesh=skin.to_mesh();mesh.calc_loop_triangles()
group=body.vertex_groups['body'].index
human={v.index for v in body.data.vertices if any(g.group==group and g.weight>.5 for g in v.groups)}
points=[skin.matrix_world@v.co for v in mesh.vertices];faces=[tuple(t.vertices) for t in mesh.loop_triangles if all(i in human for i in t.vertices)]
volume=VolumeSurface.FromPolygons(points,faces,all_triangles=True,strict=True)
obj=bpy.data.objects[name]
if not obj.data.shape_keys:obj.shape_key_add(name='Basis')
key=obj.data.shape_keys.key_blocks['Basis']
maximum=fit_key(rig,obj,volume,key,reset_key=False,minimum_clearance_m=.008)
if maximum>.08:raise RuntimeError('Rest fit exceeds 80 mm, candidate not saved')
for v,k in zip(obj.data.vertices,key.data):v.co=k.co
skin.to_mesh_clear();retain_complete_body(body)
bpy.ops.wm.save_as_mainfile(filepath=str(path))
print('INDIAN_CANDIDATE_FIT',slug,name,'max_displacement_mm',maximum*1000,flush=True)
