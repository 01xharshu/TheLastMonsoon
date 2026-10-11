"""Build a coherent diagonal cotton panel over the retained fitted blouse.

Retain the complete blouse in the editable source. Exclude only its covered
cloth faces from runtime to avoid overlapping cloth surfaces; the complete MPFB
body and opaque foundation remain unchanged in source and runtime.
"""
import bpy,sys
from mathutils.bvhtree import BVHTree
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from river_asset_export import export_river_asset
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/river_woman/river_woman_motion.blend'))
bpy.context.preferences.filepaths.save_version=0
rig=bpy.data.objects['village_woman_rig'];rig.animation_data_clear();rig.data.pose_position='REST'
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
upper=bpy.data.objects.get('Retained complete fitted cotton blouse') or bpy.data.objects['Fitted cotton upper base']
old=bpy.data.objects['Woven sari pallu over blouse'];material=old.data.materials[0]
upper.data.calc_loop_triangles();basis=upper.data.shape_keys.key_blocks['Basis']
all_faces=[tuple(face.vertices) for face in upper.data.loop_triangles];panel=[];visible=[];selected_polygons=set()
for polygon in upper.data.polygons:
    p=sum((basis.data[i].co for i in polygon.vertices),Vector())/len(polygon.vertices)
    if .84<p.z<1.245 and p.y<.005 and abs(p.x-(.14-(p.z-.85)*.29/.39))<.105:selected_polygons.add(polygon.index)
for face in upper.data.loop_triangles:
    (panel if face.polygon_index in selected_polygons else visible).append(tuple(face.vertices))
if not panel or not visible:raise RuntimeError('Missing diagonal panel or visible blouse support')

def piece(name,faces,mat):
    ids=sorted({i for face in faces for i in face});mapping={i:j for j,i in enumerate(ids)}
    mesh=bpy.data.meshes.new(name+' coherent support')
    mesh.from_pydata([basis.data[i].co for i in ids],[],[tuple(mapping[i] for i in face) for face in faces]);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    obj.parent=upper.parent;obj.matrix_parent_inverse=upper.matrix_parent_inverse.copy();obj.matrix_basis=upper.matrix_basis.copy()
    for group in upper.vertex_groups:obj.vertex_groups.new(name=group.name)
    for j,i in enumerate(ids):
        for group in upper.data.vertices[i].groups:obj.vertex_groups[group.group].add([j],group.weight,'REPLACE')
    obj.modifiers.new('Original MPFB skin weights','ARMATURE').object=rig
    mesh.materials.append(mat)
    for face in mesh.polygons:face.use_smooth=True
    for source in upper.data.shape_keys.key_blocks:
        key=obj.shape_key_add(name=source.name,from_mix=False)
        for j,i in enumerate(ids):key.data[j].co=source.data[i].co
        key.value=0
    obj['body_source']='Complete unchanged MPFB body and opaque foundation retained'
    obj['river_layer_construction']='Coherent fitted support; only covered blouse cloth faces suppressed in runtime'
    return obj
for name in ['Fitted cotton upper base','Woven sari pallu over blouse']:
    obj=bpy.data.objects.get(name)
    if obj is not None and obj!=upper:bpy.data.objects.remove(obj,do_unlink=True)
