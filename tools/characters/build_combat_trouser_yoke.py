"""Tailor a flexible crotch/waist yoke over the current complete MPFB body."""
import bpy,bmesh,hashlib,json
from mathutils import Vector
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'WorkingAssets/Arjun/combat_clothing';OUT.mkdir(parents=True,exist_ok=True)
source_body=ROOT/'characters/arjun/arjun.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source_body))
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_Body' in o.name)
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
rig.data.pose_position='REST';bpy.context.view_layer.update()
for modifier in body.modifiers:
 if modifier.type=='MASK':modifier.show_viewport=False;modifier.show_render=False
body['provenance']='Unchanged full MakeHuman/MPFB body from live Arjun GLB; original editable body remains in candidate sources'
def garment(name,lower,upper,clearance,color):
 cloth=body.copy();cloth.data=body.data.copy();cloth.name=name;bpy.context.collection.objects.link(cloth)
 groups={g.index for g in cloth.vertex_groups if g.name.startswith(('pelvis','thigh_','spine_01'))}
 arms={g.index for g in cloth.vertex_groups if g.name.startswith(('upperarm_','lowerarm_','hand_'))}
 keep=[v.index for v in cloth.data.vertices if lower<(cloth.matrix_world@v.co).z<upper
       and sum(g.weight for g in v.groups if g.group in groups)>.2
       and sum(g.weight for g in v.groups if g.group in arms)<.01]
 group=cloth.vertex_groups.new(name='Garment panel');group.add(keep,1,'REPLACE')
 modifier=cloth.modifiers.new('Cut garment panel only','MASK');modifier.vertex_group=group.name
 normals=[v.normal.copy() for v in cloth.data.vertices]
 for v,normal in zip(cloth.data.vertices,normals):
  co=cloth.matrix_world@v.co
  ease=(.008 if co.z>.98 else (.035 if .65<co.z<.94 and abs(co.x)<.16 and co.y<.015 else clearance)) if name.startswith("Trouser") else clearance
  v.co+=normal*ease
 material=bpy.data.materials.new(name+' opaque cloth');material.use_nodes=True
 material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1)
 material.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.93
 cloth.data.materials.clear();cloth.data.materials.append(material)
 return cloth
foundation=garment('Combat opaque foundation',.77,1.02,.005,(.18,.14,.11))
yoke=garment('Trouser fitted waist and crotch yoke',.40,1.18,.022,(.76,.72,.62))
for obj in list(bpy.data.objects):
 if obj.type=='MESH' and obj not in {body,foundation,yoke}:bpy.data.objects.remove(obj,do_unlink=True)
rig.animation_data_clear()
source=OUT/'upper_trouser_yoke.blend';bpy.ops.wm.save_as_mainfile(filepath=str(source))
# Bake garment cutouts at rest, retaining all original body surfaces in source.
for original in [foundation,yoke]:
 bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
 mesh=bpy.data.meshes.new_from_object(original.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
 # Cut the garment edges continuously rather than following body vertex rows.
 if original == yoke:
  bm=bmesh.new();bm.from_mesh(mesh)
  inverse=original.matrix_world.inverted()
  normal=original.matrix_world.to_3x3().transposed()@Vector((0,0,1))
  for height,lower in [(.425,True),(1.15,False)]:
   bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
    plane_co=inverse@Vector((0,0,height)),plane_no=normal,
    clear_inner=lower,clear_outer=not lower,dist=0.00001)
  bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
  bm.to_mesh(mesh);bm.free();mesh.update()
 exported=bpy.data.objects.new(original.name+' export',mesh);bpy.context.collection.objects.link(exported)
 for group in original.vertex_groups:exported.vertex_groups.new(name=group.name)
 exported.parent=rig;exported.matrix_parent_inverse=original.matrix_parent_inverse.copy();exported.matrix_basis=original.matrix_basis.copy()
 exported.modifiers.new('Rig','ARMATURE').object=rig
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in bpy.data.objects:
 if obj.type=='MESH' and obj.name.endswith(' export'):obj.select_set(True)
bpy.context.view_layer.objects.active=rig
runtime=ROOT/'characters/arjun/combat_trouser_yoke.glb'
bpy.ops.export_scene.gltf(filepath=str(runtime),export_format='GLB',use_selection=True,export_animations=False,export_apply=False)
(OUT/'manifest.json').write_text(json.dumps(dict(source=str(source.relative_to(ROOT)),runtime=str(runtime.relative_to(ROOT)),source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),runtime_sha256=hashlib.sha256(runtime.read_bytes()).hexdigest(),fitting_body_sha256=hashlib.sha256(source_body.read_bytes()).hexdigest(),complete_body_retained_in_source=True,source_body_vertices=len(body.data.vertices),visual_approved=False),indent=2)+'\n')
