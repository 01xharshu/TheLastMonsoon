"""Rebuild upper-cloth pose attachments over the unchanged canonical MPFB body."""
import bpy,json,sys
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from river_surface_binding import bind_surface
from river_cloth_correctives import fit_river_cloth
from river_asset_export import export_river_asset,asset_digest
folder=ROOT/'WorkingAssets/NPCs/river_woman';source=folder/'river_woman_motion.blend'
checkpoint=folder/'upper_rebind_checkpoint.json'
state=json.loads(checkpoint.read_text()) if checkpoint.exists() else {}
if state and asset_digest(source)!=state['source_sha256']:raise RuntimeError('Upper rebind checkpoint differs from source')
bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.preferences.filepaths.save_version=0
rig=bpy.data.objects['village_woman_rig'];body=bpy.data.objects['village_woman_MakeHuman_body']
from river_body_physique import restore_donor_physique
restore_donor_physique(ROOT,body)
upper=bpy.data.objects['Fitted cotton upper base'];rig.animation_data_clear();rig.data.pose_position='REST'
foundation=bpy.data.objects['Opaque fitted bra and thong foundation']
objects=[foundation,upper]
for obj in objects:
    for key in obj.data.shape_keys.key_blocks:key.value=0
if not state:
    if bpy.data.objects.get('Retained seam-fitted river upper') is None:
        reference=upper.copy();reference.data=upper.data.copy();reference.name='Retained seam-fitted river upper'
        bpy.context.collection.objects.link(reference);reference['river_source_only']=True
        reference.hide_set(True);reference.hide_render=True
    masks=[(modifier,modifier.show_viewport) for modifier in body.modifiers if modifier.type=='MASK']
    for modifier,_ in masks:modifier.show_viewport=False
    bpy.context.view_layer.update();ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
    try:
        if len(mesh.vertices)!=len(body.data.vertices):raise RuntimeError('Canonical body source vertex indexing changed')
        group=body.vertex_groups['body'].index
        human={vertex.index for vertex in body.data.vertices if any(weight.group==group and weight.weight>.5 for weight in vertex.groups)}
        for obj in objects:bind_surface(obj,body,mesh,human)
        print('RIVER_UPPER_REBIND_INDEXING',len(mesh.vertices),'human_vertices',len(human),flush=True)
    finally:
        ev.to_mesh_clear()
        for modifier,enabled in masks:modifier.show_viewport=enabled
        bpy.context.view_layer.update()
    bindings=json.loads(upper['river_surface_bindings'])
    for binding in bindings:binding[-1]=max(.035,min(.045,binding[-1]))
    upper['river_surface_bindings']=json.dumps(bindings)
    bindings=json.loads(foundation['river_surface_bindings'])
    for binding in bindings:binding[-1]=.010
    foundation['river_surface_bindings']=json.dumps(bindings)
def save_checkpoint(completed):
    rig.data.pose_position='REST';bpy.context.view_layer.update()
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    data={'status':'UPPER_REBIND_IN_PROGRESS','garments':['foundation','upper'],'updated_ist':datetime.now(ZoneInfo('Asia/Kolkata')).isoformat(),
          'completed_samples':completed,'source_sha256':asset_digest(source),'runtime_pending_export':True,
          'next_command':'python3 tools/characters/run_river_upper_rebind.py'}
    temporary=checkpoint.with_suffix('.tmp');temporary.write_text(json.dumps(data,indent=2)+'\n');temporary.replace(checkpoint)
    print('RIVER_UPPER_REBIND_CHECKPOINT',completed,flush=True);rig.data.pose_position='POSE'
if not state:save_checkpoint(0)
fit_river_cloth(ROOT,rig,body,objects,existing=True,start_sample=state.get('completed_samples',0),checkpoint_callback=save_checkpoint)
export_river_asset(ROOT,rig,body,len(bpy.data.objects['Opaque fitted bra and thong foundation'].data.polygons))
checkpoint.unlink()
prior=folder/'fit_checkpoint.json'
if prior.exists():prior.unlink()
print('RIVER_UPPER_REBIND_COMPLETE',flush=True)