upper.name='Retained complete fitted cotton blouse';upper['river_source_only']=True
upper.hide_render=True;upper.hide_set(True)
for key in upper.data.shape_keys.key_blocks:key.value=0
# Retopologize only the runtime cloth basis. The complete detailed original
# blouse and every original corrective remain retained in the source.
temporary=upper.copy();temporary.data=upper.data.copy();bpy.context.collection.objects.link(temporary)
temporary.hide_set(False);temporary.hide_render=False;temporary.shape_key_clear();temporary.modifiers.clear()
decimate=temporary.modifiers.new('Remove skin-detail cloth slivers','DECIMATE');decimate.ratio=.35;decimate.use_collapse_triangulate=True
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
mesh=bpy.data.meshes.new_from_object(temporary.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
bpy.data.objects.remove(temporary,do_unlink=True)
blouse=bpy.data.objects.new('Fitted cotton upper base',mesh);bpy.context.collection.objects.link(blouse)
blouse.parent=upper.parent;blouse.matrix_parent_inverse=upper.matrix_parent_inverse.copy();blouse.matrix_basis=upper.matrix_basis.copy()
for group in upper.vertex_groups:blouse.vertex_groups.new(name=group.name)
blouse.modifiers.new('Original MPFB skin weights','ARMATURE').object=rig
points=[vertex.co.copy() for vertex in basis.data];tree=BVHTree.FromPolygons(points,all_faces,all_triangles=True)
bindings=[]
for vertex in mesh.vertices:
    near,_,face_index,_=tree.find_nearest(vertex.co);a,b,c=all_faces[face_index]
    left=points[b]-points[a];right=points[c]-points[a];offset=near-points[a]
    den=left.dot(left)*right.dot(right)-left.dot(right)**2
    u=(right.dot(right)*offset.dot(left)-left.dot(right)*offset.dot(right))/max(den,1e-16)
    v=(left.dot(left)*offset.dot(right)-left.dot(right)*offset.dot(left))/max(den,1e-16)
    bindings.append((a,b,c,1-u-v,u,v,vertex.co-near))
for source in upper.data.shape_keys.key_blocks:
    key=blouse.shape_key_add(name=source.name,from_mix=False)
    for i,(a,b,c,wa,wb,wc,delta) in enumerate(bindings):key.data[i].co=source.data[a].co*wa+source.data[b].co*wb+source.data[c].co*wc+delta
    key.value=0
blouse['river_source_only']=False;blouse['river_composite']=True
print('RIVER_CLOTH_RETOPO',len(blouse.data.vertices),len(blouse.data.polygons),flush=True)
selected_polygons=set()
for polygon in blouse.data.polygons:
    p=sum((blouse.data.shape_keys.key_blocks['Basis'].data[i].co for i in polygon.vertices),Vector())/len(polygon.vertices)
    if .84<p.z<1.245 and p.y<.005 and abs(p.x-(.14-(p.z-.85)*.29/.39))<.105:selected_polygons.add(polygon.index)
runtime_material=upper.data.materials[0].copy();runtime_material.name='River coherent cotton regions'
runtime_material.use_nodes=True
vertex_color=runtime_material.node_tree.nodes.new('ShaderNodeVertexColor');vertex_color.layer_name='River panel mask'
shader=runtime_material.node_tree.nodes.get('Principled BSDF')
runtime_material.node_tree.links.new(vertex_color.outputs['Color'],shader.inputs['Base Color'])
blouse.data.materials.clear();blouse.data.materials.append(runtime_material)
mask=blouse.data.color_attributes.get('River panel mask') or blouse.data.color_attributes.new(name='River panel mask',type='FLOAT_COLOR',domain='CORNER')
blouse.data.color_attributes.active_color_index=list(blouse.data.color_attributes).index(mask)
blouse.data.color_attributes.render_color_index=blouse.data.color_attributes.active_color_index
for polygon in blouse.data.polygons:
    polygon.material_index=0
    for index in polygon.loop_indices:mask.data[index].color=(1,0,0,1) if polygon.index in selected_polygons else (0,0,0,1)
blouse['river_layer_construction']='One coherent skinned fabric surface; blouse/pallu regions carried by face-corner mask; complete separate garments retained in editable source'
pallu=piece('Woven sari pallu over blouse',panel,material)
pallu['river_source_only']=True;pallu.hide_render=True;pallu.hide_set(True)
export_river_asset(ROOT,rig,bpy.data.objects['village_woman_MakeHuman_body'],len(bpy.data.objects['Opaque fitted bra and thong foundation'].data.polygons))
print('RIVER_PALLU_REBUILT panel_triangles',len(panel),'visible_blouse_triangles',len(visible),'retained_complete_triangles',len(all_faces),flush=True)
