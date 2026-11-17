"""Fit replacement cotton and foundation to the unchanged complete adult MPFB body.

Original river Blender source/export remain retained and are never overwritten.
"""
import bpy, math, json, hashlib
from mathutils import Vector
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DONOR=ROOT/'characters/npcs/motion/river_woman/river_woman_rigged_candidate.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(DONOR))
bpy.context.preferences.filepaths.save_version=0
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
rig.data.pose_position='REST'
for key in body.data.shape_keys.key_blocks:key.value=0
body_before=[tuple(v.co) for v in body.data.vertices]
waist_repaired=0
for vertex in body.data.vertices:
    p=body.matrix_world@vertex.co
    if not (.735<p.z<.84) or abs(p.x)>.25:continue
    old={body.vertex_groups[g.group].name:g.weight for g in vertex.groups}
    if sum(w for name,w in old.items() if any(part in name.lower() for part in ['arm','hand','index','middle','ring','pinky','thumb']))>.05:continue
    t=max(0.0,min(1.0,(p.z-.735)/.05));t=t*t*(3-2*t)
    transfer=0.0
    for name,weight in old.items():
        if name.startswith('thigh_'):
            transfer+=weight*t;body.vertex_groups[name].add([vertex.index],weight*(1-t),'REPLACE')
    if transfer>1e-6:
        body.vertex_groups['pelvis'].add([vertex.index],old.get('pelvis',0.0)+transfer,'REPLACE');waist_repaired+=1
body['waist_skinning']='Pelvic skin above the hip crease no longer follows the femur; rest coordinates and topology unchanged'
body['complete_runtime_body']=True
body['authoritative_physique']='Unchanged imported original MPFB river woman; original parametric Blender source retained'
for obj in list(bpy.data.objects):
    if obj.type=='MESH' and any(word in obj.name for word in ['Fitted cotton upper','Opaque fitted bra','Wrapped sari','Sari lower border','Woven sari']):bpy.data.objects.remove(obj,do_unlink=True)
points=[body.matrix_world@v.co for v in body.data.vertices]
weights=[{body.vertex_groups[g.group].name:g.weight for g in v.groups} for v in body.data.vertices]
body.data.calc_loop_triangles()
def material(label,color):
    mat=bpy.data.materials.new(label);mat.diffuse_color=(*color,1);mat.use_nodes=True
    shader=mat.node_tree.nodes['Principled BSDF'];shader.inputs['Base Color'].default_value=(*color,1);shader.inputs['Roughness'].default_value=.98
    return mat
def surface(label,accepted,clearance,mat):
    triangles=[tuple(t.vertices) for t in body.data.loop_triangles if all(accepted(i) for i in t.vertices)]
    ids=sorted({i for face in triangles for i in face});mapping={i:j for j,i in enumerate(ids)}
    inverse=rig.matrix_world.inverted();normal_basis=body.matrix_world.to_3x3().inverted().transposed()
    coords=[]
    for i in ids:
        normal=(normal_basis@body.data.vertices[i].normal).normalized()
        coords.append(inverse@(points[i]+normal*clearance))
    mesh=bpy.data.meshes.new(label+' fitted fabric');mesh.from_pydata(coords,[],[tuple(mapping[i] for i in t) for t in triangles]);mesh.update()
    obj=bpy.data.objects.new(label,mesh);bpy.context.collection.objects.link(obj);obj.parent=rig
    for j,i in enumerate(ids):
        for name,weight in weights[i].items():
            if name in rig.data.bones:(obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)).add([j],weight,'REPLACE')
    obj['body_vertex_bindings']=ids
    obj['body_clearance_m']=clearance
    obj.modifiers.new('Same complete MPFB body weights','ARMATURE').object=rig
    mesh.materials.append(mat)
    for face in mesh.polygons:face.use_smooth=True
    return obj
def arm_weight(index):return sum(value for name,value in weights[index].items() if any(part in name.lower() for part in ['arm','hand','index','middle','ring','pinky','thumb']))
def upper(index):
    p=points[index]
    forearm=sum(value for name,value in weights[index].items() if any(part in name.lower() for part in ['lowerarm','hand','index','middle','ring','pinky','thumb']))
    return .94<p.z<1.235 and forearm<.08 and arm_weight(index)<.10
def foundation(index):
    p=points[index]
    if arm_weight(index)>.05:return False
    top=(1.005<p.z<1.17 and abs(p.x)<.205) or (1.15<p.z<1.23 and .105<abs(p.x)<.14)
    # A thong front tapers into the crotch instead of covering the inner
    # thigh fold. The narrow upper band sits above the hip flexion crease.
    front_width=.015+.030*max(0.0,min(1.0,(p.z-.64)/.175))
    bottom=(.805<p.z<.83 and abs(p.x)<.19) or (.64<p.z<.815 and ((p.y<-.025 and abs(p.x)<front_width) or (p.y>=-.025 and abs(p.x)<.025)))
    return top or bottom
