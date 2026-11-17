"""Settle existing MPFB-derived cotton fabric over the complete adult body.

This is a separate cloth construction study, not a new human or production
export. Editable pre-settle fabric remains recoverable; runtime fitting and
visual approval are independent subsequent gates.
"""
import argparse
from pathlib import Path
import sys
import bpy
import bmesh
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--source',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
p.add_argument('--frames',type=int,default=40)
args=p.parse_args(sys.argv[sys.argv.index('--')+1:]);source=args.source.resolve();output=args.output.resolve()
if not source.is_file() or output.exists() or source==output or not 16<=args.frames<=80:
    raise ValueError('Requires separate new output and16–80settlingframes')
bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.preferences.filepaths.save_version=0
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='REST'
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
upper=bpy.data.objects['Street coherent cotton blouse and pallu']
bpy.context.view_layer.update()
evaluated=upper.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
rest=[v.co.copy() for v in mesh.vertices];evaluated.to_mesh_clear()
if len(rest)!=len(upper.data.vertices):raise RuntimeError('Unexpected cloth topology evaluation')
backup=upper.copy();backup.data=upper.data.copy();backup.name='Retained blouse before physical settling'
backup['street_source_only']=True;backup.hide_render=True;bpy.context.collection.objects.link(backup);backup.hide_set(True)
upper.shape_key_clear()
for vertex,point in zip(upper.data.vertices,rest):vertex.co=point
# UV seams can contain coincident but disconnected construction vertices.
# Weld only2micrometre duplicates on the fabric, retaining UV loop seams.
bm=bmesh.new();bm.from_mesh(upper.data);before=len(bm.verts)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000002)
bm.to_mesh(upper.data);bm.free();upper.data.update()
rest=[v.co.copy() for v in upper.data.vertices]
weights=[{g.group:g.weight for g in v.groups} for v in upper.data.vertices]
group_names=[g.name for g in upper.vertex_groups]
print('COTTON_CONSTRUCTION_WELD',before,len(rest),flush=True)
pins=upper.vertex_groups.new(name='Study shoulder anchors');anchors=[]
for vertex in upper.data.vertices:
    point=upper.matrix_world@vertex.co
    if (point.z>1.22 and abs(point.x)<.18) or (point.z<1.045 and abs(point.x)<.18):
        pins.add([vertex.index],1.0,'REPLACE');anchors.append(vertex.index)
if len(anchors)<4:raise RuntimeError('Insufficient shoulder anchors')
colliders=[]
for obj in [body,bpy.data.objects['Opaque fitted bra and thong foundation']]:
    modifier=obj.modifiers.new('Temporary cloth construction support','COLLISION');colliders.append((obj,modifier))
    obj.collision.thickness_outer=.003;obj.collision.cloth_friction=5.0
cloth=upper.modifiers.new('Cotton construction settling','CLOTH')
settings=cloth.settings;settings.quality=12;settings.mass=.005
settings.tension_stiffness=40.;settings.compression_stiffness=40.;settings.shear_stiffness=20.
settings.bending_stiffness=.5;settings.air_damping=5.
settings.vertex_group_mass=pins.name;settings.pin_stiffness=1.0
cloth.collision_settings.use_collision=True;cloth.collision_settings.distance_min=.003
cloth.collision_settings.collision_quality=4
cloth.collision_settings.use_self_collision=True;cloth.collision_settings.self_distance_min=.003
cloth.point_cache.use_disk_cache=False;cloth.point_cache.frame_start=1;cloth.point_cache.frame_end=args.frames
scene=bpy.context.scene;scene.frame_start=1;scene.frame_end=args.frames
for frame in range(1,args.frames+1):
    scene.frame_set(frame);bpy.context.view_layer.update()
    if frame%10==0:print('COTTON_SETTLE_FRAME',frame,flush=True)
evaluated=upper.evaluated_get(bpy.context.evaluated_depsgraph_get())
mesh=bpy.data.meshes.new_from_object(evaluated,preserve_all_data_layers=True,depsgraph=bpy.context.evaluated_depsgraph_get())
if len(mesh.vertices)!=len(rest):raise RuntimeError('Settled fabric changed source vertex correspondence')
maximum=max((v.co-point).length for v,point in zip(mesh.vertices,rest))
print('COTTON_SETTLE_DISPLACEMENT_MM',maximum*1000,flush=True)
for index in sorted(range(len(rest)),key=lambda i:(mesh.vertices[i].co-rest[i]).length)[-3:]:
    print('COTTON_LARGEST_SHIFT',index,tuple(rest[index]),tuple(mesh.vertices[index].co),flush=True)
if maximum>.08:raise RuntimeError('Settling exceeded80mm; no study saved')
upper.modifiers.remove(cloth)
for obj,modifier in colliders:obj.modifiers.remove(modifier)
upper.data=mesh;upper.vertex_groups.clear()
for name in group_names:upper.vertex_groups.new(name=name)
for index,groups in enumerate(weights):
    for group,weight in groups.items():upper.vertex_groups[group].add([index],weight,'REPLACE')
scene.frame_set(1)
upper['cloth_construction']='MPFB-derived cotton; shoulder anchored, body/foundation collision, settled40frames; unapproved'
output.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(output))
print('COTTON_SETTLE_STUDY','anchors',len(anchors),'max_mm',maximum*1000,'unapproved',output,flush=True)
