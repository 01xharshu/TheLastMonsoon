"""Refit the lower sari and pallu while retaining the complete source and keys."""
import bpy,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from river_cloth_correctives import fit_river_cloth
from river_asset_export import export_river_asset
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/river_woman/river_woman_motion.blend'))
bpy.context.preferences.filepaths.save_version=0
rig=bpy.data.objects['village_woman_rig'];body=bpy.data.objects['village_woman_MakeHuman_body']
names=['Wrapped sari lower drape','Sari lower border','Woven sari pallu over blouse']
if '--seated' in sys.argv:names+=['Fitted cotton upper base','Opaque fitted bra and thong foundation']
objects=[bpy.data.objects[name] for name in names]
for obj in bpy.data.objects:
 if obj.type=='MESH' and obj.data.shape_keys:
  for key in obj.data.shape_keys.key_blocks:
   if key.name.startswith(('River cloth ','River walk ')):key.value=0
pallu=bpy.data.objects['Woven sari pallu over blouse'];bindings=json.loads(pallu['river_surface_bindings'])
for binding in bindings:binding[-1]=min(.04,binding[-1])
pallu['river_surface_bindings']=json.dumps(bindings)
fit_river_cloth(ROOT,rig,body,objects,existing=True,pose_filter=(lambda pose:'slope' not in pose and 35.0<=pose['time']<=51.0) if '--seated' in sys.argv else None)
export_river_asset(ROOT,rig,body,894)
