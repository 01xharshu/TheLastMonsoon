"""Fit Sergeant accoutrements and author glTF-compatible textile surfaces."""
import bpy, bmesh, math, json, hashlib, random
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'WorkingAssets/NPCs/british/sergeant_pair/sergeant_pair_mpfb_candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
body=bpy.data.objects['Sergeant_MPFB_body']
def digest():
    return hashlib.sha256(b''.join(float(c).hex().encode() for v in body.data.vertices for c in v.co)).hexdigest()
body_before=digest()
cloth=bpy.data.objects['Sergeant_fitted_cloth_base']
# Work in the existing garment's local rest space; accessory meshes share it.
assert cloth.matrix_basis.is_identity
rig=body.parent
rig.data.pose_position='REST'
bpy.context.view_layer.update()
evaluated=cloth.evaluated_get(bpy.context.evaluated_depsgraph_get())
outer=evaluated.to_mesh()
bvh=BVHTree.FromPolygons([v.co for v in outer.vertices], [list(p.vertices) for p in outer.polygons])
evaluated.to_mesh_clear()
tree=KDTree(len(cloth.data.vertices))
for v in cloth.data.vertices: tree.insert(v.co,v.index)
tree.balance()
cloth.data.calc_loop_triangles()
triangles=[tuple(t.vertices) for t in cloth.data.loop_triangles]
weight_bvh=BVHTree.FromPolygons([v.co for v in cloth.data.vertices],triangles,all_triangles=True)
weights={v.index:{cloth.vertex_groups[g.group].name:g.weight for g in v.groups} for v in cloth.data.vertices}
report=[]
for obj in list(bpy.data.objects):
    if not ('sergeant' in obj.name.lower() and ('crossbelt' in obj.name.lower() or 'chevron' in obj.name.lower())): continue
    if 'chevron' in obj.name.lower():
        # Place rank lace at mid upper sleeve rather than the original elbow.
        sign=-1 if ' -1 ' in obj.name else 1
        candidates=[bone for bone in rig.data.bones if bone.name in ('upperarm_l','upperarm_r')]
        bone=min(candidates,key=lambda bone: abs(bone.head_local.x-sign*.3))
        centre=bone.head_local.lerp(bone.tail_local,.48)
        old_centre=sum((v.co for v in obj.data.vertices),Vector())/len(obj.data.vertices)
        stripe=int(obj.name.rsplit(' ',1)[1])-1
        for vertex in obj.data.vertices:
            vertex.co.x += centre.x-old_centre.x
            vertex.co.z += centre.z-old_centre.z-stripe*.025
    front='front' in obj.name.lower()
    back='back' in obj.name.lower()
    # A wide two-edge strip cuts through a curved chest between its edges.
    # Subdivide the authored topology before projecting every surface vertex.
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.subdivide_edges(bm,edges=list(bm.edges),cuts=3,use_grid_fill=True)
    bm.to_mesh(obj.data);bm.free()
    maximum=0
    obj.vertex_groups.clear()
    for v in obj.data.vertices:
        original=v.co.copy()
        if (front or back) and v.co.z < 1.20:
            v.co.x=max(-.14,min(.14,v.co.x))
        if front or back:
            start=Vector((v.co.x, -2 if front else 2, v.co.z))
            location,normal,face,_=bvh.ray_cast(start,Vector((0,1 if front else -1,0)),4)
        else:
            location,normal,face,_=bvh.find_nearest(v.co)
        if location is None:
            location,normal,face,_=bvh.find_nearest(v.co)
        assert location is not None
        # Bias to exterior instead of inheriting occasional reversed donor normals.
        if front and normal.y>0 or back and normal.y<0: normal=-normal
        v.co=location+normal*.006
        maximum=max(maximum,(v.co-original).length)
        point,_,triangle_index,_=weight_bvh.find_nearest(location)
        indices=triangles[triangle_index]
        a,b,c=[cloth.data.vertices[index].co for index in indices]
        u=b-a;w=c-a;q=point-a
        uu=u.dot(u);ww=w.dot(w);uw=u.dot(w)
        denominator=uu*ww-uw*uw
        second=(ww*q.dot(u)-uw*q.dot(w))/denominator if abs(denominator)>1e-12 else 0
        third=(uu*q.dot(w)-uw*q.dot(u))/denominator if abs(denominator)>1e-12 else 0
        factors=[max(0,1-second-third),max(0,second),max(0,third)]
        donor={}
        for index,factor in zip(indices,factors):
            for name,value in weights[index].items():donor[name]=donor.get(name,0)+factor*value
        total=sum(donor.values())
        for name,value in donor.items():
            (obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)).add([v.index],value/total,'REPLACE')
    obj['fitted_uniform_weights']=True
    report.append({'object':obj.name,'vertices':len(obj.data.vertices),'maximum_rest_refit_m':maximum,'rest_clearance_m':.006})
