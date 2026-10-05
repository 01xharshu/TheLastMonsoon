"""Verify complete runtime body retention, separate opaque foundation and hashes."""
import hashlib,json,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
report={'scope':'GLB complete-body topology, separate opaque foundation and exact source/export hashes; no appearance/contact approval','actors':{},'errors':[]}
body_hashes=set()
for role in ['dock_porter','boatman','record_clerk']:
 folder=ROOT/'WorkingAssets/NPCs'/role
 for name in ['manifest.json','motion_manifest.json']:
  manifest=json.loads((folder/name).read_text())
  if not manifest.get('complete_runtime_body'):report['errors'].append(role+': manifest does not retain complete body')
  for key in ['source','runtime']:
   if hashlib.sha256((ROOT/manifest[key]).read_bytes()).hexdigest()!=manifest[key+'_sha256']:
    report['errors'].append(role+': '+name+' '+key+' hash mismatch')
 path=folder/(role+'_rigged_candidate.glb');raw=path.read_bytes();length=struct.unpack_from('<I',raw,12)[0]
 doc=json.loads(raw[20:20+length]);binary=raw[28+length:]
 body=next(node for node in doc['nodes'] if node.get('name')==role+'_export_full_body')
 primitives=doc['meshes'][body['mesh']]['primitives']
 count=sum(doc['accessors'][prim['attributes']['POSITION']]['count'] for prim in primitives)
 digest=hashlib.sha256()
 for prim in primitives:
  accessor=doc['accessors'][prim['attributes']['POSITION']];view=doc['bufferViews'][accessor['bufferView']]
  offset=view.get('byteOffset',0)+accessor.get('byteOffset',0)
  digest.update(binary[offset:offset+accessor['count']*12])
 body_hashes.add(digest.hexdigest())
 if count<13000 or 'skin' not in body:report['errors'].append(role+': full skinned body missing')
 foundation=next(node for node in doc['nodes'] if node.get('name')=='Opaque fitted underwear foundation')
 opaque=all(doc['materials'][prim['material']].get('alphaMode','OPAQUE')=='OPAQUE' for prim in doc['meshes'][foundation['mesh']]['primitives'])
 if not opaque or 'skin' not in foundation:report['errors'].append(role+': opaque skinned foundation missing')
 report['actors'][role]={'full_body_vertices':count,'independent_body_position_sha256':digest.hexdigest(),'foundation_separate_and_opaque':opaque}
if len(body_hashes)!=3:report['errors'].append('Underlying body geometry is not independently different')
report['passed']=not report['errors']
(ROOT/'docs/characters/npcs/purpose_full_body_validation.json').write_text(json.dumps(report,indent=2)+'\n')
print('PURPOSE_FULL_BODY',json.dumps(report))
if report['errors']:raise SystemExit(1)
