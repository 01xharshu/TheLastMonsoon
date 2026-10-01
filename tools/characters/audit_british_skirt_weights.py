"""Read-only audit of the Private woman's editable garment weights in Blender."""
import bpy
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
source = root / 'WorkingAssets/NPCs/british/private_pair/private_pair_mpfb_candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
garments = []
for name in ('Companion gathered skirt', 'Companion fitted waist transition'):
    obj = bpy.data.objects.get(name)
    if obj is None:
        continue
    totals = {}
    unique_patterns = set()
    for vertex in obj.data.vertices:
        pattern = tuple(sorted((obj.vertex_groups[g.group].name, round(g.weight, 5)) for g in vertex.groups if g.weight > 0.0001))
        unique_patterns.add(pattern)
        for group, weight in pattern:
            totals[group] = totals.get(group, 0.0) + weight
    garments.append({'object': name, 'vertices': len(obj.data.vertices), 'weight_patterns': len(unique_patterns), 'bone_weight_totals': totals, 'modifiers': [m.type for m in obj.modifiers], 'shape_keys': list(obj.data.shape_keys.key_blocks.keys()) if obj.data.shape_keys else []})
report = {'source': str(source.relative_to(root)), 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'garments': garments, 'companion_meshes': [obj.name for obj in bpy.data.objects if obj.type == 'MESH' and obj.name.startswith('Companion')], 'scope': 'read-only editable source weights and corrective inventory; no cloth or body approval'}
output = root / 'docs/characters/british/candidates/private_skirt_weight_audit.json'
output.write_text(json.dumps(report, indent=2) + '\n')
print('BRITISH_SKIRT_AUDIT', json.dumps(garments))
