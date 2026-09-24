"""Export the editable British pair as two skinned Godot preview GLBs.

Run once per pair: Blender --background --python tools/characters/export_british_roster.py -- corporal
"""
import bpy
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RANK = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else 'private'
SOURCE = ROOT / f'WorkingAssets/NPCs/british/{RANK}_pair/{RANK}_pair_mpfb_candidate.blend'
RUNTIME = ROOT / 'characters/npcs/british'
RUNTIME.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))

exports = {}
for slug, suffix in ((RANK.capitalize(), 'man'), ('Companion', 'woman')):
    rig = bpy.data.objects[f'{slug}_game_engine_rig']
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    for obj in bpy.data.objects:
        if obj.parent == rig:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    target = RUNTIME / f'{RANK}_{suffix}.glb'
    bpy.ops.export_scene.gltf(
        filepath=str(target), export_format='GLB', use_selection=True,
        export_animations=False, export_skins=True, export_cameras=False,
        export_lights=False, export_yup=True, export_apply=False,
        export_image_format='JPEG',
    )
    exports[suffix] = {'path': str(target.relative_to(ROOT)),
                       'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
                       'bytes': target.stat().st_size}

manifest_path = ROOT / f'docs/characters/british/candidates/{RANK}_pair_manifest.json'
manifest = json.loads(manifest_path.read_text())
manifest['runtime_exports'] = exports
manifest['runtime_export'] = True
manifest['animation'] = 'Godot procedural idle/walk study; no authored Blender clips'
manifest['placed_in_world'] = False
manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
print('BRITISH_RUNTIME_EXPORT', RANK, json.dumps(exports))
