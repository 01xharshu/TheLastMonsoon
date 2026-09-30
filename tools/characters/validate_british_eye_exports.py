"""Reject blank iris textures in the sixteen exported British NPCs."""
import hashlib
import io
import json
import struct
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
results = []
errors = []
for rank in ('private', 'corporal', 'sergeant', 'lieutenant', 'captain', 'major', 'colonel', 'official'):
    manifest = json.loads((ROOT / f'docs/characters/british/candidates/{rank}_pair_manifest.json').read_text())
    source = ROOT / manifest['source']
    if hashlib.sha256(source.read_bytes()).hexdigest() != manifest['source_sha256']:
        errors.append(f'{rank}: source hash changed')
    for sex in ('man', 'woman'):
        entry = manifest['runtime_exports'][sex]
        raw = (ROOT / entry['path']).read_bytes()
        count = struct.unpack_from('<I', raw, 12)[0]
        document = json.loads(raw[20:20 + count])
        binary = raw[28 + count:]
        materials = [m for m in document['materials'] if 'authored iris' in m.get('name', '')]
        if len(materials) != 1:
            errors.append(f'{rank}_{sex}: missing authored iris material')
            continue
        texture = document['textures'][materials[0]['pbrMetallicRoughness']['baseColorTexture']['index']]
        image = document['images'][texture['source']]
        view = document['bufferViews'][image['bufferView']]
        offset = view.get('byteOffset', 0)
        decoded = Image.open(io.BytesIO(binary[offset:offset + view['byteLength']])).convert('RGB')
        extrema = decoded.getextrema()
        dark_pixels = sum(max(pixel) < 60 for pixel in decoded.getdata())
        passed = dark_pixels > 100 and any(high - low > 100 for low, high in extrema)
        passed = passed and hashlib.sha256(raw).hexdigest() == entry['sha256']
        if not passed:
            errors.append(f'{rank}_{sex}: blank iris texture or runtime hash mismatch')
        results.append({'actor': f'{rank}_{sex}', 'passed': passed, 'dark_pixels': dark_pixels, 'texture_size': decoded.size})
report = {'passed': not errors and len(results) == 16, 'actors': results, 'errors': errors,
          'scope': 'Embedded iris pixels and source/runtime hashes; face geometry and appearance require rendered review'}
(ROOT / 'docs/characters/british/candidates/eye_export_validation.json').write_text(json.dumps(report, indent=2) + '\n')
print('BRITISH_EYE_EXPORT', json.dumps(report))
raise SystemExit(0 if report['passed'] else 1)
