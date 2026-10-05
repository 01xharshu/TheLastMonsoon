"""Audit the reused office runtime bodies; source/costume acceptance is separate."""
import hashlib
import json
import struct
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
ASSETS = [
    ('characters/npcs/households/merchant.glb', 'Complete original MPFB body with retained derived identity', 'short04.001', 'WorkingAssets/NPCs/households/merchant/merchant.blend'),
    ('characters/npcs/british/official_man.glb', 'base.002', 'short03', 'WorkingAssets/NPCs/british/official_pair/official_pair_mpfb_candidate.blend'),
]
records = []
for relative, body_name, foundation_name, source in ASSETS:
    raw = (ROOT / relative).read_bytes()
    length = struct.unpack_from('<I', raw, 12)[0]
    data = json.loads(raw[20:20+length])
    meshes = {mesh.get('name'): (i, mesh) for i, mesh in enumerate(data['meshes'])}
    index, body = meshes[body_name]
    count = sum(data['accessors'][primitive['attributes']['POSITION']]['count'] for primitive in body['primitives'])
    assert count == 14517, (relative, count)
    assert any(node.get('mesh') == index and 'skin' in node for node in data['nodes'])
    foundation_index, foundation = meshes[foundation_name]
    assert foundation_index != index
    assert any(node.get('mesh') == foundation_index and 'skin' in node for node in data['nodes'])
    for primitive in foundation['primitives']:
        material = data['materials'][primitive['material']]
        assert material.get('alphaMode', 'OPAQUE') == 'OPAQUE'
    assert (ROOT / source).exists()
    records.append({'runtime': relative, 'source': source, 'sha256': hashlib.sha256(raw).hexdigest(), 'body_mesh': body_name, 'body_vertices': count, 'skinned_body': True, 'separate_opaque_skinned_foundation': foundation_name})
report = {'status': 'PASS', 'scope': 'runtime complete-body topology, skin, foundation and retained editable source paths; no costume/contact approval', 'assets': records}
(ROOT / 'docs/world/administrative_staff_body_audit.json').write_text(json.dumps(report, indent=2)+'\n')
print('ADMINISTRATIVE STAFF BODY AUDIT: PASS')
