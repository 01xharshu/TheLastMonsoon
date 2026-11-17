"""Extract adult body shape inputs through MPFB, without changing game assets.

Run Blender in background with this script. The resulting source-space deltas
are authoring inputs only: clothing and rigs still require fitting and review.
"""
import bpy, hashlib, json, sys
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'WorkingAssets/NPCs/indian_body_profiles'
DONORS = {
    'female': ROOT / 'WorkingAssets/NPCs/river_woman/river_woman_motion.blend',
    'male': ROOT / 'WorkingAssets/NPCs/street_residents/merchant/merchant.blend',
}
# These are independent human proportions, not assumptions about Indian people.
PROFILES = {
    'female': [
        dict(weight=.30, muscle=.28, proportions=.43, cupsize=.30, buttock=-.35),
        dict(weight=.42, muscle=.36, proportions=.55, cupsize=.39, buttock=.10),
        dict(weight=.50, muscle=.30, proportions=.43, cupsize=.57, buttock=.28),
        dict(weight=.59, muscle=.40, proportions=.56, cupsize=.46, buttock=-.12),
        dict(weight=.68, muscle=.27, proportions=.45, cupsize=.65, buttock=.42),
        dict(weight=.39, muscle=.52, proportions=.57, cupsize=.52, buttock=.04),
    ],
    'male': [
        dict(weight=.30, muscle=.30, proportions=.43),
        dict(weight=.42, muscle=.57, proportions=.55),
        dict(weight=.55, muscle=.42, proportions=.45),
        dict(weight=.66, muscle=.31, proportions=.57),
    ],
}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    fuller_female = '--fuller-female' in sys.argv
    bpy.ops.preferences.addon_enable(module='bl_ext.blender_org.mpfb')
    from bl_ext.blender_org.mpfb.services.targetservice import TargetService
    from bl_ext.blender_org.mpfb.services.locationservice import LocationService
    from bl_ext.blender_org.mpfb.entities.objectproperties import HumanObjectProperties
    OUT.mkdir(parents=True, exist_ok=True)
    for sex, donor in DONORS.items():
        if fuller_female and sex != 'female':
            continue
        before = sha(donor)
        bpy.ops.wm.open_mainfile(filepath=str(donor))
        body = next(o for o in bpy.data.objects if o.type == 'MESH' and 'MakeHuman_body' in o.name)
        for modifier in body.modifiers:
            if modifier.type in ('MASK', 'ARMATURE'):
                modifier.show_viewport = False
        if body.data.shape_keys:
            for key in body.data.shape_keys.key_blocks:
                if key.name.startswith('River identity'):
                    key.value = 0
        macro = TargetService.get_macro_info_dict_from_basemesh(body)
        if float(macro['age']) < .35:
            raise RuntimeError('Donor must be clearly adult')
        def sample():
            bpy.context.view_layer.update()
            evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
            mesh = evaluated.to_mesh()
            values = np.empty(len(mesh.vertices) * 3, dtype=np.float32)
            mesh.vertices.foreach_get('co', values)
            evaluated.to_mesh_clear()
            return values.reshape((-1, 3))
        original = sample()
        # Some edited donors do not match the macro metadata. Normalize once
        # and subtract that same-macro result so only the requested change is
        # transferred onto the retained donor, rather than the normalization.
        TargetService.reapply_macro_details(body, remove_zero_weight_targets=False)
        base = sample()
        normalization_max = float(np.linalg.norm(base - original, axis=1).max())
        buttock_keys = None
        if sex == 'female':
            target_dir = Path(LocationService.get_mpfb_data('targets')) / 'buttocks'
            buttock_keys = [TargetService.load_target(body, str(target_dir / f'buttocks-volume-{name}.target.gz')) for name in ('decr', 'incr')]
        results = {}
        stats = []
        profiles = PROFILES[sex]
        if fuller_female:
            # Preserve each adult's other MPFB proportions and their variation.
            # This is a new input set, never a replacement for the baseline.
            profiles = [dict(profile, cupsize=min(.95, profile['cupsize'] + .14),
                             buttock=min(1.0, profile['buttock'] + .35))
                        for profile in profiles]
        for index, profile in enumerate(profiles, 1):
            for key, value in profile.items():
                if key != 'buttock':
                    HumanObjectProperties.set_value(key, value, entity_reference=body)
            TargetService.reapply_macro_details(body, remove_zero_weight_targets=False)
            if buttock_keys:
                buttock_keys[0].value = max(0.0, -profile['buttock'])
                buttock_keys[1].value = max(0.0, profile['buttock'])
            delta = sample() - base
            if delta.shape != base.shape or not np.isfinite(delta).all():
                raise RuntimeError('Unexpected MPFB body topology')
            results[f'{sex}_{index:02d}'] = delta
            stats.append(dict(id=f'{sex}_{index:02d}', macro=profile,
                              max_delta_m=float(np.linalg.norm(delta, axis=1).max())))
        if sha(donor) != before:
            raise RuntimeError('Donor was changed')
        label = 'female_fuller' if fuller_female else sex
        output = OUT / f'{label}_mpfb_deltas.npz'
        np.savez_compressed(output, **results)
        manifest = dict(donor=str(donor.relative_to(ROOT)), donor_sha256=before,
                        body=body.name, vertices=len(base), adult_age=macro['age'],
                        method='MPFB TargetService.reapply_macro_details, relative to normalized donor macro',
                        donor_normalization_max_m=normalization_max, profiles=stats,
                        output=str(output.relative_to(ROOT)),
                        status='authoring inputs only; rig, clothing and runtime unverified')
        (OUT / f'{label}_manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
        print('INDIAN_BODY_PROFILE_INPUT', json.dumps(manifest), flush=True)

main()