# Raster textile maps persist through glTF rather than the old procedural shader
# which the exporter flattened to a single color. Subtle, seamless periodic grain.
textures=ROOT/'WorkingAssets/NPCs/british/sergeant_uniform/textures'
textures.mkdir(parents=True,exist_ok=True)
random.seed(1857)
for slot_index,base,label,roughness in [(0,(.64,.20,.16),'scarlet_wool',.88),(1,(.28,.30,.34),'trouser_wool',.92)]:
    old=cloth.data.materials[slot_index]
    mat=bpy.data.materials.new('Sergeant '+label+' woven')
    mat.use_nodes=True;mat.diffuse_color=(*base,1)
    nodes=mat.node_tree.nodes;links=mat.node_tree.links;bs=nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value=roughness
    img=bpy.data.images.new(label+' albedo',width=256,height=256)
    pixels=[]
    for y in range(256):
        for x in range(256):
            grain=.99+.002*math.sin(x*math.pi/2)+.002*math.sin(y*math.pi/2)+random.uniform(-.004,.004)
            pixels.extend([min(1,c*grain) for c in base]+[1])
    img.pixels.foreach_set(pixels)
    img.filepath_raw=str(textures/(label+'.png'));img.file_format='PNG';img.save();img.pack()
    tex=nodes.new('ShaderNodeTexImage');tex.image=img
    links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    cloth.data.materials[slot_index]=mat
# Buff leather and brass response on existing details; no invented regiment badge.
for obj in bpy.data.objects:
    if obj.parent!=body.parent or obj.type!='MESH':continue
    for slot in obj.material_slots:
        if not slot.material or not slot.material.use_nodes:continue
        if 'crossbelt' in obj.name.lower() or 'chevron' in obj.name.lower():
            mat=slot.material.copy();mat.name='Sergeant buff leather' if 'crossbelt' in obj.name.lower() else 'Sergeant rank lace'
            mat.diffuse_color=(.68,.62,.48,1)
            bs=mat.node_tree.nodes.get('Principled BSDF')
            for link in list(bs.inputs['Base Color'].links):mat.node_tree.links.remove(link)
            bs.inputs['Base Color'].default_value=mat.diffuse_color
            bs.inputs['Roughness'].default_value=.73 if 'crossbelt' in obj.name.lower() else .9
            slot.material=mat
        elif 'button' in obj.name.lower():
            bs=slot.material.node_tree.nodes.get('Principled BSDF');bs.inputs['Metallic'].default_value=.75;bs.inputs['Roughness'].default_value=.34
rig.data.pose_position='POSE'
assert body_before==digest()
bpy.context.preferences.filepaths.save_version=0
target=ROOT/'WorkingAssets/NPCs/british/sergeant_uniform/sergeant_uniform.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(target))
manifest={'source':str(source.relative_to(ROOT)),'candidate':str(target.relative_to(ROOT)),'body_coordinates_unchanged':True,'accessory_refits':report,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'candidate_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'scope':'surface fit/material refinement; precise regimental pattern, dynamic penetration and full tailoring unapproved','live_applied':False}
(ROOT/'docs/characters/british/candidates/sergeant_uniform_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('SERGEANT_UNIFORM',json.dumps(manifest))
