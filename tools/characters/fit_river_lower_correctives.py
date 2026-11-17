"""Fit authored lower-wrap poses over the complete MPFB volume in a new source.

Consumes exact retained Godot drape inputs, never changes the completed base or
donor, and checkpoints the editable derivative. Diagnostics belong in OS temp.
"""
import bpy, hashlib, json, sys
from pathlib import Path
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from river_cloth_correctives import apply_river_pose
from river_surface_binding import inverse_skin
from river_coherent_cloth import fit_key
from purpose_cloth_volume import VolumeSurface
from river_layer_fit import separate_layers

OUT=ROOT/'WorkingAssets/NPCs/river_activity'
BASE=OUT/'river_activity.blend'
SOURCE=OUT/'river_activity_draped.blend'
CHECKPOINT=OUT/'lower_fit_checkpoint.json'
POSES=OUT/'poses.json'
ALGORITHM='stand_skin_clearance_v8'
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
if (OUT/'fit_checkpoint.json').exists():raise RuntimeError('Complete the base fit first')
data=json.loads(POSES.read_text());pose_hash=digest(POSES);base_hash=digest(BASE)
start=0
if CHECKPOINT.exists():
    progress=json.loads(CHECKPOINT.read_text())
    if progress.get('algorithm')!=ALGORITHM or progress['base_sha256']!=base_hash or progress['pose_sha256']!=pose_hash or progress['source_sha256']!=digest(SOURCE):
        raise RuntimeError('Lower-fit checkpoint source or input mismatch')
    start=progress['next_sample']
bpy.ops.wm.open_mainfile(filepath=str(SOURCE if start else BASE))
bpy.context.preferences.filepaths.save_version=0
from river_cotton_finish import finish_upper
finish_upper(bpy.data.objects['Fitted cotton upper base'])
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
original=[tuple(v.co) for v in body.data.vertices]
objects=[bpy.data.objects[name] for name in ['Wrapped sari lower drape','Sari lower border']]
inner=[bpy.data.objects[name] for name in ['Opaque fitted bra and thong foundation','Fitted cotton upper base']]
# Use the same official MPFB fuller displacement as the final builder when
# constructing the shared wrap; all profiles keep their actual body physique.
profile=json.loads((OUT/'mpfb_adult_breast_profiles.json').read_text())
profile_tree=KDTree(len(profile['rows']))
for i,row in enumerate(profile['rows']):profile_tree.insert(Vector(row[1:4]),i)
profile_tree.balance();profile_bindings={}
for v in body.data.vertices:
    _,i,distance=profile_tree.find(body.matrix_world@v.co)
    if distance<.00002:profile_bindings[v.index]=profile['rows'][i]
profile_key='Fit fuller envelope'
for obj in inner:
    key=obj.data.shape_keys.key_blocks.get(profile_key) or obj.shape_key_add(name=profile_key)
    inverse=obj.matrix_world.to_3x3().inverted()
    for i,binding in enumerate(obj['body_vertex_bindings']):
        key.data[i].co=obj.data.shape_keys.reference_key.data[i].co
        if binding in profile_bindings:key.data[i].co+=inverse@Vector(profile_bindings[binding][7:10])

for obj in objects:
    if not obj.data.shape_keys:obj.shape_key_add(name='Basis')
for obj in bpy.data.objects:
    if obj.type=='MESH' and obj.data.shape_keys:
        for key in obj.data.shape_keys.key_blocks:key.value=0
if rig.animation_data:
    rig.animation_data.action=None
    for track in rig.animation_data.nla_tracks:track.mute=True
