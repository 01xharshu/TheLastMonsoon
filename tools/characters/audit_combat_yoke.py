"""Check retained fitting-source hashes and the two skinned opaque garments."""
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
manifest = json.loads((ROOT / 'WorkingAssets/Arjun/combat_clothing/manifest.json').read_text())
errors = []
for key in ('source', 'runtime'):
    if hashlib.sha256((ROOT / manifest[key]).read_bytes()).hexdigest() != manifest[key + '_sha256']:
        errors.append(key + ' hash mismatch')
if hashlib.sha256((ROOT / 'characters/arjun/arjun.glb').read_bytes()).hexdigest() != manifest['fitting_body_sha256']:
    errors.append('fitting body changed since garment rebuild')
raw = (ROOT / manifest['runtime']).read_bytes()
length = struct.unpack_from('<I', raw, 12)[0]
doc = json.loads(raw[20:20 + length])
meshes = [n for n in doc['nodes'] if 'mesh' in n]
if len(meshes) != 2:
    errors.append('expected separate foundation and trouser panel')
counts = {}
for node in meshes:
    if 'skin' not in node:
        errors.append(node['name'] + ' has no skin')
    primitives = doc['meshes'][node['mesh']]['primitives']
    counts[node['name']] = sum(doc['accessors'][p['attributes']['POSITION']]['count'] for p in primitives)
    for primitive in primitives:
        if not {'JOINTS_0', 'WEIGHTS_0'}.issubset(primitive['attributes']):
            errors.append(node['name'] + ' lost deformation weights')
        material = doc['materials'][primitive['material']]
        if material.get('alphaMode', 'OPAQUE') != 'OPAQUE':
            errors.append(node['name'] + ' is not opaque')
report = dict(passed=not errors, errors=errors, garment_vertices=counts,
              fitting_body_sha256=manifest['fitting_body_sha256'],
              runtime_sha256=manifest['runtime_sha256'],
              body_retention_independently_audited=False, visual_approved=False)
(ROOT / 'docs/characters/arjun/combat_yoke_validation.json').write_text(json.dumps(report, indent=2) + '\n')
print('COMBAT YOKE', json.dumps(report))
if errors:
    raise SystemExit(1)
