"""Fit a study garment against actual disposable street poses.

Pose matrices must reproduce the exported skin within0.5mm before any change
is saved. Independent re-export/native auditing is required afterward.
"""
import argparse
import json
from pathlib import Path
import sys
import bpy
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from river_cloth_correctives import apply_river_pose
from river_coherent_cloth import fit_key
from purpose_cloth_volume import VolumeSurface
from whole_body_contract import retain_complete_body
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--identity',required=True)
p.add_argument('--source',required=True,type=Path)
p.add_argument('--poses-dir',required=True,type=Path)
p.add_argument('--garment', choices=['Opaque fitted bra and thong foundation', 'Street sari back tail', 'Street coherent cotton blouse and pallu', 'Street sari front pallu', 'Wrapped sari lower drape', 'Sari lower border'], default='Opaque fitted bra and thong foundation')
args=p.parse_args(sys.argv[sys.argv.index('--')+1:])
source=args.source.expanduser().resolve()
if not source.is_relative_to(ROOT/'WorkingAssets/NPCs/indian_body_candidates'):
    raise ValueError('Native fitting is restricted to isolated editable candidate studies')
poses=[json.loads(path.read_text()) for path in sorted(args.poses_dir.glob('surface_*.json'))]
if list(args.poses_dir.glob('realtime_*.json')):
    poses.extend(json.loads(path.read_text()) for path in sorted(args.poses_dir.glob('realtime_*.json')))
expected_count = 21 if list(args.poses_dir.glob('realtime_*.json')) else 17
if args.garment in ['Wrapped sari lower drape', 'Sari lower border']:
    poses=[pose for pose in poses if pose['sample'] in (2002, 2003)]
    expected_count=2
if len(poses)!=expected_count or any(pose.get('role')!=args.identity for pose in poses):
    raise ValueError(f'Expected {expected_count} actual matching street poses')
bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.preferences.filepaths.save_version=0
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
rig.animation_data_clear();rig.data.pose_position='POSE'
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
if body.get('body_profile')!=args.identity:raise RuntimeError('Mismatched source body')
for modifier in body.modifiers:
    if modifier.type=='MASK':modifier.show_viewport=False
obj=bpy.data.objects[args.garment]
if not obj.data.shape_keys:obj.shape_key_add(name='Basis')
key=obj.data.shape_keys.key_blocks['Basis']
# The morph-disabled GLB uses raw mesh coordinates. Some edited panels
# still have an older, divergent Basis in the editable source.
for vertex, point in zip(obj.data.vertices, key.data):
    point.co = vertex.co
obj.data.update()
original=[v.co.copy() for v in key.data]
shape_values = [(block, block.value) for block in obj.data.shape_keys.key_blocks if block != key]
for block, _ in shape_values:
    block.value = 0.0
conversion=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)));inverse=conversion.inverted()
corrections={name:(conversion@Matrix(rest)@inverse).inverted()@rig.data.bones[name].matrix_local
             for name,rest in poses[0]['rest'].items() if name in rig.data.bones}
group=body.vertex_groups['body'].index
human={v.index for v in body.data.vertices if any(g.group==group and g.weight>.5 for g in v.groups)}
for attempt in range(-1,2):
    for pose in poses:
        apply_river_pose(rig,pose['bones'],conversion,corrections)
        evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh();mesh.calc_loop_triangles()
        points=[evaluated.matrix_world@v.co for v in mesh.vertices]
        faces=[tuple(t.vertices) for t in mesh.loop_triangles if all(i in human for i in t.vertices)]
        if attempt==-1:
            native_inverse=Matrix(pose['rig_world']).inverted()
            native=[rig.matrix_world@conversion@native_inverse@Vector(point)
                    for skin in pose['body'] for point in skin['vertices']]
            tree=KDTree(len(native))
            for index,point in enumerate(native):tree.insert(point,index)
            tree.balance()
            parity=max(tree.find(points[index])[2] for index in sorted(human)[::11])
            print('NATIVE_POSE_PARITY',args.identity,pose['sample'],'mm',parity*1000,flush=True)
            if parity>.0005:raise RuntimeError('Actual native body pose was not reproduced; no fit saved')
        if attempt==-1:
            native_cloth=[rig.matrix_world@conversion@Matrix(pose['rig_world']).inverted()@Vector(point)
                          for garment in pose['garments'] if garment['name']==obj.name for point in garment['vertices']]
            if not native_cloth:raise RuntimeError('Native garment vertices required; use --upper-contact')
            cloth_tree=KDTree(len(native_cloth))
            for index,point in enumerate(native_cloth):cloth_tree.insert(point,index)
            cloth_tree.balance()
            cloth_eval=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());cloth_mesh=cloth_eval.to_mesh()
            cloth_parity=max(cloth_tree.find(cloth_eval.matrix_world@v.co)[2] for v in list(cloth_mesh.vertices)[::7])
            cloth_eval.to_mesh_clear()
            print('NATIVE_CLOTH_PARITY',args.identity,pose['sample'],'mm',cloth_parity*1000,flush=True)
            if cloth_parity>.0005:raise RuntimeError('Native garment pose mismatch; no fit saved')
        if attempt == -1:
            evaluated.to_mesh_clear()
            continue
        volume=VolumeSurface.FromPolygons(points,faces,all_triangles=True,strict=True)
        fit_key(rig,obj,volume,key,reset_key=False,minimum_clearance_m=.004)
        evaluated.to_mesh_clear()
        maximum=max((v.co-start).length for v,start in zip(key.data,original))
        if maximum>.035:print('NATIVE_FIT_BOUND',pose['sample'],sorted([(v.co-start).length*1000,index] for index,(v,start) in enumerate(zip(key.data,original)))[-5:],flush=True)
        if maximum>.035:raise RuntimeError('Native garment fit exceeds35mm; no fit saved')
    if attempt >= 0:
        print('NATIVE_GARMENT_FIT',args.identity,attempt,'max_mm',maximum*1000,flush=True)
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
for vertex,fitted in zip(obj.data.vertices,key.data):vertex.co=fitted.co
for block, value in shape_values:
    block.value = value
retain_complete_body(body)
bpy.ops.wm.save_as_mainfile(filepath=str(source))
print('NATIVE_GARMENT_FIT_SAVED',args.identity,'REEXPORT_AND_AUDIT_REQUIRED',flush=True)
