"""Derive two editable wealthy-household previews from the existing MPFB rig."""
import bpy, sys, json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
role=sys.argv[sys.argv.index('--')+1]
source=root/'WorkingAssets/NPCs/village_farmer/village_farmer_motion_candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
def material(name,color,roughness=.72):
 mat=bpy.data.materials.new(name);mat.diffuse_color=(*color,1);mat.use_nodes=True
 bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1)
 bs.inputs['Roughness'].default_value=roughness
 return mat
cream=material('Fine cream woven cotton',(.78,.70,.52))
upper=material('Merchant indigo waistcoat' if role=='merchant' else 'Landowner ivory coat',(.025,.055,.10) if role=='merchant' else (.82,.75,.60))
shawl=material('Burgundy shoulder shawl',(.24,.025,.04))
gold=material('Woven ochre gold border',(.62,.39,.095))
leather=material('Brown leather footwear',(.09,.035,.017),.48)
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
assignments={'Fitted cotton upper base':upper,'Kurta loose lower panel':upper,
 'Knee length wrapped dhoti':cream,'Dhoti woven border':gold,
 'Soft cotton head wrap':cream,'Head wrap fold':gold}
# Replace shared donor shaders with exportable, unlinked materials.
for name,mat in assignments.items():
 obj=bpy.data.objects[name];obj.data.materials.clear();obj.data.materials.append(mat)
# New fitted cloth bands follow the scalp; the donor wrap intersected the hair.
for name in ['Soft cotton head wrap','Head wrap fold']:
 bpy.data.objects.remove(bpy.data.objects[name],do_unlink=True)
for row in range(3):
 bpy.ops.mesh.primitive_torus_add(major_segments=48,minor_segments=10,major_radius=.086-row*.003,minor_radius=.013,location=(0,-.030,1.595+row*.017))
 band=bpy.context.object;band.name='Fitted turban fold '+str(row);band.scale.y=1.19
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 band.data.materials.append(gold if row==0 else cream)
 for poly in band.data.polygons:poly.use_smooth=True
 group=band.vertex_groups.new(name='head');group.add(list(range(len(band.data.vertices))),1,'REPLACE')
 mod=band.modifiers.new('Skin','ARMATURE');mod.object=rig;band.parent=rig
bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=20,location=(0,-.030,1.632))
crown=bpy.context.object;crown.name='Fitted turban crown';crown.scale=(.079,.095,.027)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
crown.data.materials.append(cream)
for poly in crown.data.polygons:poly.use_smooth=True
group=crown.vertex_groups.new(name='head');group.add(list(range(len(crown.data.vertices))),1,'REPLACE')
mod=crown.modifiers.new('Skin','ARMATURE');mod.object=rig;crown.parent=rig
# The donor lower panel deforms into pointed tails in the relaxed-arm pose.
bpy.data.objects.remove(bpy.data.objects['Kurta loose lower panel'],do_unlink=True)
# The shoulder cloth follows the existing garment surface rather than a rigid box.
from mathutils import Vector
rig.data.pose_position='REST';bpy.context.view_layer.update()
deps=bpy.context.evaluated_depsgraph_get()
shirt=bpy.data.objects['Fitted cotton upper base'].evaluated_get(deps)
points=[shirt.matrix_world@v.co for v in shirt.data.vertices]
verts=[];faces=[]
for z in [.90,1.00,1.10,1.20,1.30,1.37]:
 for x in [-.19,-.165,-.085,-.06]:
  nearby=sorted(points,key=lambda p:(p.x-x)**2+(p.z-z)**2)[:24]
  y=min(p.y for p in nearby)-.014
  verts.append((x,y,z))
for row in range(5):
 for col in range(3):
  i=row*4+col;faces.append((i,i+1,i+5,i+4))
mesh=bpy.data.meshes.new('Tailored shoulder drape');mesh.from_pydata(verts,[],faces);mesh.materials.append(shawl);mesh.materials.append(gold)
obj=bpy.data.objects.new('Bordered shoulder shawl',mesh);bpy.context.collection.objects.link(obj)
for i,poly in enumerate(mesh.polygons):poly.material_index=1 if i%3 in [0,2] else 0
# Copy nearby body garment weights for independent torso movement.
shirt_source=bpy.data.objects['Fitted cotton upper base']
for group in shirt_source.vertex_groups:obj.vertex_groups.new(name=group.name)
for v in mesh.vertices:
 nearest=min(shirt_source.data.vertices,key=lambda q:(shirt_source.matrix_world@q.co-v.co).length_squared)
 for g in nearest.groups:obj.vertex_groups[g.group].add([v.index],g.weight,'REPLACE')
