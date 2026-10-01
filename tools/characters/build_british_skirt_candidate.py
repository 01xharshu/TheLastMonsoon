"""Isolated pinned-waist lower skirt morph study; never overwrites live assets."""
import bpy, hashlib, json, math, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
RANK = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else 'private'
assert RANK in ('private', 'corporal', 'sergeant')
source = ROOT / f'WorkingAssets/NPCs/british/{RANK}_pair/{RANK}_pair_mpfb_candidate.blend'
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
scale = (zmax-zmin)/.75
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
            delta = (co.x/max(radius, 1e-6)*radial*scale, co.y/max(radius, 1e-6)*radial*scale, .009*envelope*lobe*scale)
        else:
            radial = .012*envelope
            delta = ((side*.018*envelope + co.x/max(radius, 1e-6)*radial)*scale, co.y/max(radius, 1e-6)*radial*scale, .004*envelope*math.sin(angle*2)*scale)
        for axis in range(3):
            key.data[i].co[axis] = co[axis]+delta[axis]
        motion = sum(d*d for d in delta)**.5
        max_motion = max(max_motion, motion)
        if t <= .22:
            assert motion == 0.0
            pinned += 1
    report[name] = {'maximum_displacement_m': max_motion, 'pinned_vertices': pinned}
# Fit the separate band to the actual skirt/bridge surface instead of the
# original independent ellipse, which protrudes at the back in side view.
from mathutils import Vector
bridge = bpy.data.objects['Companion fitted waist transition']
band = bpy.data.objects.get('Companion gathered waistband')
def ring_at(mesh, z):
    levels = sorted(set(round(v.co.z, 6) for v in mesh.data.vertices))
    low = max((level for level in levels if level <= z+1e-5), default=levels[0])
    high = min((level for level in levels if level >= z-1e-5), default=levels[-1])
    rings = [[v.co.copy() for v in mesh.data.vertices if abs(v.co.z-level)<1e-5] for level in (low, high)]
    return rings, max(0.0, min(1.0, (z-low)/max(high-low, 1e-8)))
for vertex in (band.data.vertices if band else []):
    z = vertex.co.z
    angle = math.atan2(vertex.co.y, vertex.co.x) % math.tau
    rings, fraction = ring_at(bridge if z >= zmax else skirt, z)
    samples = []
    for ring in rings:
        j = angle/math.tau*len(ring)
        a = int(j) % len(ring)
        samples.append(ring[a].lerp(ring[(a+1)%len(ring)], j-int(j)))
    surface = samples[0].lerp(samples[1], fraction)
    vertex.co = surface + Vector((math.cos(angle)*.0025, math.sin(angle)*.0025, 0))
    vertex.co.z = z
report['waistband'] = {'fit': 'interpolated existing skirt and bridge rings plus 2.5 mm clearance' if band else 'no separate waistband in source; existing transition retained', 'body_changed': False}
assert original_body == body_digest()
target = ROOT / f'WorkingAssets/NPCs/british/{RANK}_skirt_candidate/{RANK}_woman_skirt_candidate.blend'
target.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(target))
manifest = {'source': str(source.relative_to(ROOT)), 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'candidate': str(target.relative_to(ROOT)), 'candidate_sha256': hashlib.sha256(target.read_bytes()).hexdigest(), 'body_coordinates_unchanged': True, 'morphs': report, 'scope': 'restrained secondary deformation study; no cloth simulation, seated corrective or contact approval', 'live_asset_replaced': False}
manifest_path = ROOT / f'docs/characters/british/candidates/{RANK}_skirt_candidate.json'
if manifest_path.exists():
    previous = json.loads(manifest_path.read_text())
    manifest['live_asset_replaced'] = previous.get('live_asset_replaced', False)
manifest_path.write_text(json.dumps(manifest, indent=2)+'\n')
print('SKIRT_CANDIDATE', json.dumps(manifest))
