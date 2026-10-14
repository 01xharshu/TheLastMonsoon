"""Restore the preserved coarse foundation after a rejected subdivision study."""
import bpy,sys
from pathlib import Path
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from river_asset_export import export_river_asset
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/river_woman/river_woman_motion.blend'))
bpy.context.preferences.filepaths.save_version=0
name='Opaque fitted bra and thong foundation'
reference=bpy.data.objects.get('Retained coarse river foundation')
if reference is None:raise RuntimeError('Retained coarse foundation required')
if len(reference.data.shape_keys.key_blocks)!=675:raise RuntimeError('Foundation corrective keys incomplete')
rejected=bpy.data.objects[name]
rejected.name='Retained rejected dense river foundation'
rejected['river_source_only']=True;rejected.hide_render=True;rejected.hide_set(True)
reference.name=name;reference['river_source_only']=False
reference.hide_render=False;reference.hide_set(False)
rig=bpy.data.objects['village_woman_rig']
body=bpy.data.objects['village_woman_MakeHuman_body']
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
rig.data.pose_position='REST'
for obj in bpy.data.objects:
    if obj.type=='MESH' and obj!=body and obj.data.shape_keys:
        for key in obj.data.shape_keys.key_blocks:key.value=0
bpy.context.view_layer.update()
export_river_asset(ROOT,rig,body,len(reference.data.polygons))
checkpoint=ROOT/'WorkingAssets/NPCs/river_woman/fit_checkpoint.json'
if checkpoint.exists():checkpoint.unlink()
print('RIVER_FOUNDATION_REFERENCE restored; rejected density study excluded from runtime',flush=True)