blouse=surface('Fitted cotton upper base',upper,.012,material('River cotton blouse',(.27,.23,.12)))
def pallu(index):
    p=points[index]
    center=.14-(p.z-.85)*.29/.39
    return upper(index) and p.y<.005 and .83<p.z<1.235 and abs(p.x-center)<.14
panel=surface('Woven sari pallu over blouse',pallu,.055,material('River cotton shoulder wrap',(.31,.115,.105)))
panel['activity_source_only']=True;panel.hide_render=True;panel.hide_set(True)
# One sewn runtime surface keeps the front cotton wrap and blouse boundary
# coherent under every corrective. The complete separate garments remain
# recoverable in the original source and the outer panel remains editable here.
colors=blouse.data.color_attributes.new(name='Cotton region',type='FLOAT_COLOR',domain='CORNER')
for polygon in blouse.data.polygons:
    point=sum((blouse.data.vertices[i].co for i in polygon.vertices),Vector())/len(polygon.vertices)
    center=.14-(point.z-.85)*.29/.39
    mask=1.0 if point.y<.005 and .83<point.z<1.235 and abs(point.x-center)<.14 else 0.0
    for loop in polygon.loop_indices:colors.data[loop].color=(mask,0,0,1)
blouse['river_composite']=True
under=surface('Opaque fitted bra and thong foundation',foundation,.003,material('Opaque foundation',(.30,.24,.17)))
# Retained leg-envelope controller deforms this continuous wrap in game. The
# editable source carries its real construction and original MPFB attachment.
for label,lo,hi,rows in [('Wrapped sari lower drape',.020,.95,20),('Sari lower border',.020,.050,2)]:
    vertices=[];faces=[];segments=40
    for row in range(rows+1):
        t=row/rows
        for i in range(segments):
            theta=math.tau*i/segments
            vertices.append((math.cos(theta)*(.205+.055*t),-math.sin(theta)*(.165+.095*t),hi+(lo-hi)*t))
    for row in range(rows):
        for i in range(segments):
            a=row*segments+i;b=row*segments+(i+1)%segments;faces.append((b,b+segments,a+segments,a))
    mesh=bpy.data.meshes.new(label+' construction');mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(label,mesh);bpy.context.collection.objects.link(obj);obj.parent=rig
    obj.vertex_groups.new(name='pelvis').add(list(range(len(vertices))),1,'REPLACE');obj.modifiers.new('Editable MPFB attachment','ARMATURE').object=rig
    mesh.materials.append(material(label+' cotton',(.31,.115,.105)))
    for polygon in mesh.polygons:polygon.use_smooth=True
import sys
sys.path.insert(0,str(ROOT/'tools/characters'))
from fabric_uvs import ensure_fabric_uvs
for obj in bpy.data.objects:
    if obj.type=='MESH':ensure_fabric_uvs(obj)
assert body_before==[tuple(v.co) for v in body.data.vertices]
out=ROOT/'WorkingAssets/NPCs/river_activity';out.mkdir(parents=True,exist_ok=True)
source=out/'river_activity.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(source))
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in bpy.data.objects:
    if obj.type=='MESH' and not obj.get('activity_source_only',False):obj.select_set(True)
rig.data.pose_position='POSE';bpy.context.view_layer.objects.active=rig
runtime=ROOT/'characters/npcs/activity_people/river_activity.glb'
bpy.ops.export_scene.gltf(filepath=str(runtime),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,export_cameras=False,export_lights=False,export_yup=True,export_skins=True,export_all_influences=True,export_apply=False,export_morph_normal=False,export_morph_tangent=False,export_vertex_color='ACTIVE')
report=dict(source=str(source.relative_to(ROOT)),runtime=str(runtime.relative_to(ROOT)),donor=str(DONOR.relative_to(ROOT)),donor_sha256=hashlib.sha256(DONOR.read_bytes()).hexdigest(),original_mpfb_source='WorkingAssets/NPCs/river_woman/river_woman_motion.blend',complete_body_vertices=len(body.data.vertices),body_rest_coordinates_unchanged=True,waist_skinning_vertices_repaired=waist_repaired,foundation_vertices=len(under.data.vertices),visual_approved=False)
(out/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print('RIVER_ACTIVITY_ASSET',json.dumps(report),flush=True)
