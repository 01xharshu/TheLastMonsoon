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
    body = bpy.data.objects[f'{slug}_MPFB_body']
    outfit = bpy.data.objects[f'{slug}_fitted_cloth_base']
    rig.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()

    def bake_masked_rest(original):
        # Godot does not apply Blender's MPFB mask modifiers after importing a
        # skinned glTF. Bake only the rest-pose cutout for this export; retain
        # the complete editable meshes in the saved .blend source.
        baked_mesh = bpy.data.meshes.new_from_object(
            original.evaluated_get(depsgraph),
            preserve_all_data_layers=True, depsgraph=depsgraph)
        baked = bpy.data.objects.new(original.name + '_export_cutout', baked_mesh)
        bpy.context.scene.collection.objects.link(baked)
        for group in original.vertex_groups:
            baked.vertex_groups.new(name=group.name)
        baked.parent = rig
        baked.matrix_parent_inverse = original.matrix_parent_inverse.copy()
        baked.matrix_basis = original.matrix_basis.copy()
        baked.modifiers.new('Armature deformation', 'ARMATURE').object = rig
        return baked

    cutouts = [bake_masked_rest(body), bake_masked_rest(outfit)]
    rig.data.pose_position = 'POSE'
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    for obj in bpy.data.objects:
        if obj.parent == rig and obj not in (body, outfit):
            obj.select_set(True)
            if obj.type == 'MESH':
                if obj.name.endswith('_eyes'):
                    # Preserve MPFB's iris map with a direct glTF connection.
                    # Its MixRGB tint otherwise enters the flat-color fallback.
                    images = [node.image for slot in obj.material_slots
                              if slot.material and slot.material.use_nodes
                              for node in slot.material.node_tree.nodes
                              if node.type == 'TEX_IMAGE' and node.image]
                    if not images:
                        raise RuntimeError(f'No source iris map on {obj.name}')
                    eye_image = images[0]
                    eye_image.reload()
                    eye_mat = bpy.data.materials.new(obj.name + ' authored iris')
                    eye_mat.use_nodes = True
                    eye_bs = eye_mat.node_tree.nodes.get('Principled BSDF')
                    eye_bs.inputs['Roughness'].default_value = .35
                    eye_tex = eye_mat.node_tree.nodes.new('ShaderNodeTexImage')
                    eye_tex.image = eye_image
                    eye_mat.node_tree.links.new(eye_tex.outputs['Color'], eye_bs.inputs['Base Color'])
                    obj.data.materials.clear()
                    obj.data.materials.append(eye_mat)
                # Torso straps must not inherit nearby arm/leg weights from
                # the donor body's nearest-surface lookup.
                if 'crossbelt' in obj.name.lower():
                    obj.vertex_groups.clear()
                    obj.vertex_groups.new(name='spine_02').add(
                        list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
                for slot in obj.material_slots:
                    mat = slot.material
                    if mat is None or not mat.use_nodes:
                        continue
                    bs = mat.node_tree.nodes.get('Principled BSDF')
                    if bs is None:
                        continue
                    base = bs.inputs['Base Color']
                    # glTF cannot represent our procedural Blender noise/ramp;
                    # export its authored flat color rather than white.
                    if base.is_linked and base.links[0].from_node.type != 'TEX_IMAGE':
                        safe = mat.copy()
                        safe.name = mat.name + ' glTF flat-color'
                        safe_bs = safe.node_tree.nodes.get('Principled BSDF')
                        safe_base = safe_bs.inputs['Base Color']
                        for link in list(safe_base.links):
                            safe.node_tree.links.remove(link)
                        safe_base.default_value = tuple(mat.diffuse_color)
                        slot.material = safe
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
    bpy.data.objects.remove(cutouts[0], do_unlink=True)
    bpy.data.objects.remove(cutouts[1], do_unlink=True)

manifest_path = ROOT / f'docs/characters/british/candidates/{RANK}_pair_manifest.json'
manifest = json.loads(manifest_path.read_text())
manifest['runtime_exports'] = exports
manifest['runtime_export'] = True
manifest['animation'] = 'Independent Godot AnimationTree idle/walk Blend2 with calibrated walk TimeScale; personal clips and male/female profiles'
manifest['placed_in_world'] = manifest.get('placed_in_world', False)
manifest['eye_material'] = 'Original MPFB iris image directly connected to glTF base color; source shader retained in Blender'
manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
print('BRITISH_RUNTIME_EXPORT', RANK, json.dumps(exports))
