"""Fit separate candidate fabric over the complete body in sampled poses.

The body is never edited. The explicit source study is updated only after a
bounded correction; independent audits still decide sampled acceptance.
"""
import argparse
from pathlib import Path
import sys
import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from purpose_cloth_volume import VolumeSurface
from river_coherent_cloth import fit_key
from whole_body_contract import retain_complete_body
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--identity',required=True)
parser.add_argument('--source',required=True,type=Path)
parser.add_argument('--garment',required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
source=args.source.expanduser().resolve()
bpy.ops.wm.open_mainfile(filepath=str(source))
bpy.context.preferences.filepaths.save_version=0
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
rig.animation_data_clear();rig.data.pose_position='POSE'
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
if body.get('body_profile')!=args.identity:raise RuntimeError('Mismatched body identity')
for modifier in body.modifiers:
    if modifier.type=='MASK':modifier.show_viewport=False
obj=bpy.data.objects[args.garment]
if obj.get('street_source_only',False):raise RuntimeError('Inactive garment')
if not obj.data.shape_keys:obj.shape_key_add(name='Basis')
key=obj.data.shape_keys.key_blocks['Basis']
original=[v.co.copy() for v in key.data]
group=body.vertex_groups['body'].index
human={v.index for v in body.data.vertices if any(g.group==group and g.weight>.5 for g in v.groups)}
poses=[(0.,0.,False),(-.35,0.,False),(-.175,0.,False),(.175,0.,False),(.35,0.,False),
       (0.,1.,False),(-.175,1.,False),(.175,1.,False),(0.,0.,True),(0.,.7,True),(0.,1.,True)]
for attempt in range(2):
    for swing,lean,carrying in poses:
        for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
        for side,sign in [('l',1),('r',-1)]:
            for prefix in ('thigh_','upperarm_'):
                bone=rig.pose.bones.get(prefix+side)
                if bone:bone.rotation_mode='QUATERNION';bone.rotation_quaternion=Quaternion(Vector((1,0,0)),swing*sign)
            if carrying:
                for prefix,angle in [('upperarm_',-.8),('lowerarm_',-1.)]:
                    bone=rig.pose.bones.get(prefix+side)
                    if bone:
                        axis=bone.bone.matrix_local.to_3x3().inverted()@Vector((1,0,0))
                        bone.rotation_mode='QUATERNION';bone.rotation_quaternion=Quaternion(axis.normalized(),angle)
        for name,angle in [('spine_01',.24),('spine_02',.20)]:
            bone=rig.pose.bones.get(name)
            if bone:
                axis=bone.bone.matrix_local.to_3x3().inverted()@Vector((1,0,0))
                bone.rotation_mode='QUATERNION';bone.rotation_quaternion=Quaternion(axis.normalized(),angle*lean)
        bpy.context.view_layer.update()
        evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh=evaluated.to_mesh();mesh.calc_loop_triangles()
        points=[evaluated.matrix_world@v.co for v in mesh.vertices]
        faces=[tuple(t.vertices) for t in mesh.loop_triangles if all(i in human for i in t.vertices)]
        volume=VolumeSurface.FromPolygons(points,faces,all_triangles=True,strict=True)
        fit_key(rig,obj,volume,key,reset_key=False,minimum_clearance_m=.004)
        evaluated.to_mesh_clear()
        maximum=max((v.co-p).length for v,p in zip(key.data,original))
        if maximum>.04:raise RuntimeError('Multi-pose body fit exceeds40mm; no study saved')
    print('MOTION_BODY_FIT',args.identity,args.garment,attempt,'max_mm',maximum*1000,flush=True)
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
for vertex,fitted in zip(obj.data.vertices,key.data):vertex.co=fitted.co
retain_complete_body(body)
bpy.ops.wm.save_as_mainfile(filepath=str(source))
print('MOTION_BODY_FIT_SAVED',args.identity,args.garment,flush=True)
