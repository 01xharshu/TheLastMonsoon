"""Checkpointed pose fitting for the isolated river garment construction study.

Does not touch the original MPFB body, original river source or production export.
"""
import bpy,json,sys,hashlib,os
from pathlib import Path
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from river_cloth_correctives import apply_river_pose
from river_coherent_cloth import fit_key
from river_surface_binding import inverse_skin
from purpose_cloth_volume import VolumeSurface
from river_upper_self_fit import regularize_upper
OUT=ROOT/'WorkingAssets/NPCs/river_activity'
SOURCE=OUT/'river_activity.blend'
CHECKPOINT=OUT/'fit_checkpoint.json'
POSES=OUT/'poses.json' if (OUT/'poses.json').exists() else ROOT/'WorkingAssets/NPCs/river_woman/poses.json'
pose_digest=hashlib.sha256(POSES.read_bytes()).hexdigest()
data=json.loads(POSES.read_text())
def sample_hash(pose):
    geometry={name:pose[name] for name in ['key','bones','time','slope'] if name in pose}
    return hashlib.sha256(json.dumps(geometry,sort_keys=True,separators=(',',':')).encode()).hexdigest()
sample_digests=[sample_hash(pose) for pose in data['poses']]
walk_refit=os.environ.get('TLM_RIVER_FOUNDATION_WALK_REFIT')=='1'
algorithm='walk_foundation_local_v2' if walk_refit else 'cropped_body_v8'
walk_buffer_keys={'River fine walk 8 %02d'%frame for frame in range(44,48)}
bpy.ops.wm.open_mainfile(filepath=str(SOURCE));bpy.context.preferences.filepaths.save_version=0
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
unchanged=[tuple(v.co) for v in body.data.vertices]
objects=[bpy.data.objects[name] for name in ['Opaque fitted bra and thong foundation','Fitted cotton upper base']]
c=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)));inverse=c.inverted()
corrections={name:(c@Matrix(rest)@inverse).inverted()@rig.data.bones[name].matrix_local for name,rest in data['rest'].items() if name in rig.data.bones}
start=0
accepted_samples={}
if CHECKPOINT.exists():
    checkpoint=json.loads(CHECKPOINT.read_text())
    if checkpoint['source_sha256']!=hashlib.sha256(SOURCE.read_bytes()).hexdigest():raise RuntimeError('Fit checkpoint/source mismatch')
    if checkpoint.get('algorithm')==algorithm:
        accepted_samples=checkpoint.get('completed_pose_sha256',{})
        if checkpoint.get('pose_sha256')==pose_digest:start=checkpoint['next_sample']
        else:
            previous=checkpoint.get('sample_sha256',[])
            for index in range(min(int(checkpoint['next_sample']),len(previous),len(sample_digests))):
                if previous[index]!=sample_digests[index]:break
                start=index+1
    print('RIVER_ACTIVITY_FIT_RESUME',start,flush=True)
animation=rig.animation_data
if animation:
    animation.action=None
    for track in animation.nla_tracks:track.mute=True
rig.data.pose_position='POSE'
for obj in objects:
    if not obj.data.shape_keys:obj.shape_key_add(name='Basis')
    for key in obj.data.shape_keys.key_blocks:key.value=0
