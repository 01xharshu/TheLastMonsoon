"""Refresh the retained river export without refitting unchanged work poses."""
import bpy,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from river_asset_export import export_river_asset
from whole_body_contract import retain_complete_body
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/river_woman/river_woman_motion.blend'))
bpy.context.preferences.filepaths.save_version=0
rig=bpy.data.objects['village_woman_rig'];body=bpy.data.objects['village_woman_MakeHuman_body']
retain_complete_body(body);rig.data.pose_position='REST';rig.animation_data_clear()
export_river_asset(ROOT,rig,body,len(bpy.data.objects['Opaque fitted bra and thong foundation'].data.polygons))
