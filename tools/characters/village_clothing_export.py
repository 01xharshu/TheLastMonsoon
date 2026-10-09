import bpy,hashlib,json
from pathlib import Path
def export_fitted(ROOT,role,rig,body,report):
    folder=ROOT/"WorkingAssets/NPCs"/role
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
        export_frame_range=False,export_skins=True,export_all_influences=True,export_apply=False,export_morph=True,
        export_cameras=False,export_lights=False)
    import_settings=runtime.with_suffix(runtime.suffix+'.import')
    if import_settings.exists():
        text=import_settings.read_text().replace('animation/fps=30','animation/fps=60').replace('meshes/force_disable_compression=false','meshes/force_disable_compression=true')
        import_settings.write_text(text)
    report.update(export_all_bone_influences=True, fitted_source=str(fitted.relative_to(ROOT)),fitted_source_sha256=hashlib.sha256(fitted.read_bytes()).hexdigest(),runtime=str(runtime.relative_to(ROOT)),runtime_sha256=hashlib.sha256(runtime.read_bytes()).hexdigest(),status='FITTED_CANDIDATE_REQUIRES_AUDIT_RENDER')
    (folder/'clothing_fit_manifest.json').write_text(json.dumps(report,indent=2)+'\n')
