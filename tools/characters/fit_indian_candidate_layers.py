"""Try bounded exact outer/inner garment separation in an isolated candidate."""
import bpy,sys
from pathlib import Path
from mathutils import Matrix
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from river_layer_fit import separate_layers
args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
outer_name=args[args.index('--outer')+1];inner_name=args[args.index('--inner')+1]
path=Path(args[args.index('--source')+1]).expanduser().resolve() if '--source' in args else ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.animation_data_clear();rig.data.pose_position='POSE'
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update();inner=bpy.data.objects[inner_name];ev=inner.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh();mesh.calc_loop_triangles()
points=[ev.matrix_world@v.co for v in mesh.vertices];faces=[tuple(t.vertices) for t in mesh.loop_triangles];ev.to_mesh_clear()
tree=BVHTree.FromPolygons(points,faces,all_triangles=True);outer=bpy.data.objects[outer_name]
if not outer.data.shape_keys:outer.shape_key_add(name='Basis')
key=outer.data.shape_keys.key_blocks['Basis'];old=[v.co.copy() for v in key.data]
steps=separate_layers(rig,outer,key,points,faces,tree,gap=.006,reserve_margin=False)
maximum=max((a.co-b).length for a,b in zip(key.data,old))
if maximum>.06:raise RuntimeError('Layer correction exceeds 60 mm; candidate not saved')
for v,k in zip(outer.data.vertices,key.data):v.co=k.co
bpy.ops.wm.save_as_mainfile(filepath=str(path));print('INDIAN_LAYER_FIT',slug,outer_name,'iterations',steps,'max_mm',maximum*1000,flush=True)
