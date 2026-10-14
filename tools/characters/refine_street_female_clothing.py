"""Refine retained MPFB street clothing; preserve complete source garments/body."""
import bpy,sys,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from whole_body_contract import retain_complete_body
from street_female_garments import smooth_hems,natural_hairline,back_tail
import numpy as np

def refine(index):
 slug=f'female_{index+1:02d}';folder=ROOT/'WorkingAssets/NPCs/indian_street_variants'/slug
 bpy.ops.wm.open_mainfile(filepath=str(folder/f'{slug}.blend'))
 bpy.context.preferences.filepaths.save_version=0
 rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='REST'
 body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
 retain_complete_body(body)
 old=bpy.data.objects.get('Street coherent cotton blouse and pallu')
 if old:bpy.data.objects.remove(old,do_unlink=True)
 blouse=bpy.data.objects['Fitted cotton upper base'];pallu=bpy.data.objects['Woven sari pallu over blouse']
 garment=blouse.copy();garment.data=blouse.data.copy();bpy.context.collection.objects.link(garment)
 garment.name='Street coherent cotton blouse and pallu';garment['street_source_only']=False;garment.hide_render=False;garment.hide_set(False)
 if garment.data.shape_keys:garment.shape_key_clear()
 bpy.ops.object.select_all(action='DESELECT');garment.select_set(True);bpy.context.view_layer.objects.active=garment
 # Simplify the cloth's inherited sliver folds, never the human body.
 modifier=garment.modifiers.new('Regularise cotton panels','DECIMATE');modifier.ratio=.60
 bpy.ops.object.modifier_apply(modifier=modifier.name)
 # Smooth cloth-only sliver folds without moving boundary cuffs/neckline.
 edges=np.asarray([tuple(e.vertices) for e in garment.data.edges],dtype=np.int32)
 neighbours=np.concatenate([edges,edges[:,::-1]])
 counts=np.bincount(neighbours[:,0],minlength=len(garment.data.vertices))
 points=np.asarray([v.co[:] for v in garment.data.vertices],dtype=float)
 for iteration in range(4):
  total=np.zeros_like(points);np.add.at(total,neighbours[:,0],points[neighbours[:,1]])
  points+=(total/np.maximum(counts[:,None],1)-points)*.18
 for vertex,point in zip(garment.data.vertices,points):vertex.co=point
 garment.data.update();smooth_hems(garment)
 material=blouse.data.materials[0].copy();material.name='Street connected cotton regions'
 material.diffuse_color=(1,1,1,1)
 if material.use_nodes:
  bsdf=next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
  for link in list(bsdf.inputs['Base Color'].links):material.node_tree.links.remove(link)
  color_node=material.node_tree.nodes.new('ShaderNodeVertexColor');color_node.layer_name='StreetCotton'
  material.node_tree.links.new(color_node.outputs['Color'],bsdf.inputs['Base Color'])
 garment.data.materials.clear();garment.data.materials.append(material)
 for attribute in list(garment.data.color_attributes):garment.data.color_attributes.remove(attribute)
 colours=garment.data.color_attributes.new(name='StreetCotton',type='FLOAT_COLOR',domain='POINT')
 garment.data.color_attributes.active_color_index=0;garment.data.color_attributes.render_color_index=0
 blouse_tint=[(.30,.25,.11),(.42,.32,.22),(.36,.18,.14),(.23,.25,.16)][index]
 sari_tint=[(.31,.115,.105),(.12,.19,.29),(.25,.28,.13),(.39,.23,.11)][index]
 for vertex in garment.data.vertices:
  point=vertex.co;centre=.14-(point.z-.85)*.29/.39;width=[.125,.105,.16,.085][index]
  edge=min(point.z-.83,1.34-point.z,.02-point.y,width-abs(point.x-centre))
  if point.y>=.02 and point.z>1.22:edge=min(point.z-1.22,1.34-point.z,.11-abs(point.x+.125))
  region=max(0,min(1,edge/.015+.5))
  colours.data[vertex.index].color=tuple(a*(1-region)+b*region for a,b in zip(blouse_tint,sari_tint))+(1,)
 for face in garment.data.polygons:
  point=sum((garment.data.vertices[i].co for i in face.vertices),Vector())/len(face.vertices)
  centre=.14-(point.z-.85)*.29/.39
  width=[.125,.105,.16,.085][index]
  face.material_index=0
  face.use_smooth=True
 garment['construction']='Connected cotton surface and a separate fitted shoulder tail; complete separate originals retained source-only'
 natural_hairline(index)
 back_tail(rig,body,index,pallu.data.materials[0])
 for original in [blouse,pallu]:original.hide_render=True;original.hide_set(True);original['street_source_only']=True
 bpy.ops.wm.save_as_mainfile(filepath=str(folder/f'{slug}.blend'))
 # Export the unchanged full human volume; exclude only MPFB helpers.
 dg=bpy.context.evaluated_depsgraph_get();mesh=bpy.data.meshes.new_from_object(body.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
 cutout=bpy.data.objects.new(body.name+'_export_cutout',mesh);bpy.context.collection.objects.link(cutout)
 for group in body.vertex_groups:cutout.vertex_groups.new(name=group.name)
 cutout.parent=rig;cutout.matrix_parent_inverse=body.matrix_parent_inverse.copy();cutout.matrix_basis=body.matrix_basis.copy()
 cutout.modifiers.new('Original MPFB rig','ARMATURE').object=rig
 bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
 for obj in bpy.data.objects:
  if obj.type=='MESH' and obj!=body and not obj.get('street_source_only',False):obj.select_set(True)
 bpy.context.view_layer.objects.active=rig
 bpy.ops.export_scene.gltf(filepath=str(ROOT/'characters/npcs/street_residents'/f'{slug}.glb'),export_format='GLB',use_selection=True,export_animations=False,export_skins=True,export_all_influences=True,export_cameras=False,export_lights=False,export_morph=False)
 import struct
 exported=(ROOT/'characters/npcs/street_residents'/f'{slug}.glb').read_bytes();chunk_size=struct.unpack_from('<I',exported,12)[0];document=json.loads(exported[20:20+chunk_size])
 if not any(n.get('name')=='Street coherent cotton blouse and pallu' and 'mesh' in n for n in document['nodes']):raise RuntimeError('Refined cotton garment missing from runtime export')
 report=json.loads((folder/'manifest.json').read_text());report['clothing_construction']=garment['construction'];report['visual_approved']=False;report['wardrobe']=['broad shoulder-wrap cotton sari','plain work sari with narrow shoulder wrap','wide folded shoulder-wrap sari','narrow side-wrap cotton sari'][index]
 (folder/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
 print('STREET_CLOTHING_REFINED',slug,'body',len(body.data.vertices),'cloth',len(garment.data.vertices),flush=True)
indices=[int(sys.argv[sys.argv.index('--identity-index')+1])] if '--identity-index' in sys.argv else range(4)
for index in indices:refine(index)
