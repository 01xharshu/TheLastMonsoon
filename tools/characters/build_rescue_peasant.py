"""Derive an adult shirtless rescue actor from the retained MPFB farmer source."""
import bpy, json, hashlib, math
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'WorkingAssets/NPCs/rescue_peasant'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'WorkingAssets/NPCs/village_farmer/village_farmer_motion_candidate.blend'))
rig = bpy.data.objects['village_farmer_rig']
body = bpy.data.objects['village_farmer_MakeHuman_body']
import sys
sys.path.insert(0, str(ROOT / 'tools/characters'))
from whole_body_contract import retain_complete_body
retain_complete_body(body)
for name in ['Fitted cotton upper base', 'Kurta loose lower panel', 'Soft cotton head wrap', 'Head wrap fold']:
    obj = bpy.data.objects.get(name)
    if obj: bpy.data.objects.remove(obj, do_unlink=True)
# Refine only the rescue outfit: a continuous folded waist above the foundation.
# The torso, arms and legs remain the same retained MPFB human.
hip_groups = {g.index for g in body.vertex_groups if g.name.startswith(('pelvis','thigh_','spine01','spine_01'))}
hip = [v.co for v in body.data.vertices if .80 < v.co.z < .95
       and sum(g.weight for g in v.groups if g.group in hip_groups) > .6]
waist_x = max(abs(v.x) for v in hip) + .025
waist_y = max(abs(v.y) for v in hip) + .025
for name,levels in [
 ('Knee length wrapped dhoti',[(.43,.25,.21),(.49,.255,.21),(.65,.23,.20),
                              (.86,waist_x,waist_y),(.920,waist_x,waist_y),(.935,waist_x+.003,waist_y+.003)]),
 ('Dhoti woven border',[(.43,.252,.212),(.46,.254,.214)])]:
 obj=bpy.data.objects[name]
 materials=list(obj.data.materials)
 sides=64;verts=[];faces=[]
 for row,(z,rx,ry) in enumerate(levels):
  for column in range(sides):
   angle=column*math.tau/sides
   amplitude=.015 if z>.85 else .045
   fold=1+amplitude*math.cos(angle*8+row*.25)
   verts.append((math.cos(angle)*rx*fold,math.sin(angle)*ry*fold,z))
 for row in range(len(levels)-1):
  for column in range(sides):
   nxt=(column+1)%sides
   faces.append((row*sides+column,row*sides+nxt,(row+1)*sides+nxt,(row+1)*sides+column))
 mesh=bpy.data.meshes.new(name+' continuous cotton');mesh.from_pydata(verts,[],faces);mesh.update()
 uv=mesh.uv_layers.new(name="Cotton wrap UV")
 for polygon in mesh.polygons:
  crosses_seam=any(mesh.loops[loop].vertex_index%sides==sides-1 for loop in polygon.loop_indices)
  for loop in polygon.loop_indices:
   index=mesh.loops[loop].vertex_index
   u=(index%sides)/sides
   if crosses_seam and index%sides==0:u=1.0
   uv.data[loop].uv=(u,(mesh.vertices[index].co.z-levels[0][0])/(levels[-1][0]-levels[0][0]))
 for material in materials:mesh.materials.append(material)
 for polygon in mesh.polygons:polygon.use_smooth=True
 obj.data=mesh;obj.vertex_groups.clear()
 for vertex in mesh.vertices:
  influence=.22*max(0,min(1,(.86-vertex.co.z)/.43))
  left=max(0,min(1,.5+vertex.co.x/.5))
  for bone,weight in [('pelvis',1-influence),('thigh_l',influence*left),('thigh_r',influence*(1-left))]:
   (obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)).add([vertex.index],weight,'REPLACE')
 obj.shape_key_add(name='Basis')
 compression=obj.shape_key_add(name='Knockdown cotton compression')
 compression.value=0.0
 for vertex in compression.data:
  if vertex.co.y>.115:vertex.co.y=.115+(vertex.co.y-.115)*.28
 obj['construction']='Continuous folded waist and knee wrap; full body clearance; restrained weighted hem; lying cotton compression'
