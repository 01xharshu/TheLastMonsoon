"""Opening fit variant of the existing MPFB Arjun; shared sources stay intact."""
import bpy, sys, json, hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))
from arjun_full_body import ensure_full_body
SOURCE = ROOT / 'WorkingAssets/Arjun/candidate/arjun_animated_candidate.blend'
OUT = ROOT / 'WorkingAssets/Arjun/opening_fit'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
bpy.context.preferences.filepaths.save_version = 0
audit = ensure_full_body()
rig = bpy.data.objects['Arjun_Rig']
rig.data.pose_position = 'REST'
body = bpy.data.objects['Arjun_MakeHuman_Body']
disabled = [(m, m.show_viewport) for m in body.modifiers if m.type == 'ARMATURE']
for m, _ in disabled: m.show_viewport = False
bpy.context.view_layer.update()
evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
mesh = evaluated.to_mesh()
points = [evaluated.matrix_world @ v.co for v in mesh.vertices]
trees = {}
for side in [-1, 0, 1]:
    faces = [tuple(p.vertices) for p in mesh.polygons
             if .2 < sum(points[i].z for i in p.vertices)/len(p.vertices) < 1.10
             and max(abs(points[i].x) for i in p.vertices) < .34
             and max(abs(points[i].y) for i in p.vertices) < .26
             and (side == 0 or side*sum(points[i].x for i in p.vertices)/len(p.vertices) > .008)]
    trees[side] = BVHTree.FromPolygons(points, faces)
evaluated.to_mesh_clear()
for m, state in disabled: m.show_viewport = state
garments = []
report = []
for name, side in [('Arjun_DrapedTrousers_-1',-1), ('Arjun_DrapedTrousers_1',1), ('Arjun_Kurta_SplitHem',0)]:
    obj = bpy.data.objects[name]
    fitted = 0
    maximum = 0.0
    for vertex in obj.data.vertices:
        p = obj.matrix_world @ vertex.co
        t = max(0.0, min(1.0, (p.z-.205)/.765))
        centre = Vector((side*(.196-.07*t), -.022, p.z))
        radial = p-centre
        radial.z = 0
        radius = radial.length
        if radius < .001: continue
        radial.normalize()
        # Cast inward from outside, so the far side of a complete thigh is
        # used even when the ring centre sits between two legs.
        hit, _, _, _ = trees[side].ray_cast(centre+radial*.8, -radial, 1.6)
        if hit is None: continue
        needed = (hit-centre).dot(radial)+(.018 if side else .022)
        if needed > radius:
            delta = needed-radius
            vertex.co = obj.matrix_world.inverted() @ (p+radial*delta)
            fitted += 1
            maximum = max(maximum,delta)
    # Transfer from actual MakeHuman body surfaces after fitting, instead of
    # the old uniform height-only waist/thigh skinning.
    for group in body.vertex_groups:
        if not obj.vertex_groups.get(group.name): obj.vertex_groups.new(name=group.name)
    bpy.context.view_layer.objects.active = obj
    transfer = obj.modifiers.new('Opening body surface weights','DATA_TRANSFER')
    transfer.object = body
    transfer.use_vert_data = True
    transfer.data_types_verts = {'VGROUP_WEIGHTS'}
    transfer.vert_mapping = 'POLYINTERP_NEAREST'
    # Apply before subdivision and thickness so editable base weights persist.
    while obj.modifiers.find(transfer.name) > 0:
        bpy.ops.object.modifier_move_up(modifier=transfer.name)
    bpy.ops.object.modifier_apply(modifier=transfer.name)
    obj['opening_fit'] = 'Complete MPFB body retained; cloth eased and surface weights transferred'
    assert maximum < .16, 'Unexpected body region in garment projection'
    garments.append(obj)
    report.append({'mesh':name,'vertices_fitted':fitted,'maximum_ease_m':maximum})
assert ensure_full_body()['body_coordinate_sha256'] == audit['body_coordinate_sha256']
candidate = OUT/'arjun_opening_fitted.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(candidate))
bpy.ops.object.select_all(action='DESELECT')
for obj in [rig,body,bpy.data.objects[audit['foundation']]]+garments:
    obj.hide_set(False)
    obj.hide_render = False
    obj.select_set(True)
bpy.context.view_layer.objects.active = rig
asset = ROOT/'characters/arjun/arjun_opening_fit.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_animations=False,export_yup=True,export_apply=True)
audit.update({'source':str(SOURCE.relative_to(ROOT)), 'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              'candidate':str(candidate.relative_to(ROOT)), 'asset':str(asset.relative_to(ROOT)),
              'garments':report,'shared_source_changed':False,'visual_approval':False})
(OUT/'manifest.json').write_text(json.dumps(audit,indent=2)+'\n')
print('OPENING CLOTHING EXPORT: PASS', json.dumps(report))
