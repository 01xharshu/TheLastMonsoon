"""Recoverable mesh refinement of the existing CC0 horse; unchanged rig/actions.
This is a generic bay candidate, not certification of a historical breed.
"""
from pathlib import Path
import bpy, math, json, hashlib
root=Path(__file__).resolve().parents[2]
source=root/'WorkingAssets/Horse/candidates/quaternius_horse/rigged_horse_candidate.blend'
output=root/'WorkingAssets/Horse/candidates/body_refinement'
output.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(source))
mesh=bpy.data.objects['Horse']
rig=bpy.data.objects['AnimalArmature']
original_bones=[b.name for b in rig.data.bones]
original_actions=[a.name for a in bpy.data.actions]
bpy.context.view_layer.objects.active=mesh
bpy.ops.object.select_all(action="DESELECT");mesh.select_set(True)
# Original flat-shaded faces duplicate their border vertices. Weld exact
# coincident borders before subdivision, preventing each face shrinking apart.
weld=mesh.modifiers.new("ConnectedSurfaceBorders","WELD")
weld.merge_threshold=0.000001
bpy.ops.object.modifier_apply(modifier=weld.name)
# Work in Blender world coordinates; source importer retains a 100x basis.
inverse=mesh.matrix_world.inverted()
def gaussian(value,center,width): return math.exp(-((value-center)/width)**2)
for vertex in mesh.data.vertices:
 p=mesh.matrix_world@vertex.co
 x,y,z=p
 # Rounded rib cage, restrained flank tuck and shoulder/haunch definition.
 barrel=gaussian(y,0.0,1.15)*gaussian(z,2.65,.55)
 shoulder=gaussian(y,-1.15,.48)*gaussian(z,2.72,.60)
 haunch=gaussian(y,1.22,.55)*gaussian(z,2.78,.65)
 p.x *= 1+.10*barrel+.08*shoulder+.06*haunch
 # Taper upper neck, avoiding the long rectangular throat silhouette.
 neck=gaussian(y,-1.95,.52)*gaussian(z,3.55,.55)
 p.x *= 1-.12*neck
 # Restore rounded dorsal volume under the existing saddle rather than
 # changing rider/rig anchor coordinates in this body-only candidate.
 p.z += .28*gaussian(y,0.0,.95)*gaussian(z,3.45,.36)
 # Keep skeleton positions/hooves/back/tack anchors unchanged.
 vertex.co=inverse@p
for polygon in mesh.data.polygons: polygon.use_smooth=True
for material in mesh.data.materials:
 if material.name in ['Main','Main_Light','Main_Dark']:
  tint=(.16,.061,.023,1) if material.name!='Main_Dark' else (.143,.053,.020,1)
  material.diffuse_color=tint
  material.use_nodes=True
  bsdf=material.node_tree.nodes.get('Principled BSDF')
  bsdf.inputs['Base Color'].default_value=tint
  bsdf.inputs['Roughness'].default_value=.72
# Preserve hoof boundaries when smoothing; the source topology has duplicated
# material borders, so avoid an indiscriminate weld across separate skin groups.
crease=mesh.data.attributes.new('crease_edge','FLOAT','EDGE') if not mesh.data.attributes.get('crease_edge') else mesh.data.attributes['crease_edge']
hoof_vertices=set()
for face in mesh.data.polygons:
 if mesh.data.materials[face.material_index].name=='Hooves': hoof_vertices.update(face.vertices)
for edge in mesh.data.edges:
 if all(v in hoof_vertices for v in edge.vertices): crease.data[edge.index].value=.65
bpy.context.view_layer.objects.active=mesh
bpy.ops.object.select_all(action='DESELECT');mesh.select_set(True)
subd=mesh.modifiers.new('BodySurfaceRefinement','SUBSURF')
subd.levels=1;subd.render_levels=1
# Apply only new surface subdivision. Skin weights interpolate; armature stays.
bpy.ops.object.modifier_apply(modifier=subd.name)
assert original_bones==[b.name for b in rig.data.bones]
assert original_actions==[a.name for a in bpy.data.actions]
bpy.ops.wm.save_as_mainfile(filepath=str(output/'horse_body_refinement.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.data.objects: obj.select_set(obj.type in {'ARMATURE','MESH'})
bpy.context.view_layer.objects.active=rig
asset=root/'assets/animals/horse/horse_body_refinement.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',export_yup=True,use_selection=True,export_animations=True,export_animation_mode='ACTIONS')
manifest={'source':str(source.relative_to(root)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'asset':str(asset.relative_to(root)),'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'vertices':len(mesh.data.vertices),'bones':original_bones,'actions':original_actions,'rig_changed':False,'historical_breed_approved':False,'visual_approved':False,'motion_contact_approved':False}
(output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('HORSE BODY REFINEMENT EXPORTED',len(mesh.data.vertices),'vertices',len(original_bones),'bones')
