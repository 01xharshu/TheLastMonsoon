"""Build isolated MPFB body and costume blockouts for the first British NPC pair.

Run: /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/characters/build_british_private_pair.py
No runtime export or approval is implied by this candidate builder.
"""
import bpy
import bmesh
import math
import json
import hashlib
from pathlib import Path
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "WorkingAssets/NPCs/british/private_pair"
REVIEW = ROOT / "docs/characters/british/candidates"
DATA = Path.home() / "Library/Application Support/Blender/5.2/extensions/.user/blender_org/mpfb/data"
OUT.mkdir(parents=True, exist_ok=True)
REVIEW.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
from bl_ext.blender_org.mpfb.services.humanservice import HumanService

def material(name, rgb, texture=None):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*rgb, 1)
    bs.inputs["Roughness"].default_value = .82
    if texture and texture.exists():
        image = m.node_tree.nodes.new("ShaderNodeTexImage")
        image.image = bpy.data.images.load(str(texture), check_existing=True)
        m.node_tree.links.new(image.outputs["Color"], bs.inputs["Base Color"])
    return m

def fabric_grain(mat, light, dark, scale=65):
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bs = nodes.get('Principled BSDF')
    coord = nodes.new('ShaderNodeTexCoord')
    noise = nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = scale
    noise.inputs['Detail'].default_value = 2
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = .27
    ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].position = .72
    ramp.color_ramp.elements[1].color = (*light, 1)
    bump = nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = .035
    bump.inputs['Distance'].default_value = .002
    links.new(coord.outputs['Generated'], noise.inputs['Vector'])
    links.new(noise.outputs['Fac'], ramp.inputs['Fac'])
    links.new(ramp.outputs['Color'], bs.inputs['Base Color'])
    links.new(noise.outputs['Fac'], bump.inputs['Height'])
    links.new(bump.outputs['Normal'], bs.inputs['Normal'])

def make_mesh(name, verts, faces, mat, rig, tree, weight_map, mode="nearest"):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    data.materials.append(mat)
    bm = bmesh.new(); bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data); bm.free()
    for polygon in data.polygons:
        polygon.use_smooth = True
    for vertex in data.vertices:
        if mode == "head":
            weights = {"head": 1.0}
        elif mode == "pelvis":
            weights = {"pelvis": 1.0}
        else:
            weights = {}
            for _, index, distance in tree.find_n(vertex.co, 4):
                factor = 1 / max(distance, .01) ** 2
                for bone, value in weight_map[index].items():
                    weights[bone] = weights.get(bone, 0) + value * factor
            total = sum(weights.values())
            weights = {name: value / total for name, value in weights.items()} if total else {"pelvis": 1.0}
        for bone, value in weights.items():
            if value > .001:
                (obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)).add([vertex.index], value, "REPLACE")
    obj.parent = rig
    obj.modifiers.new("Armature deformation", "ARMATURE").object = rig
    return obj

def rings(name, levels, mat, rig, tree, weights, mode="nearest", sides=24, folds=0):
    verts=[]
    for row, (z, rx, ry, cx, cy) in enumerate(levels):
        for j in range(sides):
            angle = math.tau * j / sides
            ripple = 1 + folds * math.cos(angle * 7 + row * .3)
            verts.append((cx + rx * ripple * math.cos(angle), cy + ry * ripple * math.sin(angle), z))
    faces=[]
    for row in range(len(levels)-1):
        for j in range(sides):
            nxt=(j+1)%sides
            faces.append((row*sides+j,row*sides+nxt,(row+1)*sides+nxt,(row+1)*sides+j))
    return make_mesh(name,verts,faces,mat,rig,tree,weights,mode)

def gathered_skirt(name, mat, rig, tree, weights):
    verts=[]
    sides=144
    rows=33
    for row in range(rows):
        t=row/(rows-1)
        z=.82-.75*t
        bell=math.sin(t*math.pi/2)**1.35
        radius=.215+.265*bell
        for j in range(sides):
            angle=math.tau*j/sides
            # Narrow gathered folds emerge from the waist and become deeper at
            # the hem, retaining a fabric silhouette rather than a cone.
            ripple=1+(.015+.055*bell)*math.cos(24*angle+.15*t)
            verts.append((radius*ripple*math.cos(angle),radius*.92*ripple*math.sin(angle),z))
    faces=[(row*sides+j,row*sides+(j+1)%sides,(row+1)*sides+(j+1)%sides,(row+1)*sides+j) for row in range(rows-1) for j in range(sides)]
    return make_mesh(name,verts,faces,mat,rig,tree,weights,'pelvis')

