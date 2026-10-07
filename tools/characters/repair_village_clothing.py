"""Fit existing village garments over intact posed MPFB bodies; retain source master.
Run Blender --background --python tools/characters/repair_village_clothing.py -- ROLE.
Correctives are exported as animation weight tracks, so consumers of the original
idle/walk clips receive them without a separate phase clock.
"""
import bpy, sys, json, hashlib
from pathlib import Path
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from village_cloth_fit import _fit_pose
from whole_body_contract import retain_complete_body
role=sys.argv[sys.argv.index('--')+1]
assert role in ['village_farmer','village_woman','village_fruit_seller','village_weaver_assistant']
folder=ROOT/'WorkingAssets/NPCs'/role
source=folder/(role+'_motion_candidate.blend')
bpy.ops.wm.open_mainfile(filepath=str(source))
rig=bpy.data.objects[role+'_rig'];body=bpy.data.objects[role+'_MakeHuman_body']
retain_complete_body(body)
# Bake clothing masks/thickness at rest, preserving the existing surface and weights.
rig.data.pose_position='REST';bpy.context.view_layer.update()
names=['Fitted cotton upper base','Knee length wrapped dhoti','Dhoti woven border',
       'Kurta loose lower panel','Wrapped sari lower drape','Sari lower border',
       'Woven sari pallu over blouse']
objects=[bpy.data.objects[n] for n in names if n in bpy.data.objects]
dg=bpy.context.evaluated_depsgraph_get()
for obj in objects:
    obj.data=bpy.data.meshes.new_from_object(obj.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
    for mod in list(obj.modifiers):
        if mod.type!='ARMATURE':obj.modifiers.remove(mod)
    # Low-resolution wraps need intermediate rows to follow a bent knee.
    if len(obj.data.vertices)<500:
        import bmesh
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.subdivide_edges(bm,edges=list(bm.edges),cuts=2,use_grid_fill=True)
        bm.to_mesh(obj.data);bm.free()
    obj.shape_key_add(name='Basis')
# Garments must share the body deformation, including shoulder/chest weights.
from mathutils.kdtree import KDTree
skin_tree=KDTree(len(body.data.vertices))
for vertex in body.data.vertices:skin_tree.insert(body.matrix_world@vertex.co,vertex.index)
skin_tree.balance()
body_groups={group.index:group.name for group in body.vertex_groups}
for obj in objects:
    if obj.name != 'Fitted cotton upper base':continue
    obj.vertex_groups.clear()
    for vertex in obj.data.vertices:
        weights={}
        for _,index,distance in skin_tree.find_n(obj.matrix_world@vertex.co,3):
            factor=1/max(.005,distance)**2
            for group in body.data.vertices[index].groups:
                name=body_groups[group.group]
                if name in rig.data.bones:weights[name]=weights.get(name,0)+group.weight*factor
        total=sum(weights.values())
        for name,weight in weights.items():
            (obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)).add([vertex.index],weight/total,'REPLACE')
rig.data.pose_position='POSE'
report={'role':role,'source':str(source.relative_to(ROOT)),'garments':{},'body_preserved':True}
# Fit the rest surface first; every sampled corrective starts from this basis.
rig.animation_data.action=None
for bone in rig.pose.bones:bone.matrix_basis.identity()
bpy.context.view_layer.update()
def body_tree():
    dg=bpy.context.evaluated_depsgraph_get();ev=body.evaluated_get(dg);mesh=ev.to_mesh()
    tree=BVHTree.FromPolygons([ev.matrix_world@v.co for v in mesh.vertices],[tuple(p.vertices) for p in mesh.polygons]);ev.to_mesh_clear()
    return tree
for obj in objects:
    _fit_pose(rig,obj,body_tree(),obj.data.shape_keys.key_blocks['Basis'])
    for v in obj.data.vertices:v.co=obj.data.shape_keys.key_blocks['Basis'].data[v.index].co
# 30 Hz samples match the authored runtime actions; include both loop endpoints.
for clip,duration in [('idle',60),('walk',36)]:
    rig.animation_data.action=bpy.data.actions[clip]
    for frame in range(1,duration+2):
        bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();tree=body_tree()
        for obj in objects:
            key=obj.shape_key_add(name=f'{clip} fit {frame:03d}');key.value=1
            _fit_pose(rig,obj,tree,key);key.value=0
        print('VILLAGE_FIT',role,clip,frame,flush=True)
    # Weight curves travel with the matching armature action in glTF.
    for obj in objects:
        keys=obj.data.shape_keys
        keys.animation_data_create()
        action=bpy.data.actions.new(role+'_'+obj.name+'_'+clip)
        keys.animation_data.action=action
        action.use_fake_user=True
        for key in keys.key_blocks:
            if key.name=='Basis':continue
            active=key.name.startswith(clip+' fit ')
            sample=int(key.name.rsplit(' ',1)[1]) if active else -100
            for frame in range(1,duration+2):
                key.value=1.0 if frame==sample else 0.0
                key.keyframe_insert('value',frame=frame,group=key.name)
        # NLA strip names join the cloth curves with the matching rig clip.
        track=keys.animation_data.nla_tracks.new();track.name=clip
        strip=track.strips.new(clip,1,action);strip.action_frame_end=duration+1
        keys.animation_data.action=None
        report['garments'][obj.name]={'vertices':len(obj.data.vertices),'pose_keys':len(keys.key_blocks)-1}
# Rig NLA clips use the same names, keeping two complete synchronized actions.
rig.animation_data.action=None
for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
for clip,duration in [('idle',60),('walk',36)]:
    track=rig.animation_data.nla_tracks.new();track.name=clip
    strip=track.strips.new(clip,1,bpy.data.actions[clip]);strip.action_frame_end=duration+1
# Save a separate editable fitting source; original body and source remain recoverable.
bpy.context.scene.frame_set(1)
fitted=folder/(role+'_clothing_fitted.blend')
bpy.ops.wm.save_as_mainfile(filepath=str(fitted))
# Bake only MPFB helper exclusion on the body. Keep skin and rig weights intact.
rig.data.pose_position='REST';bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
mesh=bpy.data.meshes.new_from_object(body.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
export_body=bpy.data.objects.new(role+'_export_full_body',mesh);bpy.context.scene.collection.objects.link(export_body)
for group in body.vertex_groups:export_body.vertex_groups.new(name=group.name)
export_body.parent=rig;export_body.matrix_parent_inverse=body.matrix_parent_inverse.copy();export_body.matrix_basis=body.matrix_basis.copy()
export_body.modifiers.new('Armature','ARMATURE').object=rig
rig.data.pose_position='POSE'
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in bpy.data.objects:
    if obj.type=='MESH' and obj!=body:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
runtime=ROOT/f'characters/npcs/motion/{role}/{role}_rigged_candidate.glb'
bpy.ops.export_scene.gltf(filepath=str(runtime),export_format='GLB',use_selection=True,
    export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,
    export_frame_range=False,export_skins=True,export_apply=False,export_morph=True,
    export_cameras=False,export_lights=False)
report.update(fitted_source=str(fitted.relative_to(ROOT)),runtime=str(runtime.relative_to(ROOT)),runtime_sha256=hashlib.sha256(runtime.read_bytes()).hexdigest(),status='FITTED_CANDIDATE_REQUIRES_AUDIT_RENDER')
(folder/'clothing_fit_manifest.json').write_text(json.dumps(report,indent=2)+'\n')
