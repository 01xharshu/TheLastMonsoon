"""Build an isolated, *unapproved* MPFB short-sleeve clothing study.

The starting garment is the MPFB female_sportsuit01 asset, released as CC0
according to its .mhclo header. This tool removes its lower sportswear and
replaces its modern material with the candidate's cotton material. It never
overwrites the input character. An explicit output path is required.
"""
import argparse
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/characters'))
from purpose_cloth_volume import VolumeSurface
from river_coherent_cloth import fit_key
from river_upper_self_fit import points_of, self_hits
from whole_body_contract import retain_complete_body

parser = argparse.ArgumentParser()
parser.add_argument('--identity', required=True)
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
if args.identity not in {f'female_{n:02}' for n in range(1, 7)}:
    raise ValueError('Select one of the six isolated female candidates')
source = ROOT / 'WorkingAssets/NPCs/indian_body_candidates' / args.identity / 'candidate.blend'
output = args.output.expanduser().resolve()
if output == source.resolve() or output.exists():
    raise ValueError('Study output must be a new file, separate from the candidate')
asset = (ROOT / 'WorkingAssets/NPCs/indian_body_candidates/source/female_sportsuit01'
         / 'female_sportsuit01.mhclo')
if not asset.is_file():
    raise FileNotFoundError('Missing retained MPFB garment source: ' + str(asset))

bpy.ops.preferences.addon_enable(module='bl_ext.blender_org.mpfb')
from bl_ext.blender_org.mpfb.services.humanservice import HumanService
bpy.ops.wm.open_mainfile(filepath=str(source))
bpy.context.preferences.filepaths.save_version = 0
body = next(o for o in bpy.data.objects if o.type == 'MESH' and 'MakeHuman_body' in o.name)
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
rig.data.pose_position = 'POSE'
rig.animation_data_clear()
for bone in rig.pose.bones:
    bone.matrix_basis = Matrix.Identity(4)
old = bpy.data.objects['Street coherent cotton blouse and pallu']
old.name = 'Retained old street upper'
old['street_source_only'] = True
old.hide_render = True
old.hide_set(True)
upper = HumanService.add_mhclo_asset(str(asset), body, asset_type='Clothes', subdiv_levels=0)
upper.name = 'Street coherent cotton blouse and pallu'
bm = bmesh.new()
bm.from_mesh(upper.data)
lower = [v for v in bm.verts if (upper.matrix_world @ v.co).z < .89]
bmesh.ops.delete(bm, geom=lower, context='VERTS')
bm.to_mesh(upper.data)
bm.free()
upper.data.update()
upper.data.materials.clear()
upper.data.materials.append(old.data.materials[0])
for face in upper.data.polygons:
    face.material_index = 0
    face.use_smooth = True
color = upper.data.color_attributes.get('StreetCotton') or upper.data.color_attributes.new(
    name='StreetCotton', type='FLOAT_COLOR', domain='POINT')
upper.data.color_attributes.active_color_index = 0
upper.data.color_attributes.render_color_index = 0
old_color = old.data.color_attributes.get('StreetCotton')
if old_color is None or old_color.domain != 'POINT':
    raise RuntimeError('Retained upper has no point-domain cotton colors')
color_tree = KDTree(len(old.data.vertices))
for vertex in old.data.vertices:
    color_tree.insert(old.matrix_world @ vertex.co, vertex.index)
color_tree.balance()
for vertex in upper.data.vertices:
    p = upper.matrix_world @ vertex.co
    _, index, _ = color_tree.find(p)
    color.data[vertex.index].color = old_color.data[index].color
for modifier in body.modifiers:
    if modifier.type == 'MASK':
        modifier.show_viewport = False
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
skin = body.evaluated_get(dg)
skin_mesh = skin.to_mesh()
skin_mesh.calc_loop_triangles()
group = body.vertex_groups['body'].index
human = {v.index for v in body.data.vertices if any(g.group == group and g.weight > .5 for g in v.groups)}
points = [skin.matrix_world @ v.co for v in skin_mesh.vertices]
faces = [tuple(t.vertices) for t in skin_mesh.loop_triangles if all(i in human for i in t.vertices)]
volume = VolumeSurface.FromPolygons(points, faces, all_triangles=True, strict=True)
foundation = bpy.data.objects['Opaque fitted bra and thong foundation'].evaluated_get(dg)
foundation_mesh = foundation.to_mesh()
foundation_mesh.calc_loop_triangles()
foundation_tree = BVHTree.FromPolygons(
    [foundation.matrix_world @ v.co for v in foundation_mesh.vertices],
    [tuple(t.vertices) for t in foundation_mesh.loop_triangles], all_triangles=True)
if not upper.data.shape_keys:
    upper.shape_key_add(name='Basis')
key = upper.data.shape_keys.key_blocks['Basis']
movement = fit_key(rig, upper, volume, key, reset_key=False,
                   minimum_clearance_m=.008, foundation=foundation_tree, jacobi=True)
if movement > .08:
    raise RuntimeError('Study fit exceeded 80 mm; no file saved')
for vertex, fitted in zip(upper.data.vertices, key.data):
    vertex.co = fitted.co
skin.to_mesh_clear()
foundation.to_mesh_clear()
retain_complete_body(body)
upper.data.calc_loop_triangles()
hits = self_hits(points_of(upper), [tuple(t.vertices) for t in upper.data.loop_triangles])
output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(output))
print('TAILORED_UPPER_STUDY', args.identity, 'max_fit_mm', movement * 1000,
      'idle_self_crossings', hits, 'unapproved', str(output), flush=True)