def garment_surface_y(garment, x, z, front=True):
    nearby = [v.co.y for v in garment.data.vertices if abs(v.co.x-x)<.035 and abs(v.co.z-z)<.045]
    if not nearby:
        nearby = [v.co.y for v in garment.data.vertices if abs(v.co.x-x)<.07 and abs(v.co.z-z)<.08]
    if not nearby:
        raise ValueError(f"No fitted garment surface at x={x:.3f}, z={z:.3f}")
    return (min(nearby)-.007) if front else (max(nearby)+.007)

def cloth_strip(name, path, width, mat, rig, tree, weights, garment, front=True):
    verts=[]
    for x,z in path:
        for xx in (x-width/2,x+width/2):
            y=garment_surface_y(garment,xx,z,front)
            verts.append((xx,y,z))
    faces=[(i*2,i*2+1,i*2+3,i*2+2) for i in range(len(path)-1)]
    obj=make_mesh(name,verts,faces,mat,rig,tree,weights)
    solid=obj.modifiers.new('Leather thickness','SOLIDIFY')
    solid.thickness=.003
    return obj

def accessory_box(name, location, dimensions, mat, rig, bone, bevel=.008):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj=bpy.context.object
    obj.name=name
    obj.dimensions=dimensions
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(mat)
    obj.parent=rig
    obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))),1,'REPLACE')
    obj.modifiers.new('Armature deformation','ARMATURE').object=rig
    if bevel:
        mod=obj.modifiers.new('Soft edges','BEVEL')
        mod.width=bevel
        mod.segments=2
        obj.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return obj

def create_person(slug, female, macro, skin_path):
    body = HumanService.create_human(macro_detail_dict=macro)
    body.name = slug + "_MPFB_body"
    body["source_workflow"] = "MakeHuman MPFB core body; isolated British NPC candidate"
    body["approval"] = "candidate only; costume, motion, and historical detail unapproved"
    rig = HumanService.add_builtin_rig(body,"game_engine",import_weights=True)
    rig.name = slug + "_game_engine_rig"
    skin = material(slug+" skin",(.72,.54,.43),skin_path)
    body.data.materials.clear();body.data.materials.append(skin)
    for poly in body.data.polygons: poly.material_index=0;poly.use_smooth=True
    eyes = HumanService.add_mhclo_asset(str(DATA/"eyes/low-poly/low-poly.mhclo"),body,asset_type="Eyes",subdiv_levels=0)
    eyes.name=slug+"_eyes"
    hair_name="short02" if female else "short04"
    hair = HumanService.add_mhclo_asset(str(DATA/f"hair/{hair_name}/{hair_name}.mhclo"),body,asset_type="Hair",subdiv_levels=0)
    hair.name=slug+"_hair"
    hair.data.materials.clear();hair.data.materials.append(material(slug+" brown hair",(.13,.085,.055)))
    shoe_slug = "shoes03" if female else "shoes04"
    shoes = HumanService.add_mhclo_asset(str(DATA/f"clothes/{shoe_slug}/{shoe_slug}.mhclo"),body,asset_type="Clothes",subdiv_levels=0)
    shoes.name = slug + "_shoes"
    shoes.data.materials.clear();shoes.data.materials.append(material(slug+" dark leather shoes",(.045,.037,.033)))
    outfit_slug = "female_elegantsuit01" if female else "male_casualsuit03"
    outfit = HumanService.add_mhclo_asset(str(DATA/f"clothes/{outfit_slug}/{outfit_slug}.mhclo"),body,asset_type="Clothes",subdiv_levels=0)
    outfit.name = slug + "_fitted_cloth_base"
    for mod in body.modifiers: mod.show_viewport = mod.type == "MASK"
    bpy.context.view_layer.update()
    source=bpy.data.meshes.new_from_object(body.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    body_group=body.vertex_groups["body"].index
    indices=[v.index for v in source.vertices if any(g.group==body_group for g in v.groups)]
    tree=KDTree(len(indices))
    for index in indices: tree.insert(source.vertices[index].co,index)
    tree.balance()
    names={group.index:group.name for group in body.vertex_groups}
    bone_names=set(rig.data.bones.keys())
    weights={index:{names[group.group]:group.weight for group in source.vertices[index].groups if names[group.group] in bone_names} for index in indices}
    bpy.data.meshes.remove(source)
    return body,rig,tree,weights,outfit

male_macro=dict(gender=1.0,age=.48,muscle=.44,weight=.48,proportions=.5,height=.53,cupsize=.5,firmness=.5,race=dict(asian=.02,caucasian=.96,african=.02))
female_macro=dict(gender=0.0,age=.39,muscle=.36,weight=.49,proportions=.5,height=.46,cupsize=.5,firmness=.5,race=dict(asian=.02,caucasian=.96,african=.02))
male_skin=DATA/"skins/middleage_caucasian_male/middleage_lightskinned_male_diffuse.png"
female_skin=DATA/"skins/young_caucasian_female/young_lightskinned_female_diffuse.png"
body,rig,tree,weights,male_outfit=create_person("Private",False,male_macro,male_skin)
woman,wr,wt,ww,female_outfit=create_person("Companion",True,female_macro,female_skin)
# MPFB creation clears orphan data blocks, so keep costume materials until both
# bodies and their assets have been constructed.
red=material("1857 study - red wool",(.46,.055,.038))
dark=material("Study - dark charcoal wool",(.055,.065,.08))
white=material("Study - white leather",(.76,.72,.61))
black=material("Study - black leather",(.035,.029,.025))
cotton=material("Study - cream printed cotton",(.70,.64,.51))
trim=material("Study - muted blue trim",(.27,.34,.37))
brass=material("Study - aged brass",(.47,.35,.15))
for mat, light, shade, scale in [(red,(.48,.067,.052),(.43,.045,.037),140),(dark,(.065,.073,.09),(.048,.054,.07),135),(cotton,(.73,.69,.61),(.68,.64,.56),175)]:
    fabric_grain(mat, light, shade, scale)

def recolor_outfit(obj, upper, lower):
    obj.data.materials.clear()
    obj.data.materials.append(upper)
    obj.data.materials.append(lower)
    parent = list(range(len(obj.data.vertices)))
    def find(index):
        while parent[index] != index:
            parent[index] = parent[parent[index]]
            index = parent[index]
        return index
    for edge in obj.data.edges:
        a, b = find(edge.vertices[0]), find(edge.vertices[1])
        parent[a] = b
    highest = {}
    for vertex in obj.data.vertices:
        root = find(vertex.index)
        highest[root] = max(highest.get(root, -1), vertex.co.z)
    for poly in obj.data.polygons:
        poly.material_index = 0 if highest[find(poly.vertices[0])] > 1.2 else 1
        poly.use_smooth = True
    solidify = obj.modifiers.new("Cloth shell", 'SOLIDIFY')
    solidify.thickness = .005
    solidify.offset = 1

recolor_outfit(male_outfit,red,dark)
recolor_outfit(female_outfit,cotton,cotton)
rings("Private forage cap",[(1.68,.137,.142,0,0),(1.70,.145,.147,0,0),(1.75,.143,.145,0,0),(1.765,.11,.115,0,0),(1.77,.005,.005,0,0)],dark,rig,tree,weights,"head",sides=32)
rings("Private cap band",[(1.685,.147,.149,0,0),(1.704,.148,.150,0,0)],red,rig,tree,weights,"head",sides=32)
accessory_box("Private forage cap visor",(0,-.149,1.685),(.20,.078,.009),black,rig,'head',.008)
for side in (-1,1):
    path=[(side*(.18-.36*t),1.43-.34*t) for t in (i/28 for i in range(29))]
    cloth_strip(f"Private front crossbelt {side}",path,.047,white,rig,tree,weights,male_outfit)
    cloth_strip(f"Private back crossbelt {side}",path,.047,white,rig,tree,weights,male_outfit,front=False)
for z in (1.15,1.23,1.31,1.39):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=.006, location=(0,garment_surface_y(male_outfit,0,z)-.005,z))
    button=bpy.context.object
    button.name=f"Private brass tunic button {z:.2f}"
    button.data.materials.append(brass)
    button.parent=rig
    button.vertex_groups.new(name='spine_02').add(list(range(len(button.data.vertices))),1,'REPLACE')
    button.modifiers.new('Armature deformation','ARMATURE').object=rig