rig.data.pose_position='POSE'
c=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
corrections={name:(c@Matrix(rest)@c.inverted()).inverted()@rig.data.bones[name].matrix_local for name,rest in data['rest'].items() if name in rig.data.bones}
def save(next_sample):
    assert original==[tuple(v.co) for v in body.data.vertices]
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    CHECKPOINT.write_text(json.dumps({'algorithm':ALGORITHM,'next_sample':next_sample,'total':len(data['poses']),'base_sha256':base_hash,'pose_sha256':pose_hash,'source_sha256':digest(SOURCE)},indent=2)+'\n')
print('RIVER_LOWER_START',start,len(data['poses']),flush=True)
for sample,pose in enumerate(data['poses']):
    if sample<start:continue
    if set(pose.get('drape',{}))!={o.name for o in objects}:raise RuntimeError('Missing complete authored drape inputs')
    apply_river_pose(rig,pose['bones'],c,corrections);bpy.context.view_layer.update()
    ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh();mesh.calc_loop_triangles()
    points=[ev.matrix_world@v.co for v in mesh.vertices];faces=[tuple(t.vertices) for t in mesh.loop_triangles]
    ev.to_mesh_clear();tree=VolumeSurface.FromPolygons(points,faces,all_triangles=True,strict=False)
    inner_points=[];inner_faces=[];clearance_trees=[]
    for obj in inner:
        for key in obj.data.shape_keys.key_blocks:key.value=1.0 if key.name==pose['key'] else 0.0
        for amount in [0.0,1.0]:
            obj.data.shape_keys.key_blocks[profile_key].value=amount
            bpy.context.view_layer.update()
            ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh();mesh.calc_loop_triangles()
            local_points=[ev.matrix_world@v.co for v in mesh.vertices]
            local_faces=[tuple(t.vertices) for t in mesh.loop_triangles]
            clearance_trees.append(BVHTree.FromPolygons(local_points,local_faces,all_triangles=True))
            offset=len(inner_points);inner_points.extend(local_points)
            inner_faces.extend(tuple(offset+i for i in face) for face in local_faces);ev.to_mesh_clear()
        obj.data.shape_keys.key_blocks[profile_key].value=0
    support=BVHTree.FromPolygons(inner_points,inner_faces,all_triangles=True)
    maximum=0.0
    for obj in objects:
        for key in obj.data.shape_keys.key_blocks:key.value=0
        key=obj.data.shape_keys.key_blocks.get(pose['key']) or obj.shape_key_add(name=pose['key'])
        key.value=1.0
        transforms=inverse_skin(rig,obj);rows=pose['drape'][obj.name]
        if len(rows)!=len(key.data):raise RuntimeError('Drape topology changed')
        # The runtime owner is in actor space; the retained source figure faces
        # the opposite way. A half-ring permutation preserves source UV seams.
        for index in range(len(key.data)):
            row,segment=divmod(index,40)
            key.data[index].co=transforms[index]@(c@Vector(rows[row*40+(segment+20)%40]))
        if obj==objects[1]:
            # Sew the border along the fitted hem surface. A vertical cylinder
            # at the hem radius cuts through a sloping or pleated lower wrap.
            last=len(fitted_lower)-40;above=last-40
            for index in range(len(key.data)):
                row,segment=divmod(index,40)
                bottom=fitted_lower[last+segment];up=fitted_lower[above+segment]-bottom
                across=fitted_lower[last+(segment+1)%40]-fitted_lower[last+(segment-1)%40]
                normal=up.cross(across).normalized()
                fraction=min(1.0,.030/max(.001,up.length))*(1.0-row/2.0)
                key.data[index].co=transforms[index]@(bottom+up*fraction+normal*.0035)
        bpy.context.view_layer.update()
        ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
        before=[ev.matrix_world@v.co for v in mesh.vertices];ev.to_mesh_clear()
        if obj==objects[0]:
            fit_key(rig,obj,tree,key,reset_key=False,foundation=support,minimum_clearance_m=.010 if 48.0<pose["time"]<51.0 and pose["key"].startswith("River cloth ") else .004,jacobi=True)
            separate_layers(rig,obj,key,inner_points,inner_faces,support,clearance_trees=clearance_trees)
            if 48.0<pose["time"]<51.0 and pose["key"].startswith("River cloth "):
                skin=BVHTree.FromPolygons(points,faces,all_triangles=True)
                separate_layers(rig,obj,key,points,faces,skin,gap=.006,reserve_margin=False)
        bpy.context.view_layer.update()
        ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
        fitted=[ev.matrix_world@v.co for v in mesh.vertices]
        shift=max((point-original).length for point,original in zip(fitted,before));ev.to_mesh_clear()
        if obj==objects[0]:fitted_lower=fitted
        if shift>.16:raise RuntimeError('Lower-wrap correction exceeds 16cm construction bound: '+str(shift))
        maximum=max(maximum,shift);key.value=0
    print('RIVER_LOWER_FIT',sample+1,len(data['poses']),maximum,flush=True)
    if (sample+1)%8==0:save(sample+1)
save(len(data['poses']))
for obj in bpy.data.objects:
    if obj.type=='MESH' and obj.data.shape_keys:
        for key in obj.data.shape_keys.key_blocks:key.value=0
for obj in inner:obj.shape_key_remove(obj.data.shape_keys.key_blocks[profile_key])
rig.data.pose_position='REST'
if rig.animation_data:
    for track in rig.animation_data.nla_tracks:track.mute=False
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
(OUT/'lower_fit_manifest.json').write_text(json.dumps({'algorithm':ALGORITHM,'complete':True,'source':str(SOURCE.relative_to(ROOT)),'source_sha256':digest(SOURCE),'base_sha256':base_hash,'pose_sha256':pose_hash,'samples':len(data['poses']),'complete_body_unchanged':True,'visual_approved':False},indent=2)+'\n')
CHECKPOINT.unlink();print('RIVER_LOWER_COMPLETE',flush=True)
