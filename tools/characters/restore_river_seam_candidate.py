"""Restore the retained garment after rejecting a cloth construction experiment."""
import bpy,sys
from pathlib import Path
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from river_asset_export import export_river_asset
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/river_woman/river_woman_motion.blend'))
bpy.context.preferences.filepaths.save_version=0
reference=bpy.data.objects['Retained seam-fitted river upper']
rejected=bpy.data.objects['Fitted cotton upper base'];mesh=rejected.data
bpy.data.objects.remove(rejected,do_unlink=True)
if mesh.users==0:bpy.data.meshes.remove(mesh)
reference.name='Fitted cotton upper base';reference['river_source_only']=False
reference.hide_render=False;reference.hide_set(False)
rig=bpy.data.objects['village_woman_rig'];rig.animation_data_clear();rig.data.pose_position='REST'
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
for obj in bpy.data.objects:
    if obj.type=='MESH' and obj.data.shape_keys and obj.name!='village_woman_MakeHuman_body':
        for key in obj.data.shape_keys.key_blocks:key.value=0
from river_body_physique import restore_donor_physique
restore_donor_physique(ROOT,bpy.data.objects['village_woman_MakeHuman_body'])
export_river_asset(ROOT,rig,bpy.data.objects['village_woman_MakeHuman_body'],len(bpy.data.objects['Opaque fitted bra and thong foundation'].data.polygons))
for name in ['fit_checkpoint.json','upper_rebind_checkpoint.json']:
    checkpoint=ROOT/'WorkingAssets/NPCs/river_woman'/name
    if checkpoint.exists():checkpoint.unlink()
print('RIVER_SEAM_CANDIDATE_RESTORED',flush=True)
