"""Audit complete skinned MPFB body and opaque foundation in the rescue export."""
import hashlib,json,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
manifest=json.loads((ROOT/'WorkingAssets/NPCs/rescue_peasant/manifest.json').read_text())
errors=[]
for key in ('source','runtime'):
 if hashlib.sha256((ROOT/manifest[key]).read_bytes()).hexdigest()!=manifest[key+'_sha256']:errors.append(key+' hash mismatch')
raw=(ROOT/manifest['runtime']).read_bytes();length=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+length])
def check_mesh(name):
 node=next(n for n in doc['nodes'] if n.get('name')==name)
 assert 'skin' in node,name+' must retain skin weights'
 primitives=doc['meshes'][node['mesh']]['primitives']
 return sum(doc['accessors'][p['attributes']['POSITION']]['count'] for p in primitives),all(doc['materials'][p['material']].get('alphaMode','OPAQUE')=='OPAQUE' for p in primitives)
body_count,_=check_mesh('RescuePeasantSkin');foundation_count,opaque=check_mesh('OpaqueFoundation')
if body_count<manifest['full_body_vertex_count']:errors.append('export has fewer vertices than complete helper-free source')
if not opaque or not foundation_count:errors.append('opaque separate foundation missing')
if not manifest.get('complete_runtime_body') or manifest.get('clothing_body_masks_enabled',True):errors.append('body mask contract fails')
report=dict(passed=not errors,errors=errors,full_body_export_vertices=body_count,foundation_vertices=foundation_count,foundation_separate_and_opaque=opaque,source_sha256=manifest['source_sha256'],runtime_sha256=manifest['runtime_sha256'],visual_approved=False)
(ROOT/'docs/characters/arjun/rescue_peasant_full_body_validation.json').write_text(json.dumps(report,indent=2)+'\n')
print('RESCUE_FULL_BODY',json.dumps(report))
if errors:raise SystemExit(1)