# The MPFB adult body stays intact beneath separate opaque study garments.
gathered_skirt("Companion gathered skirt",cotton,wr,wt,ww)
rings("Companion gathered waistband",[(.795,.212,.192,0,0),(.825,.210,.190,0,0),(.842,.205,.187,0,0)],cotton,wr,wt,ww,"pelvis",sides=64,folds=.012)
rings("Companion bonnet crown",[(1.435,.134,.13,0,.035),(1.49,.145,.142,0,.035),(1.535,.125,.121,0,.035),(1.55,.005,.005,0,.035)],trim,wr,wt,ww,"head",sides=32)
rings("Companion bonnet brim",[(1.435,.15,.142,0,-.005),(1.45,.158,.148,0,-.005)],cotton,wr,wt,ww,"head",sides=32)

source_path=OUT/"private_pair_mpfb_candidate.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(source_path))
manifest={"status":"CANDIDATE_NOT_APPROVED","source":str(source_path.relative_to(ROOT)),"source_sha256":hashlib.sha256(source_path.read_bytes()).hexdigest(),"reference":"docs/characters/british/references/private_and_companion_multiview.png","male_body_vertices":len(body.data.vertices),"female_body_vertices":len(woman.data.vertices),"male_bones":len(rig.data.bones),"female_bones":len(wr.data.bones),"mpfb_data":str(DATA),"runtime_export":False,"visual_approved":False,"motion_approved":False}
(REVIEW/"private_pair_manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
print("BRITISH_PRIVATE_PAIR",json.dumps(manifest))
