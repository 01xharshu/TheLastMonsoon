"""Isolated pinned-waist lower skirt morph study; never overwrites live assets."""
import bpy, hashlib, json, math
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
source = ROOT / 'WorkingAssets/NPCs/british/private_pair/private_pair_mpfb_candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
body = bpy.data.objects['Companion_MPFB_body']
def body_digest():
    return hashlib.sha256(b''.join(float(c).hex().encode() for v in body.data.vertices for c in v.co)).hexdigest()
original_body = body_digest()
skirt = bpy.data.objects['Companion gathered skirt']
assert not skirt.data.shape_keys, 'Review existing correctives before replacing'
basis = skirt.shape_key_add(name='Basis')
zmax = max(v.co.z for v in skirt.data.vertices)
zmin = min(v.co.z for v in skirt.data.vertices)
report = {}
# Waist and upper seat remain exactly fixed. Lower folds flex outward to
# preserve the inner clearance envelope; a small lateral lag adds hem motion.
for name, side, stride in [('StrideLeft', -1, True), ('StrideRight', 1, True), ('LagLeft', -1, False), ('LagRight', 1, False)]:
    key = skirt.shape_key_add(name=name)
    max_motion = 0.0
    pinned = 0
    for i, vertex in enumerate(basis.data):
        co = vertex.co
        t = (zmax-co.z)/(zmax-zmin)
        u = max(0.0, min(1.0, (t-.22)/.78))
        envelope = u*u*(3-2*u)
        angle = math.atan2(co.y, co.x)
        radius = math.hypot(co.x, co.y)
        if stride:
            # Side-specific broad bulge around the moving leg, no thigh skin
            # copying that would pull the whole bell into the knee.
            lobe = max(0.0, side*math.cos(angle))**2
            radial = .036*envelope*lobe
            delta = (co.x/max(radius, 1e-6)*radial, co.y/max(radius, 1e-6)*radial, .009*envelope*lobe)
        else:
            radial = .012*envelope
            delta = (side*.018*envelope + co.x/max(radius, 1e-6)*radial, co.y/max(radius, 1e-6)*radial, .004*envelope*math.sin(angle*2))
        for axis in range(3):
            key.data[i].co[axis] = co[axis]+delta[axis]
        motion = sum(d*d for d in delta)**.5
        max_motion = max(max_motion, motion)
        if t <= .22:
            assert motion == 0.0
            pinned += 1
    report[name] = {'maximum_displacement_m': max_motion, 'pinned_vertices': pinned}
assert original_body == body_digest()
target = ROOT / 'WorkingAssets/NPCs/british/private_skirt_candidate/private_woman_skirt_candidate.blend'
target.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(target))
manifest = {'source': str(source.relative_to(ROOT)), 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'candidate': str(target.relative_to(ROOT)), 'candidate_sha256': hashlib.sha256(target.read_bytes()).hexdigest(), 'body_coordinates_unchanged': True, 'morphs': report, 'scope': 'restrained secondary deformation study; no cloth simulation, seated corrective or contact approval', 'live_asset_replaced': False}
(ROOT/'docs/characters/british/candidates/private_skirt_candidate.json').write_text(json.dumps(manifest, indent=2)+'\n')
print('SKIRT_CANDIDATE', json.dumps(manifest))
