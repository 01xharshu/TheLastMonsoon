"""Audit known runtime human consumers for restored complete MPFB body geometry."""
import json,struct,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
paths=[ROOT/'characters/arjun/arjun.glb',ROOT/'characters/npcs/dev/dev_idle_candidate.glb',ROOT/'characters/npcs/rescue_peasant.glb']
slugs=['village_farmer','village_woman','village_fruit_seller','village_weaver_assistant','river_woman','dock_porter','boatman','record_clerk']
for slug in slugs:
 paths.append(ROOT/f'characters/npcs/motion/{slug}/{slug}_rigged_candidate.glb')
 if slug!='river_woman':paths.append(ROOT/f'characters/npcs/{slug}.glb')
paths+=list((ROOT/'characters/npcs/motion/fort_staff').glob('*.glb'))+list((ROOT/'characters/npcs/motion/errand_passenger').glob('*.glb'))
paths+=list((ROOT/'characters/npcs/british').glob('*.glb'))
for family in ['households','street_residents']:
 for role in ['landowner','merchant']:paths.append(ROOT/f'characters/npcs/{family}/{role}.glb')
for role in ['daroga','mohurrir','burkundaz']:
 for suffix in ['','_motion']:paths.append(ROOT/f'characters/npcs/thana/{role}{suffix}.glb')
report={'scope':'Known human runtime assets including player, NPCs and shared driver/staff donors; full geometry structural audit, no cloth/motion approval','assets':[],'errors':[]}
for p in paths:
 if not p.exists():report['errors'].append(str(p.relative_to(ROOT))+': missing');continue
 raw=p.read_bytes();doc=json.loads(raw[20:20+struct.unpack_from('<I',raw,12)[0]])
 bodies=[]
 for n in doc['nodes']:
  name=n.get('name','').lower()
  if 'mesh' in n and (any(t in name for t in ['makehuman_body','mpfb_body','visible_skin','export_skin','export_full_body','rescuepeasantskin','complete_body_export']) or name=='arjun_makehuman_body') and not any(t in name for t in ['eyebrow','hair','eyes','foundation','underwear']):
   primitives=doc['meshes'][n['mesh']]['primitives'];count=sum(doc['accessors'][q['attributes']['POSITION']]['count'] for q in primitives)
   triangles=sum(doc['accessors'][q['indices']]['count']//3 for q in primitives)
   bodies.append({'node':n['name'],'vertices':count,'triangles':triangles,'skinned':'skin' in n})
 if not bodies or max(b['vertices'] for b in bodies)<14517:report['errors'].append(str(p.relative_to(ROOT))+': body incomplete or unrecognized')
 if p.name=='arjun.glb' and max([b['vertices'] for b in bodies] or [0])<50000:report['errors'].append('Arjun subdivided full body still cut')
 report['assets'].append({'path':str(p.relative_to(ROOT)),'sha256':hashlib.sha256(raw).hexdigest(),'body':bodies})
report['passed']=not report['errors'];report['asset_count']=len(report['assets'])
(ROOT/'docs/characters/npcs/whole_body_runtime_audit.json').write_text(json.dumps(report,indent=2)+'\n')
print('WHOLE_BODY_RUNTIME',report['asset_count'],report['passed'],json.dumps(report['errors']))
if report['errors']:raise SystemExit(1)
