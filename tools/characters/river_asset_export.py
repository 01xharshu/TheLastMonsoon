"""Save editable river source and export the complete MPFB runtime body."""
import bpy,hashlib,json
from pathlib import Path
def export_river_asset(ROOT,rig,body,foundation_faces):
    OUT=ROOT/"WorkingAssets/NPCs/river_woman"
    source=OUT/'river_woman_motion.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    # Bake helper exclusion and clothing-only masks. The full human body and
    # separate opaque foundation are both exported.
    masked={body}
    depsgraph=bpy.context.evaluated_depsgraph_get()
    for original in masked:
        mesh=bpy.data.meshes.new_from_object(original.evaluated_get(depsgraph),preserve_all_data_layers=True,depsgraph=depsgraph)
        cutout=bpy.data.objects.new(original.name+'_export_cutout',mesh);bpy.context.collection.objects.link(cutout)
        for group in original.vertex_groups:cutout.vertex_groups.new(name=group.name)
        cutout.parent=rig;cutout.matrix_parent_inverse=original.matrix_parent_inverse.copy();cutout.matrix_basis=original.matrix_basis.copy()
        cutout.modifiers.new('Armature deformation','ARMATURE').object=rig
    rig.data.pose_position='POSE';rig.animation_data_create();rig.animation_data.action=bpy.data.actions.get('idle');bpy.context.scene.frame_set(1)
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
    for obj in bpy.data.objects:
        if obj.type=='MESH' and obj not in masked :obj.select_set(True)
    bpy.context.view_layer.objects.active=rig
    runtime=ROOT/'characters/npcs/motion/river_woman/river_woman_rigged_candidate.glb'
    runtime.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(runtime),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,export_cameras=False,export_lights=False,export_yup=True,export_skins=True,export_all_influences=True,export_apply=False,export_morph_normal=False,export_morph_tangent=False)
    report=dict(status='RIVER_ROUTINE_RUNTIME',source=str(source.relative_to(ROOT)),runtime=str(runtime.relative_to(ROOT)),source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),runtime_sha256=hashlib.sha256(runtime.read_bytes()).hexdigest(),foundation_faces=foundation_faces,donor='village_woman_motion_candidate.blend',visual_approved=False,motion_approved=False,in_world=True,corrective_samples=max((len(obj.data.shape_keys.key_blocks)-1 for obj in bpy.data.objects if obj.type=="MESH" and obj.data.shape_keys and obj.name!=body.name),default=0),foundation_in_runtime=True)
    (OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    print('RIVER_SOURCE',json.dumps(report))
