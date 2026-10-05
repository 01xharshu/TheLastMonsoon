"""Migrate current editable humans to whole-body masks and record source audit."""
import bpy,sys,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from whole_body_contract import retain_complete_body
sources=[ROOT/'WorkingAssets/NPCs/fort_staff/fort_staff_mpfb.blend',ROOT/'WorkingAssets/NPCs/errand_passenger/errand_passenger_mpfb.blend']+list((ROOT/'WorkingAssets/NPCs').glob('village_*/*.blend'))+list((ROOT/'WorkingAssets/NPCs').glob('river_woman/*.blend'))+list((ROOT/'WorkingAssets/NPCs').glob('rescue_peasant/*.blend'))+list((ROOT/'WorkingAssets/NPCs').glob('households/*/*.blend'))+list((ROOT/'WorkingAssets/NPCs').glob('street_residents/*/*.blend'))+list((ROOT/'WorkingAssets/NPCs').glob('thana_motion/*/*.blend'))+list((ROOT/'WorkingAssets/NPCs').glob('arjun_brother/*mpfb.blend'))+list((ROOT/'WorkingAssets/NPCs').glob('arjun_brother/dev_idle_candidate.blend'))+list((ROOT/'WorkingAssets/NPCs/british').glob('*_pair/*mpfb_candidate.blend'))+list((ROOT/'WorkingAssets/NPCs/british').glob('*_skirt_candidate/*.blend'))+[ROOT/'WorkingAssets/NPCs/british/sergeant_uniform/sergeant_uniform.blend',ROOT/'WorkingAssets/Arjun/candidate/arjun_animated_candidate.blend',ROOT/'WorkingAssets/Arjun/candidate/arjun_reference_candidate.blend']
report=[]
for path in sources:
 if not path.exists():continue
 bpy.ops.wm.open_mainfile(filepath=str(path));bodies=[];changed=False
 for body in bpy.data.objects:
  if body.type=='MESH' and ('makehuman_body' in body.name.lower() or 'mpfb_body' in body.name.lower() or body.name=='Arjun_brother_independent_MakeHuman_body') and not any(t in body.name.lower() for t in ['foundation','underwear','eyebrow','hair','eyes']):
   if any(m.show_viewport or m.show_render for m in body.modifiers if m.type=='MASK' and m.name!='Hide helpers'):changed=True
   assert len(body.data.vertices)>=13380, str(path)+': incomplete source topology'
   retain_complete_body(body)
   bodies.append({'name':body.name,'vertices':len(body.data.vertices),'covered_body_masks_enabled':False})
 if changed:
  bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(path))
 report.append({'source':str(path.relative_to(ROOT)),'bodies':bodies,'mask_state_repaired':changed})
(ROOT/'docs/characters/npcs/whole_body_source_audit.json').write_text(json.dumps(report,indent=2)+'\n')
print('WHOLE_BODY_SOURCE',len(report),flush=True)
