"""Export a completed source-fit sweep for native review without refitting it.

Keeps the fit checkpoint until the caller has imported and reviewed the candidate.
Export success does not grant contact, motion or visual approval.
"""
import bpy,json,sys
from pathlib import Path
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from river_asset_export import export_river_asset,asset_digest
folder=ROOT/'WorkingAssets/NPCs/river_woman'
checkpoint=folder/'fit_checkpoint.json'
state=json.loads(checkpoint.read_text())
source=ROOT/state['source']
if state['completed_sweeps']<1:raise RuntimeError('A completed fitting sweep is required')
if asset_digest(source)!=state['source_sha256']:raise RuntimeError('Fit checkpoint differs from editable source')
bpy.ops.wm.open_mainfile(filepath=str(source))
bpy.context.preferences.filepaths.save_version=0
rig=bpy.data.objects['village_woman_rig']
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
rig.data.pose_position='REST'
body=bpy.data.objects['village_woman_MakeHuman_body']
for obj in bpy.data.objects:
    if obj.type=='MESH' and obj!=body and obj.data.shape_keys:
        for key in obj.data.shape_keys.key_blocks:key.value=0
bpy.context.view_layer.update()
export_river_asset(ROOT,rig,body,len(bpy.data.objects['Opaque fitted bra and thong foundation'].data.polygons))
state['source_sha256']=asset_digest(source)
state['runtime_pending_export']=False
state['status']='EXPORTED_FIT_REVIEW_PENDING'
temporary=checkpoint.with_suffix('.tmp')
temporary.write_text(json.dumps(state,indent=2)+'\n');temporary.replace(checkpoint)
print('RIVER_FIT_CHECKPOINT exported completed sweep for native review',flush=True)
