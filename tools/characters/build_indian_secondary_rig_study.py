"""Add coherent adult breast/seat skinning to a separate complete MPFB study.

Only weights are transferred from existing parents to equivalent child bones.
The complete body and ordinary posed silhouette must remain unchanged before
any runtime spring motion is enabled. No production assets are replaced.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import bpy
from mathutils import Matrix, Quaternion, Vector
from mathutils.kdtree import KDTree
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--identity',required=True,choices=[f'female_{n:02}' for n in range(1,7)])
p.add_argument('--source',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
args=p.parse_args(sys.argv[sys.argv.index('--')+1:]);source=args.source.resolve();output=args.output.resolve()
if not source.is_file() or output.exists() or source==output:raise ValueError('Requires a separate new study output')
manifest=json.loads((ROOT/'WorkingAssets/NPCs/indian_body_profiles/female_fuller_manifest.json').read_text())
if float(manifest['adult_age'])<.35:raise RuntimeError('Clearly adult source required')
inputs=json.loads((ROOT/'WorkingAssets/NPCs/river_activity/mpfb_adult_breast_profiles.json').read_text())
if hashlib.sha256((ROOT/inputs['donor']).read_bytes()).hexdigest()!=inputs['donor_sha256']:
    raise RuntimeError('Retained MPFB weight donor changed')
bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.preferences.filepaths.save_version=0
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.animation_data_clear();rig.data.pose_position='POSE'
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
if body.get('body_profile')!=args.identity or len(body.data.vertices)!=19158:raise RuntimeError('Mismatched complete MPFB body')
names=['Opaque fitted bra and thong foundation','Street coherent cotton blouse and pallu',
       'Street sari front pallu','Street sari back tail','Wrapped sari lower drape','Sari lower border']
objects=[body]+[bpy.data.objects[name] for name in names if bpy.data.objects.get(name)]
mask_states=[(m,m.show_viewport) for m in body.modifiers if m.type=='MASK']
for modifier,_ in mask_states:modifier.show_viewport=False
poses=[(0.,0.),(-.35,0.),(.35,0.),(0.,1.),(-.175,1.),(.175,1.)]

def pose(swing,lean):
    for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
    for side,sign in [('l',1),('r',-1)]:
        for prefix in ('thigh_','upperarm_'):
            bone=rig.pose.bones.get(prefix+side)
            if bone:bone.rotation_mode='QUATERNION';bone.rotation_quaternion=Quaternion(Vector((1,0,0)),swing*sign)
    for name,angle in [('spine_01',.24),('spine_02',.20)]:
        bone=rig.pose.bones.get(name)
        if bone:
            axis=bone.bone.matrix_local.to_3x3().inverted()@Vector((1,0,0))
            bone.rotation_mode='QUATERNION';bone.rotation_quaternion=Quaternion(axis.normalized(),angle*lean)
    bpy.context.view_layer.update()

def points(obj):
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
    values=[obj.matrix_world@v.co for v in mesh.vertices];evaluated.to_mesh_clear();return values

before=[]
for sample in poses:
    pose(*sample);before.append({obj.name:points(obj) for obj in objects})
pose(0.,0.);rig.data.pose_position='REST';bpy.context.view_layer.update()
rest=points(body);human_group=body.vertex_groups['body'].index
human={v.index for v in body.data.vertices if any(g.group==human_group and g.weight>.5 for g in v.groups)}
parents={'breast_l':'spine_03','breast_r':'spine_03','glute_l':'pelvis','glute_r':'pelvis'}
if any(name in rig.data.bones for name in parents):raise RuntimeError('Study already contains secondary bones')
parent_weights={name:{v.index:next((g.weight for g in v.groups if g.group==body.vertex_groups[name].index),0.) for v in body.data.vertices} for name in set(parents.values())}
fractions={name:{} for name in parents}
for row in inputs['rows']:
    index=int(row[0])
    if index in human:
        fractions['breast_l'][index]=float(row[10]);fractions['breast_r'][index]=float(row[11])
def smooth(a,b,value):
    t=max(0.,min(1.,(value-a)/(b-a)));return t*t*(3.-2.*t)
for index in human:
    point=rest[index]
    rear=(smooth(.64,.71,point.z)*(1-smooth(.86,.94,point.z))*smooth(.025,.075,point.y))
    for side,sign in [('l',1),('r',-1)]:
        lateral=smooth(.015,.055,point.x*sign)*(1-smooth(.14,.205,point.x*sign))
        fractions['glute_'+side][index]=rear*lateral*.85
weights={name:{i:parent_weights[parent][i]*value for i,value in fractions[name].items()} for name,parent in parents.items()}
for name in parents:
    if sum(weights[name].values())<5:raise RuntimeError('Secondary region did not bind enough actual tissue: '+name)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for name,parent_name in parents.items():
    mask=weights[name];total=sum(mask.values());centre=sum((rest[i]*value for i,value in mask.items()),Vector())/total
    parent=rig.data.edit_bones[parent_name];bone=rig.data.edit_bones.new(name)
    bone.parent=parent;bone.use_connect=False;bone.head=rig.matrix_world.inverted()@centre
    bone.tail=bone.head+(parent.tail-parent.head).normalized()*.04;bone.align_roll(parent.z_axis)
bpy.ops.object.mode_set(mode='OBJECT')
tree=KDTree(len(human))
for index in human:tree.insert(rest[index],index)
tree.balance()
for obj in objects:
    for name in parents:obj.vertex_groups.new(name=name)
    coordinates=rest if obj==body else points(obj)
    for vertex in obj.data.vertices:
        if obj==body:
            desired={name:weights[name].get(vertex.index,0.) for name in parents}
        else:
            nearest=tree.find_n(coordinates[vertex.index],3)
            if nearest[0][2]>.08:continue
            multipliers=[1./max(distance,.001)**2 for _,_,distance in nearest];total=sum(multipliers)
            desired={name:sum(weights[name].get(index,0.)*factor for (_,index,_),factor in zip(nearest,multipliers))/total for name in parents}
        for parent_name in set(parents.values()):
            group=obj.vertex_groups.get(parent_name)
            if group is None:continue
            old=next((g.weight for g in vertex.groups if g.group==group.index),0.)
            children=[name for name,parent in parents.items() if parent==parent_name]
            requested=sum(desired[name] for name in children)
            if requested<.000001 or old<.000001:continue
            scale=min(1.,old/requested)
            group.add([vertex.index],max(0.,old-requested*scale),'REPLACE')
            for name in children:
                value=desired[name]*scale
                if value>.000001:obj.vertex_groups[name].add([vertex.index],value,'REPLACE')
    obj.data.update()
rig.data.pose_position='POSE';maximum=0.
for sample,baseline in zip(poses,before):
    pose(*sample)
    for obj in objects:
        after=points(obj)
        if len(after)!=len(baseline[obj.name]):raise RuntimeError('Body or garment topology changed')
        error=max((a-b).length for a,b in zip(after,baseline[obj.name]));maximum=max(maximum,error)
        if error>.000002:raise RuntimeError('Neutral secondary rig altered ordinary deformation: '+obj.name+' '+str(error))
pose(0.,0.)
for modifier,enabled in mask_states:modifier.show_viewport=enabled
body['adult_character']=True;body['adult_secondary_version']=1
profile=next(profile['macro'] for profile in manifest['profiles'] if profile['id']==args.identity)
body['adult_secondary_breast_mass']=.85+.30*(profile['cupsize']-.44)/(.79-.44)
body['adult_secondary_rear_mass']=.85+.30*profile['buttock']/.77
body['adult_secondary_weight_source']=inputs['weight_source']+'; local pelvis seat mask, parent-preserving transfer'
body['approval']='Secondary rig study; no spring/contact/motion or live approval'
output.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(output))
print('ADULT_SECONDARY_RIG_NEUTRAL_PARITY',args.identity,'poses',len(poses),'objects',len(objects),'max_mm',maximum*1000,'complete_body_vertices',len(body.data.vertices),'unapproved',output,flush=True)