mod=obj.modifiers.new('Skin','ARMATURE');mod.object=rig;obj.parent=rig
solid=obj.modifiers.new('Woven thickness','SOLIDIFY');solid.thickness=.004
for side,x in [('l',.184),('r',-.184)]:
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=(x,-.15,.055))
 shoe=bpy.context.object;shoe.name='Leather shoe '+side;shoe.scale=(.066,.197,.058)
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 shoe.data.materials.append(leather)
 for poly in shoe.data.polygons:poly.use_smooth=True
 group=shoe.vertex_groups.new(name='foot_'+side);group.add(list(range(len(shoe.data.vertices))),1,'REPLACE')
 mod=shoe.modifiers.new('Skin','ARMATURE');mod.object=rig;shoe.parent=rig
out=root/f'WorkingAssets/NPCs/households/{role}'; out.mkdir(parents=True,exist_ok=True)
bpy.context.preferences.filepaths.save_version=0

import sys
sys.path.insert(0,str(root/'tools/characters'))
from whole_body_contract import retain_complete_body
retain_complete_body(bpy.data.objects['village_farmer_MakeHuman_body'])

# Bake evaluated rest geometry, including morphs and garment masks, then retain skinning.
for rig in bpy.data.objects:
 if rig.type=='ARMATURE':rig.data.pose_position='REST'
bpy.context.view_layer.update()
depsgraph=bpy.context.evaluated_depsgraph_get()
for obj in list(bpy.data.objects):
 if obj.type!='MESH':continue
 mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph),preserve_all_data_layers=True,depsgraph=depsgraph)
 obj.data=mesh
 for mod in list(obj.modifiers):
  if mod.type!='ARMATURE':obj.modifiers.remove(mod)
# Local facial sculpt keeps eyes and rig proportions intact.
import math
body=bpy.data.objects['village_farmer_MakeHuman_body']
for v in body.data.vertices:
 jaw=math.exp(-((v.co.z-1.455)/.036)**2)
 v.co.x*=1+(.075 if role=='merchant' else -.055)*jaw
 if role=='landowner':v.co.y-=.005*math.exp(-((v.co.z-1.505)/.025)**2-(v.co.x/.025)**2)
hairmat=material('Merchant black moustache' if role=='merchant' else 'Landowner salt and pepper moustache',(.022,.015,.012) if role=='merchant' else (.075,.070,.060))
for sign in [-1,1]:
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=(sign*.017,-.153,1.474))
 hair=bpy.context.object;hair.name='Tailored moustache '+str(sign)
 hair.scale=(.023,.0045,.0045 if role=='merchant' else .006)
 hair.rotation_euler.y=sign*(.12 if role=='merchant' else -.18)
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 hair.data.materials.append(hairmat)
 for poly in hair.data.polygons:poly.use_smooth=True
 group=hair.vertex_groups.new(name='head');group.add(list(range(len(hair.data.vertices))),1,'REPLACE')
 mod=hair.modifiers.new('Skin','ARMATURE');mod.object=rig;hair.parent=rig
for side in ['l','r']:
 shoe=bpy.data.objects['Leather shoe '+side]
 for v in shoe.data.vertices:
  if v.co.z+shoe.location.z<.014:v.co.z=.006-shoe.location.z
# Save the final rest meshes with their rig and editable materials.
bpy.ops.wm.save_as_mainfile(filepath=str(out/f'{role}.blend'))
runtime=root/'characters/npcs/households';runtime.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(runtime/f'{role}.glb'),export_format='GLB',export_skins=True,export_animations=False,export_cameras=False,export_lights=False)
(out/'manifest.json').write_text(json.dumps({'role':role,'donor':str(source.relative_to(root)),'facial_variant':'broader jaw, thin black moustache' if role=='merchant' else 'narrower jaw, stronger nose, grey moustache','status':'sculpted household costume candidate; not final period approval'},indent=2)+'\n')
