"""Refine the existing editable fit without rebuilding or altering the physique."""
import bpy,sys,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from village_interpolation_fit import refine
from village_clothing_export import export_fitted
role=sys.argv[sys.argv.index('--')+1];folder=ROOT/'WorkingAssets/NPCs'/role
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.open_mainfile(filepath=str(folder/(role+'_clothing_fitted.blend')))
rig=bpy.data.objects[role+'_rig'];body=bpy.data.objects[role+'_MakeHuman_body']
objects=[o for o in bpy.data.objects if o.type=='MESH' and o.data.shape_keys and o.data.shape_keys.key_blocks.get('idle fit 001')]
report=json.loads((folder/'clothing_fit_manifest.json').read_text())
if '--export-only' not in sys.argv:report['interpolation_repairs']=refine(rig,body,objects,fit_layers="--body-contact-only" not in sys.argv)
export_fitted(ROOT,role,rig,body,report)