for key in body.data.shape_keys.key_blocks:key.value=0
def save(next_sample):
    assert unchanged==[tuple(v.co) for v in body.data.vertices]
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    CHECKPOINT.write_text(json.dumps(dict(next_sample=next_sample,total=len(data['poses']),algorithm=algorithm,pose_sha256=pose_digest,sample_sha256=sample_digests,completed_pose_sha256=accepted_samples,source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),objective='pose-specific cloth corrections over unchanged complete MPFB body'),indent=2)+'\n')
# The builder transfers the repaired canonical body weights to the fabric.
# Preserve its spine/pelvis blend rather than overriding the waistband to a
# rigid pelvis attachment, which separates it from the bending waist.
for sample,pose in enumerate(data['poses']):
    if sample<start:continue
    if not walk_refit and accepted_samples.get(pose['key'])==sample_digests[sample]:continue
    if walk_refit and pose['key'] not in walk_buffer_keys:continue
    apply_river_pose(rig,pose['bones'],c,corrections)
    for key in body.data.shape_keys.key_blocks:key.value=float(pose.get('body_weights',{}).get(key.name,0.0))
    bpy.context.view_layer.update()
    ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh();mesh.calc_loop_triangles()
    vertices=[ev.matrix_world@v.co for v in mesh.vertices]
    normals=[(ev.matrix_world.to_3x3().inverted().transposed()@v.normal).normalized() for v in mesh.vertices]
    faces=[tuple(t.vertices) for t in mesh.loop_triangles]
    ev.to_mesh_clear()
    # Use six agreeing oriented rays for the many fitting trial points;
    # ambiguous folds still use exact solid angles. Acceptance remains strict.
    tree=VolumeSurface.FromPolygons(vertices,faces,all_triangles=True,strict=False)
    maximum=0.0
    for obj in (objects[:1] if walk_refit else objects):
        for key in obj.data.shape_keys.key_blocks:key.value=0
        key=obj.data.shape_keys.key_blocks.get(pose['key']) or obj.shape_key_add(name=pose['key'])
        for point,basis_point in zip(key.data,obj.data.shape_keys.key_blocks['Basis'].data):point.co=basis_point.co
        key.value=1
        bpy.context.view_layer.update()
        ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());before_mesh=ev.to_mesh()
        before=[ev.matrix_world@v.co for v in before_mesh.vertices];ev.to_mesh_clear()
        # A coherent upper surface uses a body-relative fabric envelope rather
        # than competing rays against an open foundation panel. The thin
        # foundation keeps its own closer body envelope; audit both afterwards.
        # Offset along the ACTUAL deformed skin normal, not the linearly
        # blended rest normal that flips into the waist/chest during flexion.
        transforms=inverse_skin(rig,obj)
        for index,binding in enumerate(obj['body_vertex_bindings']):
            gap=float(obj['body_clearance_m'])
            if obj==objects[0] and pose['key'] in walk_buffer_keys and .80<body.data.vertices[binding].co.z<.84:gap+=.004
            target=vertices[binding]+normals[binding]*gap
            key.data[index].co=transforms[index]@target
        print("RIVER_ACTIVITY_SOLVE",sample,pose["key"],obj.name,flush=True)
        accumulated=fit_key(rig,obj,tree,key,reset_key=False,foundation=None,minimum_clearance_m=.002 if obj==objects[0] else .008,jacobi=True)
        if obj==objects[1]:regularize_upper(rig,obj,tree,key)
        bpy.context.view_layer.update()
        ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());after_mesh=ev.to_mesh()
        delta=max(((ev.matrix_world@v.co)-point).length for v,point in zip(after_mesh.vertices,before));ev.to_mesh_clear()
        rest_delta=max((v.co-original.co).length for v,original in zip(key.data,obj.data.shape_keys.key_blocks['Basis'].data))
        print('RIVER_ACTIVITY_GARMENT sample='+str(sample)+' name='+obj.name+' net_m='+str(delta)+' rest_m='+str(rest_delta)+' path_m='+str(accumulated),flush=True)
        if rest_delta>.16:raise RuntimeError('Rest-space correction exceeded16cm; ill-conditioned construction rejected')
        if delta>(.08 if obj==objects[0] else .12):
            worst=max(range(len(before)),key=lambda i:(key.data[i].co-obj.data.shape_keys.key_blocks['Basis'].data[i].co).length)
            print('RIVER_ACTIVITY_REJECT_REGION',obj.name,'basis',tuple(obj.data.shape_keys.key_blocks['Basis'].data[worst].co),'weights',[(obj.vertex_groups[g.group].name,g.weight) for g in obj.data.vertices[worst].groups],flush=True)
            raise RuntimeError('Bounded garment construction rejected '+obj.name+' '+pose['key']+' displacement='+str(delta))
        maximum=max(maximum,delta)
    accepted_samples[pose['key']]=sample_digests[sample]
    print('RIVER_ACTIVITY_FIT sample='+str(sample+1)+'/'+str(len(data['poses']))+' max_m='+str(maximum),flush=True)
    if (sample+1)%8==0:save(sample+1)
save(len(data['poses']))
for key in body.data.shape_keys.key_blocks:key.value=0
for obj in objects:
    for key in obj.data.shape_keys.key_blocks:key.value=0
if animation:
    for track in animation.nla_tracks:track.mute=False
rig.data.pose_position='REST'
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in bpy.data.objects:
    if obj.type=='MESH' and not obj.get('activity_source_only',False):obj.select_set(True)
rig.data.pose_position='POSE';bpy.context.view_layer.objects.active=rig
rig.animation_data_create();rig.animation_data.action=bpy.data.actions.get('idle');bpy.context.scene.frame_set(1)
runtime=ROOT/'characters/npcs/activity_people/river_activity.glb'
bpy.ops.export_scene.gltf(filepath=str(runtime),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,export_cameras=False,export_lights=False,export_yup=True,export_skins=True,export_all_influences=True,export_apply=False,export_morph_normal=False,export_morph_tangent=False,export_vertex_color='ACTIVE')
report=json.loads((OUT/'manifest.json').read_text());report.update(corrective_samples=len(data['poses']),pose_source=str(POSES.relative_to(ROOT)),pose_sha256=pose_digest,requires_refined_work_motion=bool(data.get('refined_work_motion',False)),source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),runtime_sha256=hashlib.sha256(runtime.read_bytes()).hexdigest(),visual_approved=False,walking_foundation_waist_clearance_m=.007)
(OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n');CHECKPOINT.unlink()
print('RIVER_ACTIVITY_FIT_COMPLETE',flush=True)
