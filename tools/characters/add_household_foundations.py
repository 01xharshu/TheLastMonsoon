"""Add separate opaque foundation clothing to existing MPFB residents; never cut bodies."""
import bpy,sys,json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from whole_body_contract import retain_complete_body
role=sys.argv[sys.argv.index('--')+1]
source=ROOT/(f'WorkingAssets/NPCs/households/{role}/{role}.blend' if role!='official' else 'WorkingAssets/NPCs/british/official_pair/official_pair_mpfb_candidate.blend')
donor=None
if role.startswith('staff_'):
 slug='village_woman' if role=='staff_woman' else 'village_farmer'
 donor=ROOT/f'WorkingAssets/NPCs/{slug}/{slug}_motion_candidate.blend'
 source=ROOT/f'WorkingAssets/NPCs/households/{role}/{role}.blend'
 source.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(donor or source));bpy.context.preferences.filepaths.save_version=0
bodies=[o for o in bpy.data.objects if o.type=='MESH' and (o.name.endswith('MakeHuman_body') or o.name.endswith('MPFB_body'))]
report=[]
for body in bodies:
 retain_complete_body(body)
 # Derived household meshes already baked helper exclusion before restoration.
 # Their inherited mask group indices no longer describe the restored topology.
 if body.get('restoration') and len(body.data.vertices)==14517:
  for modifier in body.modifiers:
   if modifier.type=='MASK':modifier.show_viewport=False;modifier.show_render=False
 rig=next(m.object for m in body.modifiers if m.type=='ARMATURE');rig.data.pose_position='REST'
 name=body.name+'_Opaque foundation shorts'
 if name in bpy.data.objects:bpy.data.objects.remove(bpy.data.objects[name],do_unlink=True)
 for m in body.modifiers:
  if m.type=='ARMATURE':m.show_viewport=False
 bpy.context.view_layer.update()
 mesh=bpy.data.meshes.new_from_object(body.evaluated_get(bpy.context.evaluated_depsgraph_get()),preserve_all_data_layers=True,depsgraph=bpy.context.evaluated_depsgraph_get())
 for m in body.modifiers:
  if m.type=='ARMATURE':m.show_viewport=True
 hip=rig.data.bones['pelvis'].head_local.z
 forbidden={g.index for g in body.vertex_groups if g.name.startswith(('upperarm_','lowerarm_','hand_','thumb_','index_','middle_','ring_','pinky_'))}
 allowed={v.index for v in mesh.vertices if hip-.24<v.co.z<hip+.13 and sum(g.weight for g in v.groups if g.group in forbidden)<.15}
 faces=[list(p.vertices) for p in mesh.polygons if all(i in allowed for i in p.vertices)]
 used=sorted({i for f in faces for i in f});mapping={i:j for j,i in enumerate(used)}
 cloth=bpy.data.meshes.new(name);cloth.from_pydata([tuple(mesh.vertices[i].co+mesh.vertices[i].normal*.008) for i in used],[],[[mapping[i] for i in f] for f in faces]);cloth.update()
 obj=bpy.data.objects.new(name,cloth);bpy.context.collection.objects.link(obj)
 obj.parent=body.parent;obj.matrix_parent_inverse=body.matrix_parent_inverse.copy();obj.matrix_basis=body.matrix_basis.copy()
 for g in body.vertex_groups:obj.vertex_groups.new(name=g.name)
 for original,index in mapping.items():
  for g in mesh.vertices[original].groups:obj.vertex_groups[g.group].add([index],g.weight,'REPLACE')
 obj.modifiers.new('MPFB foundation skin','ARMATURE').object=rig
 mat=bpy.data.materials.new(name+' opaque cotton');mat.diffuse_color=(.24,.20,.15,1);mat.use_nodes=True
 bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=mat.diffuse_color;bs.inputs['Roughness'].default_value=.85
 cloth.materials.append(mat)
 for p in cloth.polygons:p.use_smooth=True
 obj['construction']='Separate opaque foundation garment over complete MPFB body; body topology unchanged'
 report.append({'body':body.name,'body_evaluated_vertices':len(mesh.vertices),'foundation_vertices':len(cloth.vertices),'foundation_faces':len(faces)})
 assert len(faces)>100
bpy.ops.wm.save_as_mainfile(filepath=str(source))
if role!='official':
 bpy.ops.export_scene.gltf(filepath=str(ROOT/f'characters/npcs/households/{role}.glb'),export_format='GLB',export_skins=True,export_animations=False,export_cameras=False,export_lights=False)
(ROOT/f'docs/world/household_foundation_{role}.json').write_text(json.dumps({'source':str(source.relative_to(ROOT)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'bodies':report,'scope':'source full-body masks disabled and separate opaque foundations; clothing fit requires rendered review'},indent=2)+'\n')
