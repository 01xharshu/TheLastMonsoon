"""Verify exported headwear uses rigid head weights, with per-head source fit."""
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/characters/british/candidates'

def values(document, binary, index):
    accessor = document['accessors'][index]
    view = document['bufferViews'][accessor['bufferView']]
    component = accessor['componentType']
    code, size = {5121: ('B', 1), 5123: ('H', 2), 5126: ('f', 4)}[component]
    count = {'VEC4': 4, 'VEC3': 3}[accessor['type']]
    offset = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
    stride = view.get('byteStride', size * count)
    return [struct.unpack_from('<' + code * count, binary, offset + i * stride)
            for i in range(accessor['count'])]

results = []
errors = []
for fit_path in sorted(OUT.glob('*_headwear_fit.json')):
    report = json.loads(fit_path.read_text())
    rank = report['rank']
    for fit in report['fits']:
        kind = 'woman' if fit['actor'] == 'Companion' else 'man'
        path = ROOT / f'characters/npcs/british/{rank}_{kind}.glb'
        data = path.read_bytes()
        length = struct.unpack_from('<I', data, 12)[0]
        document = json.loads(data[20:20 + length])
        binary = data[28 + length:]
        checked = []
        for node in document['nodes']:
            if node.get('name') not in fit['parts']:
                continue
            assert any(word in node['name'].lower() for word in ('forage cap', 'cap band', 'cap visor', 'bonnet', 'top hat')), node['name']
            skin = document['skins'][node['skin']]
            head = next(i for i, joint in enumerate(skin['joints']) if document['nodes'][joint]['name'] == 'head')
            vertex_count = 0
            for primitive in document['meshes'][node['mesh']]['primitives']:
                attributes = primitive['attributes']
                joints = values(document, binary, attributes['JOINTS_0'])
                weights = values(document, binary, attributes['WEIGHTS_0'])
                for ids, amounts in zip(joints, weights):
                    attached = sum(w for joint, w in zip(ids, amounts) if joint == head)
                    if attached < 0.999:
                        errors.append(f'{rank}_{kind}/{node["name"]}: head weight {attached}')
                vertex_count += len(joints)
            checked.append({'part': node['name'], 'vertices': vertex_count})
        if len(checked) != len(fit['parts']):
            errors.append(f'{rank}_{kind}: missing exported headwear')
        results.append({'actor': rank + '_' + kind, 'crown_width_m': fit['crown_width_m'], 'parts': checked})
report = {'passed': len(results) == 11 and not errors, 'actors_with_headwear': len(results), 'actors': results,
          'errors': errors, 'scope': 'exported skin weights and fitted dimensions; rendered scalp contact reviewed separately'}
(OUT / 'headwear_validation.json').write_text(json.dumps(report, indent=2) + '\n')
print('BRITISH_HEADWEAR', report['passed'], len(results), errors)
raise SystemExit(0 if report['passed'] else 1)
