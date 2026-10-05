"""Fort staff derivative of the existing MPFB farmer; preserve complete anatomy."""
import bpy
import bmesh
import json
import hashlib
import sys
import struct
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/characters'))
from whole_body_contract import retain_complete_body
SOURCE = ROOT / 'WorkingAssets/NPCs/village_farmer/village_farmer_motion_candidate.blend'
OUT = ROOT / 'WorkingAssets/NPCs/fort_staff'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
body = bpy.data.objects['village_farmer_MakeHuman_body']
rig = bpy.data.objects['village_farmer_rig']
retain_complete_body(body)
rig.data.pose_position = 'REST'
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
complete = bpy.data.meshes.new_from_object(body.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
# Derive opaque underwear from MPFB skin topology, retaining original deform weights.
foundation = body.copy()
foundation.data = complete.copy()
foundation.name = 'Opaque fitted underwear foundation'
bpy.context.collection.objects.link(foundation)
for modifier in list(foundation.modifiers):
    if modifier.type != 'ARMATURE': foundation.modifiers.remove(modifier)
bm = bmesh.new(); bm.from_mesh(foundation.data)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not .68 < v.co.z < .93], context='VERTS')
for vertex in bm.verts: vertex.co += vertex.normal * .004
bm.to_mesh(foundation.data); bm.free()
mat = bpy.data.materials.new('Opaque cotton foundation')
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Base Color'].default_value = (.18, .14, .11, 1)
bsdf.inputs['Roughness'].default_value = .95
foundation.data.materials.clear(); foundation.data.materials.append(mat)
foundation['presentation'] = 'Separate opaque adult foundation; complete MPFB body retained underneath'
rig.data.pose_position = 'POSE'
bpy.context.scene.frame_set(1)
editable = OUT / 'fort_staff_mpfb.blend'
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(editable))
# Bake helper exclusion and garment masks only; covered skin remains intact.
rig.data.pose_position = 'REST'
bpy.context.view_layer.update(); dg = bpy.context.evaluated_depsgraph_get()
masked = []
for original in list(bpy.data.objects):
    if original.type != 'MESH' or not any(m.type == 'MASK' for m in original.modifiers): continue
    mesh = bpy.data.meshes.new_from_object(original.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    baked = bpy.data.objects.new('fort_staff_export_full_body' if original == body else original.name + '_export_upper_cutout', mesh)
    bpy.context.collection.objects.link(baked)
    for group in original.vertex_groups: baked.vertex_groups.new(name=group.name)
    baked.parent = rig
    baked.matrix_parent_inverse = original.matrix_parent_inverse.copy()
    baked.matrix_basis = original.matrix_basis.copy()
    baked.modifiers.new('Armature deformation', 'ARMATURE').object = rig
    masked.append(original)
rig.data.pose_position = 'POSE'; bpy.context.scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True)
for obj in bpy.data.objects:
    if obj.type == 'MESH' and obj not in masked: obj.select_set(True)
bpy.context.view_layer.objects.active = rig
runtime = OUT / 'fort_staff_rigged_candidate.glb'
bpy.ops.export_scene.gltf(filepath=str(runtime), export_format='GLB', use_selection=True,
    export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True,
    export_frame_range=False, export_cameras=False, export_lights=False,
    export_yup=True, export_skins=True, export_apply=False)
# Verify every retained body vertex survived glTF export, allowing UV seam duplicates.
blob = runtime.read_bytes()
json_length = struct.unpack_from('<I', blob, 12)[0]
gltf = json.loads(blob[20:20+json_length])
binary_start = 20 + json_length + 8
node = next(n for n in gltf['nodes'] if n.get('name') == 'fort_staff_export_full_body')
primitive = gltf['meshes'][node['mesh']]['primitives'][0]
accessor = gltf['accessors'][primitive['attributes']['POSITION']]
view = gltf['bufferViews'][accessor['bufferView']]
offset = binary_start + view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
stride = view.get('byteStride', 12)
exported = {tuple(round(v, 4) for v in struct.unpack_from('<3f', blob, offset + i*stride)) for i in range(accessor['count'])}
expected = {tuple(round(v, 4) for v in (vertex.co.x, vertex.co.z, -vertex.co.y)) for vertex in complete.vertices}
missing = expected - exported
if missing: raise RuntimeError(f'Body export omitted {len(missing)} original MPFB positions')
report = dict(source=str(SOURCE.relative_to(ROOT)), editable=str(editable.relative_to(ROOT)),
    runtime=str(runtime.relative_to(ROOT)), complete_body_vertices=len(complete.vertices), runtime_body_vertices=accessor['count'],
    missing_body_positions=len(missing), source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    foundation_vertices=len(foundation.data.vertices), clothing_body_masks_enabled=False,
    runtime_sha256=hashlib.sha256(runtime.read_bytes()).hexdigest(), visual_approved=False)
(OUT / 'manifest.json').write_text(json.dumps(report, indent=2)+'\n')
print('FORT_STAFF_BODY', json.dumps(report))