body['combat_role'] = 'Clearly adult Indian peasant; shirtless; opaque dhoti'
body['source_provenance'] = 'Existing MakeHuman/MPFB farmer; underlying body retained'
# Foundation follows this same MPFB body and keeps the complete editable surface.
foundation = body.copy()
foundation.data = body.data.copy()
foundation.name = 'Opaque fitted adult underwear foundation'
bpy.context.scene.collection.objects.link(foundation)
for modifier in list(foundation.modifiers):
    if modifier.type == 'MASK' and modifier.vertex_group == 'Visible period skin': foundation.modifiers.remove(modifier)
group = foundation.vertex_groups.new(name='Opaque foundation surface')
foundation_bones = {g.index for g in foundation.vertex_groups if g.name.startswith(('pelvis', 'thigh_'))}
arm_bones = {g.index for g in foundation.vertex_groups if g.name.startswith(('upperarm_', 'lowerarm_', 'hand_'))}
foundation_vertices = [v.index for v in foundation.data.vertices if .70 < v.co.z < .91
    and sum(g.weight for g in v.groups if g.group in foundation_bones) > .25
    and sum(g.weight for g in v.groups if g.group in arm_bones) < .01]
group.add(foundation_vertices, 1.0, 'REPLACE')
mask = foundation.modifiers.new('Foundation cut', 'MASK'); mask.vertex_group = group.name
foundation_normals = [vertex.normal.copy() for vertex in foundation.data.vertices]
for vertex, normal in zip(foundation.data.vertices, foundation_normals): vertex.co += normal * .004
material = bpy.data.materials.new('Opaque cotton foundation'); material.diffuse_color=(.18,.14,.11,1)
material.use_nodes=True
material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.18,.14,.11,1)
foundation.data.materials.clear(); foundation.data.materials.append(material)
foundation['presentation'] = 'Opaque fitted adult underwear beneath opaque dhoti'
# Complete body is retained; only helper removal and foundation garment cut are baked.
source = OUT / 'rescue_peasant.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(source))
rig.data.pose_position = 'REST'
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
body_vertex_count = len(body.evaluated_get(dg).data.vertices)
print('RESCUE_BODY_VERTICES', body_vertex_count, 'source', len(body.data.vertices))
assert body_vertex_count > 10000, 'Complete MPFB human surfaces required'
assert all(not m.show_render for m in body.modifiers if m.type == 'MASK' and m.name != 'Hide helpers')
for original, label in [(body, 'RescuePeasantSkin'), (foundation, 'OpaqueFoundation')]:
    mesh = bpy.data.meshes.new_from_object(original.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    cut = bpy.data.objects.new(label, mesh)
    bpy.context.scene.collection.objects.link(cut)
    for group in original.vertex_groups: cut.vertex_groups.new(name=group.name)
    cut.parent = rig
    cut.matrix_parent_inverse = original.matrix_parent_inverse.copy()
    cut.matrix_basis = original.matrix_basis.copy()
    cut.modifiers.new('Armature deformation', 'ARMATURE').object = rig
rig.data.pose_position = 'POSE'
bpy.context.scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for obj in bpy.data.objects:
    if obj.type == 'MESH' and obj not in {body, foundation}: obj.select_set(True)
bpy.context.view_layer.objects.active = rig
runtime = ROOT / 'characters/npcs/rescue_peasant.glb'
bpy.ops.export_scene.gltf(filepath=str(runtime), export_format='GLB', use_selection=True,
    export_animations=False, export_skins=True, export_apply=False, export_cameras=False, export_lights=False)
(OUT / 'manifest.json').write_text(json.dumps(dict(source=str(source.relative_to(ROOT)),
    runtime=str(runtime.relative_to(ROOT)), source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
    runtime_sha256=hashlib.sha256(runtime.read_bytes()).hexdigest(), provenance='Retained MPFB adult farmer',
    complete_runtime_body=True, full_body_vertex_count=body_vertex_count, foundation_body_vertices=len(foundation_vertices),
    clothing_body_masks_enabled=False, visual_approved=False, motion_approved=False), indent=2)+'\n')
