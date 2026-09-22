"""Build an isolated Arjun study using the installed MakeHuman/MPFB extension.

Run with Blender --background --python tools/characters/build_arjun_candidate.py.
Owner boards are visual targets, not metric scans. Does not replace gameplay assets.
"""
import bpy
import bmesh
import hashlib
import json
import math
import random
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.kdtree import KDTree
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'WorkingAssets/Arjun/candidate'
REVIEW = ROOT / 'docs/characters/arjun'
DATA = Path.home() / 'Library/Application Support/Blender/5.2/extensions/.user/blender_org/mpfb/data'
random.seed(22)
OUT.mkdir(parents=True, exist_ok=True)
REVIEW.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'WorkingAssets/Arjun/arjun_character_v2.blend'))
from bl_ext.blender_org.mpfb.services.humanservice import HumanService
from bl_ext.blender_org.mpfb.services.targetservice import TargetService

body = bpy.data.objects['Human']
upper = bpy.data.objects['CLOTH_Arjun_Kurta_Upper']
for obj in list(bpy.data.objects):
    if obj not in (body, upper):
        bpy.data.objects.remove(obj, do_unlink=True)
body.parent = None
body.name = 'Arjun_MakeHuman_Body'
upper.parent = None
body.hide_render = False
body.hide_set(False)
for mod in list(body.modifiers):
    if mod.type != 'MASK' or mod.name != 'Hide helpers':
        body.modifiers.remove(mod)
for mod in list(upper.modifiers):
    upper.modifiers.remove(mod)

# Keep the MPFB shape stack editable; the existing local adjustments are the start.
for key in body.data.shape_keys.key_blocks:
    if 'head_age_decr' in key.name:
        key.value = 0.0
    if 'head_fat_decr' in key.name:
        key.value = 0.18
    if 'chin_width_incr' in key.name:
        key.value = 0.24
    if 'nose_scale_depth_incr' in key.name:
        key.value = 0.25
    if 'mouth_scale_horiz_incr' in key.name:
        key.value = 0.22
body['source_workflow'] = 'MakeHuman MPFB 2.0.17; original editable v2 body and reference-specific refinements'
body['reference_status'] = 'Owner supplied concept boards; likeness study, not approved'
body['age_years'] = 22
rig = HumanService.add_builtin_rig(body, 'game_engine', import_weights=True)
rig.name = 'Arjun_Rig'
rig.show_in_front = True
rig['candidate_status'] = 'WORK_IN_PROGRESS'

def material(name, color, rough=0.65, texture=None, weave=False, leather=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*color, 1)
    nt = mat.node_tree
    bs = nt.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = rough
    if texture:
        tex = nt.nodes.new('ShaderNodeTexImage')
        tex.image = bpy.data.images.load(str(texture), check_existing=True)
        mix = nt.nodes.new('ShaderNodeMixRGB')
        mix.blend_type = 'MULTIPLY'
        mix.inputs[0].default_value = 1
        mix.inputs[2].default_value = (*color,1)
        nt.links.new(tex.outputs['Color'], mix.inputs[1])
        nt.links.new(mix.outputs[0], bs.inputs['Base Color'])
    if weave or leather:
        texcoord = nt.nodes.new('ShaderNodeTexCoord')
        noise = nt.nodes.new('ShaderNodeTexNoise')
        noise.inputs['Scale'].default_value = 42 if weave else 110
        noise.inputs['Detail'].default_value = 3
        nt.links.new(texcoord.outputs['Object'], noise.inputs['Vector'])
        ramp = nt.nodes.new('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].position = 0.17
        ramp.color_ramp.elements[0].color = (*(c * .68 for c in color), 1)
        ramp.color_ramp.elements[1].position = .83
        ramp.color_ramp.elements[1].color = (*(c * 1.3 for c in color), 1)
        nt.links.new(noise.outputs['Fac'], ramp.inputs[0])
        nt.links.new(ramp.outputs[0], bs.inputs['Base Color'])
        fine = nt.nodes.new('ShaderNodeTexNoise')
        fine.inputs['Scale'].default_value = 950 if weave else 480
        fine.inputs['Detail'].default_value = 2
        nt.links.new(texcoord.outputs['Object'], fine.inputs[0])
        bump = nt.nodes.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value = .24
        bump.inputs['Distance'].default_value = .0006
        nt.links.new(fine.outputs['Fac'], bump.inputs['Height'])
        nt.links.new(bump.outputs['Normal'], bs.inputs['Normal'])
        if weave:
            bs.inputs['Sheen Weight'].default_value = .18
    return mat

skin = material('Arjun warm medium-brown skin', (.52,.36,.245), .52,
    ROOT/'WorkingAssets/Arjun/arjun_character_v2_young_lightskinned_male_diffuse.png')
skin.node_tree.nodes.get('Principled BSDF').inputs['Subsurface Weight'].default_value = .06
body.data.materials.clear()
body.data.materials.append(skin)
for poly in body.data.polygons:
    poly.material_index = 0
    poly.use_smooth = True
charcoal = material('Weathered charcoal cotton',(.032,.034,.038), weave=True)
cream = material('Unbleached draped cotton',(.64,.57,.44), weave=True)
red = material('Faded madder-red sash',(.22,.031,.026), weave=True)
red_thread = material('Muted ochre sash thread',(.29,.14,.065), weave=True)
leather = material('Worn dark-brown leather',(.062,.029,.014), .48, leather=True)
leather_edge = material('Leather seams and welt',(.17,.085,.034), .7, leather=True)
sole_mat = material('Dark boot soles',(.018,.012,.008), .82)
brass = material('Aged brass hardware',(.26,.16,.067), .36)
brass.node_tree.nodes.get('Principled BSDF').inputs['Metallic'].default_value = .7
hair_mat = material('Soft black hair',(.009,.007,.005), .43)
foundation_mat = material('Opaque fitted foundation',(.12,.105,.082), weave=True)

# MPFB fits body parts to this body's target stack and transfers its rig weights.
eyes = HumanService.add_mhclo_asset(str(DATA/'eyes/high-poly/high-poly.mhclo'), body, asset_type='Eyes', subdiv_levels=1)
eyes.name = 'Arjun_Eyes'
eye_mat = material('Brown eyes', (1,1,1), .25, ROOT/'WorkingAssets/Arjun/arjun_character_v2_brown_eye.png')
eyes.data.materials.clear(); eyes.data.materials.append(eye_mat)
brows = HumanService.add_mhclo_asset(str(DATA/'eyebrows/eyebrow012/eyebrow012.mhclo'), body, asset_type='Eyebrows', subdiv_levels=1)
brows.name = 'Arjun_Eyebrows'
for mat in brows.data.materials:
    for n in mat.node_tree.nodes:
        if n.type == 'BSDF_PRINCIPLED': n.inputs['Roughness'].default_value = .8

# Evaluate the full MPFB mesh before helper masking to retain fitting groups.
for mod in body.modifiers: mod.show_viewport = False
bpy.context.view_layer.update()
source = bpy.data.meshes.new_from_object(body.evaluated_get(bpy.context.evaluated_depsgraph_get()))
for mod in body.modifiers: mod.show_viewport = True
body_ids = {v.index for v in source.vertices if any(g.group == body.vertex_groups['body'].index for g in v.groups)}
kd = KDTree(len(body_ids))
for i in body_ids: kd.insert(source.vertices[i].co, i)
kd.balance()
bone_names = set(rig.data.bones.keys())
vg_names = {g.index:g.name for g in body.vertex_groups}
body_weights = {i:{vg_names[g.group]:g.weight for g in source.vertices[i].groups if vg_names[g.group] in bone_names} for i in body_ids}
polys = [list(p.vertices) for p in source.polygons if all(i in body_ids for i in p.vertices)]
bvh = BVHTree.FromPolygons([v.co for v in source.vertices], polys, all_triangles=False)

def fit_weights(obj, bone=None):
    if obj.type != 'MESH':
        bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
        bpy.ops.object.convert(target='MESH')
    for v in obj.data.vertices:
        weights = {}
        if bone:
            weights[bone] = 1.
        else:
            close = kd.find_n(obj.matrix_world @ v.co, 4)
            for _, idx, distance in close:
                factor = 1. / max(distance, .0005)**2
                for name, value in body_weights[idx].items(): weights[name] = weights.get(name,0) + value*factor
            total = sum(weights.values())
            weights = {k:v/total for k,v in weights.items()} if total else {'pelvis':1.}
        for name, value in weights.items():
            if value > .001:
                group = obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
                group.add([v.index],value,'REPLACE')
    arm = obj.modifiers.new('MPFB deformation','ARMATURE'); arm.object=rig
    obj.parent=rig
    return obj

def mesh_obj(name, vertices, faces, mat, smooth=True, subdiv=0, thickness=0):
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for p in mesh.polygons:p.use_smooth=smooth
    # Recalculate to make subsequent solidify and renders deterministic.
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    if subdiv:
        m=obj.modifiers.new('Fabric smoothing','SUBSURF');m.levels=subdiv;m.render_levels=subdiv
    if thickness:
        m=obj.modifiers.new('Fabric thickness','SOLIDIFY');m.thickness=thickness;m.offset=0
    return obj

def curve(name, points, radius, mat, bone=None, cyclic=False):
    data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.resolution_u=2;data.bevel_depth=radius;data.bevel_resolution=2
    spline=data.splines.new('POLY');spline.points.add(len(points)-1)
    for p,co in zip(spline.points,points):p.co=(*co,1)
    spline.use_cyclic_u=cyclic
    obj=bpy.data.objects.new(name,data);bpy.context.scene.collection.objects.link(obj);data.materials.append(mat)
    return fit_weights(obj,bone)

def subset(name, group, predicate, offset, mat):
    group_idx=body.vertex_groups[group].index
    ids={v.index for v in source.vertices if any(g.group==group_idx for g in v.groups) and predicate(v.co)}
    faces=[list(p.vertices) for p in source.polygons if all(i in ids for i in p.vertices)]
    used=sorted({i for f in faces for i in f}); lookup={i:j for j,i in enumerate(used)}
    obj=mesh_obj(name,[source.vertices[i].co + source.vertices[i].normal*offset for i in used],[[lookup[i] for i in f] for f in faces],mat,subdiv=1,thickness=.0015)
    return fit_weights(obj)

foundation=subset('Arjun_Foundation_FittedShorts','helper-tights',lambda v:.77<v.z<1.01,.004,foundation_mat)
foundation['construction']='Opaque fitted underwear over the same recoverable body; no exposed genital detail'

# Rebuild the shirt opening in the existing body-fitted upper pattern.
upper.name='Arjun_Kurta_Upper'
upper.vertex_groups.clear()
bm=bmesh.new();bm.from_mesh(upper.data)
remove=[]
for f in bm.faces:
    c=f.calc_center_median()
    # A narrow V opening at the front, connected to the neck opening.
    if c.y < -.035 and c.z > 1.355 and abs(c.x) < max(0,(c.z-1.355)*.38): remove.append(f)
bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(upper.data);bm.free()
upper.data.materials.clear();upper.data.materials.append(charcoal)
for v in upper.data.vertices:
    # Ease and restrained cloth folds, strongest around the waist and elbows.
    v.co.y += (-1 if v.co.y<-.025 else 1)*(.007+.003*math.sin(v.co.x*70+v.co.z*21))
for p in upper.data.polygons:p.use_smooth=True
fit_weights(upper)
m=upper.modifiers.new('Cotton surface','SUBSURF');m.levels=2;m.render_levels=2
m=upper.modifiers.new('Cotton thickness','SOLIDIFY');m.thickness=.002;m.offset=0

def elliptical_surface(name, rows, n, mat, folds=0, split=False, phase=0):
    verts=[];faces=[]
    for j,(z,cx,cy,rx,ry) in enumerate(rows):
        for i in range(n):
            a=2*math.pi*i/n
            fold=folds*(math.sin(13*a+z*22+phase)+.45*math.sin(21*a-z*32))
            verts.append((cx+(rx+fold)*math.cos(a),cy+(ry+fold)*math.sin(a),z+.002*math.sin(a*9+phase)))
    for j in range(len(rows)-1):
        for i in range(n):
            if split and j<5 and i in (0,n//2):continue
            k=j*n+i; nxt=j*n+(i+1)%n
            faces.append((k,nxt,nxt+n,k+n))
    return fit_weights(mesh_obj(name,verts,faces,mat,subdiv=1,thickness=.002))

shirt_rows=[]
for j in range(25):
    t=j/24; z=.705+t*.38
    rx=.211-.045*t;ry=.149-.03*t
    shirt_rows.append((z,0,-.022,rx,ry))
skirt=elliptical_surface('Arjun_Kurta_SplitHem',shirt_rows,96,charcoal,.004,True)
skirt['construction']='Side-split long shirt panels with eased waist and hem'

# Folded collar and continuous front placket, with visible small brass buttons.
for side in (-1,1):
    verts=[(side*.014,-.150,1.355),(side*.068,-.091,1.451),(side*.056,-.021,1.497),(side*.046,.02,1.487),
           (side*.045,-.113,1.379),(side*.083,-.061,1.455),(side*.065,.001,1.490),(side*.052,.027,1.485)]
    fit_weights(mesh_obj('Kurta folded collar '+str(side),verts,[(0,1,5,4),(1,2,6,5),(2,3,7,6)],charcoal,subdiv=2,thickness=.002))
    points=[(side*(.013+max(0,z-1.36)*.36),-.159 if z<1.36 else -.158+(z-1.36)*.30,z) for z in [1.06,1.10,1.15,1.20,1.25,1.30,1.35,1.40,1.45]]
    curve('Kurta placket seam '+str(side),points,.0017,charcoal)
for z in [1.10,1.17,1.24,1.31,1.37]:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=1,location=(.006,-.169,z))
    o=bpy.context.object;o.name='Kurta button';o.scale=(.0045,.0025,.0045);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(brass);fit_weights(o)

# Sleeve cuffs follow the original sleeve direction in the MPFB A pose.
for side in (-1,1):
    center=Vector((side*.382,-.023,1.19));axis=Vector((side*.66,-.12,-.74)).normalized()
    u=axis.cross(Vector((0,1,0))).normalized();v=axis.cross(u)
    for ring in range(3):
        c=center+axis*(ring*.010)
        pts=[c+(.069+.002*math.sin(i*.9))*(math.cos(i*2*math.pi/64)*u+math.sin(i*2*math.pi/64)*v) for i in range(64)]
        curve('Rolled cotton cuff '+str(side),pts,.008,charcoal,cyclic=True)

# Two separate dhoti-style trouser legs; pleats taper into each boot.
for side in (-1,1):
    rows=[]
    for j in range(39):
        t=j/38;z=.205+t*.765
        cx=side*(.196-.07*t);cy=-.005-.018*math.sin(t*math.pi)
        radius=.052+.071*math.sin(math.pi*t*.92)**.8
        rows.append((z,cx,cy,radius,radius*1.02))
    pants=elliptical_surface('Arjun_DrapedTrousers_'+str(side),rows,96,cream,.009,phase=side*.7)
    pants['construction']='Gathered individual trouser leg; diagonal pleats and ankle taper'
    # Broad diagonal folded panel produces overlapping drape rather than uniform tubes.
    verts=[];faces=[]
    for j in range(33):
        t=j/32;z=.27+t*.60;cx=side*(.196-.070*t)
        radius=.065+.065*math.sin(t*math.pi*.9)
        for i in range(17):
            u=i/16;a=-math.pi*.83+u*math.pi*.60+side*.3*t
            r=radius+.008+ .010*math.sin(u*math.pi*7+t*15)
            verts.append((cx+r*math.cos(a),-.014+r*math.sin(a)-.008,z+.03*math.sin(u*math.pi)*math.sin(t*math.pi)))
    for j in range(32):
        for i in range(16):
            k=j*17+i;faces.append((k,k+1,k+18,k+17))
    fit_weights(mesh_obj('Dhoti overlapping pleat '+str(side),verts,faces,cream,subdiv=1,thickness=.0015))

sash_rows=[(1.032+j*.0042,0,-.020,.181+ .003*math.sin(j*1.7),.139+.003*math.sin(j*1.5)) for j in range(19)]
sash=elliptical_surface('Arjun_RedWaistSash',sash_rows,128,red,.002)
for j in range(9):
    z=1.038+j*.009
    pts=[(.185*math.cos(a),-.02+.144*math.sin(a),z+.006*math.sin(a*3+j*.4)) for a in [i*2*math.pi/128 for i in range(128)]]
    curve('Sash woven stripe',pts,.0008,red_thread,cyclic=True)
# Knot and two unequal fabric tails on the wearer's right hip (image left).
for layer in range(2):
    verts=[];faces=[]
    for j in range(41):
        t=j/40;z=1.065-t*(.48-layer*.075)
        for i in range(19):
            u=i/18-.5
            verts.append((-.163+u*(.11+.035*t)-.035*t+layer*.016,
                          -.158-.032*t+.009*math.sin(u*23+t*3)+layer*.012,
                          z+.014*math.sin(u*8+layer)))
    for j in range(40):
        for i in range(18):
            k=j*19+i;faces.append((k,k+1,k+20,k+19))
    fit_weights(mesh_obj('Sash hanging tail '+str(layer),verts,faces,red,subdiv=1,thickness=.0015))
    for i in range(16):
        u=i/15-.5;x=-.198+u*.145+layer*.016;z=.585+layer*.075+.014*math.sin(u*8+layer)
        curve('Sash fringe',[(x,-.189+layer*.012,z),(x+.002,-.193+layer*.012,z-.022),(x-.003,-.193+layer*.012,z-.045)],.0012,red)
for k in range(3):
    pts=[(-.162+.027*math.cos(a),-.167-.013*math.sin(a),1.066+.013*math.sin(a)+k*.009) for a in [i*math.tau/48 for i in range(48)]]
    curve('Tied sash knot',pts,.012,red,cyclic=True)

def boot(side):
    cx=side*.195
    # Last-shaped foot shell: broad toe, tighter instep, closed sole and ankle opening.
    rows=[]
    for z,rx,ry,cy in [(.015,.071,.153,-.073),(.025,.073,.156,-.073),(.04,.071,.150,-.071),(.066,.069,.143,-.070),(.092,.063,.121,-.052),(.118,.056,.086,-.025),(.145,.053,.059,-.006),(.18,.056,.060,-.006),(.23,.061,.062,-.006),(.285,.065,.065,-.006),(.30,.065,.065,-.006)]:
        rows.append((z,cx,cy,rx,ry))
    shell=elliptical_surface('Arjun_Boot_'+str(side),rows,64,leather,.0015)
    shell['construction']='Leather shaft, shaped vamp and toe, separate outsole, welt, crossed straps and buckles'
    sole_rows=[(.004,cx,-.074,.073,.155),(.012,cx,-.074,.076,.157),(.025,cx,-.074,.075,.156)]
    elliptical_surface('Boot outsole '+str(side),sole_rows,64,sole_mat)
    for z in [.026,.290,.299]:
        ry=.156 if z<.03 else .068;rx=.075 if z<.03 else .067;cy=-.074 if z<.03 else -.006
        curve('Boot welt seam',[(cx+rx*math.cos(a),cy+ry*math.sin(a),z) for a in [i*math.tau/64 for i in range(64)]],.0017,leather_edge,cyclic=True)
    for row in range(5):
        z=.132+row*.033
        for direction in (-1,1):
            pts=[]
            for i in range(17):
                t=i/16; a=-math.pi*.85+t*math.pi*.7
                pts.append((cx+.065*math.cos(a),-.010+.071*math.sin(a),z+direction*(t-.5)*.034))
            curve('Crossed boot strap',pts,.006,leather_edge)
    for z in [.14,.245]:
        x=cx+side*.063
        curve('Boot brass buckle',[(x,-.039,z-.009),(x,-.060,z-.009),(x,-.060,z+.009),(x,-.039,z+.009)],.0018,brass,cyclic=True)
    curve('Boot toe seam',[(cx+.068*math.cos(a),-.07+.143*math.sin(a),.065) for a in [math.pi+i*math.pi/48 for i in range(49)]],.0012,leather_edge)
for side in (-1,1):boot(side)

# A connected scalp foundation with swept, layered wave locks.
cap=subset('Arjun_Hair_Cap','scalp',lambda v:True,.007,hair_mat)
for vg in list(cap.vertex_groups):cap.vertex_groups.remove(vg)
g=cap.vertex_groups.new(name='head');g.add(list(range(len(cap.data.vertices))),1,'REPLACE')
def head_surface(x,z):
    hit=bvh.ray_cast(Vector((x,-.6,z)),Vector((0,1,0)))
    return hit[0] if hit[0] is not None else Vector((x,-.12,z))

# Tousled waves over the crown. Curves are tapered and overlap the scalp foundation.
for k in range(155):
    a=random.uniform(-math.pi,math.pi)
    theta=random.uniform(.10,1.47)
    pts=[]
    for i in range(15):
        t=i/14;aa=a+.40*t+.09*math.sin(t*math.tau+k)
        th=max(.04,theta-.36*t)
        x=.083*math.sin(th)*math.cos(aa)
        y=-.040+.097*math.sin(th)*math.sin(aa)
        z=1.613+.126*math.cos(th)+.012*math.sin(math.pi*t)+.008*math.sin(k)
        pts.append((x,y,z))
    lock=curve('Swept black wave',pts,random.uniform(.0025,.0048),hair_mat,'head')
    for strand in range(2):
        off=(strand-.5)*.003
        curve('Fine wave strand',[(x+off,y-.001,z+.002) for x,y,z in pts],.00055,hair_mat,'head')
# Upper lip moustache has a narrow central part and tapered outer ends.
for side in (-1,1):
    for k in range(85):
        t=k/84;x=side*(.002+.025*t)
        z=1.550-.006*t+.0016*math.sin(k*2)
        pts=[]
        for j in range(6):
            u=j/5;xx=x+side*.0035*u;zz=z-.0045*u
            p=head_surface(xx,zz);pts.append((xx,p.y-.0014,zz))
        curve('Moustache strand',pts,.00045*(1-.45*t),hair_mat,'head')

sub=body.modifiers.new('Body surface smoothing','SUBSURF');sub.levels=1;sub.render_levels=1
# Conservative render-only masks beneath opaque garments; full base remains editable.
covered=body.vertex_groups.new(name='CoveredByCoreOutfit')
mask_ids=[]
for i in body_ids:
    p=source.vertices[i].co
    if p.z<1.11 or (1.11<p.z<1.33 and abs(p.x)<.19):mask_ids.append(i)
covered.add(mask_ids,1,'REPLACE')
mask=body.modifiers.new('Conservative clothing occlusion','MASK');mask.vertex_group=covered.name;mask.invert_vertex_group=True
foundation.hide_render=True
foundation.hide_set(True)

# Relax the A pose using the MPFB armature, preserving the editable rest pose.
for side,sign in [('l',1),('r',-1)]:
    bone=rig.pose.bones.get('upperarm_'+side)
    if bone:
        axis=bone.bone.matrix_local.to_3x3().inverted() @ Vector((0,1,0))
        bone.rotation_mode='QUATERNION'
        from mathutils import Quaternion
        bone.rotation_quaternion=Quaternion(axis,sign*math.radians(28))

# Embedded reference boards, hidden from beauty renders.
refs=bpy.data.collections.new('Owner references — visual targets');bpy.context.scene.collection.children.link(refs)
for index,name in enumerate(['arjun_core_multiview.png','arjun_equipped_multiview.png']):
    obj=bpy.data.objects.new(name,None);obj.empty_display_type='IMAGE';obj.data=bpy.data.images.load(str(ROOT/'WorkingAssets/Arjun/references'/name));obj.empty_display_size=2.5;obj.location=(3+index*3,1,1);obj.rotation_euler=(math.pi/2,0,0);obj.hide_render=True;refs.objects.link(obj)

scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.18,.18,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.35
studio=bpy.data.collections.new('Review studio');scene.collection.children.link(studio)
for name,pos,power,size in [('Key',(2,-3,4),260,3),('Fill',(-2,-1,2),150,2.5),('Rim',(1,2,3),280,2)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;obj=bpy.data.objects.new(name,data);studio.objects.link(obj);obj.location=pos;obj.rotation_euler=(Vector((0,0,1))-obj.location).to_track_quat('-Z','Y').to_euler()
floor=mesh_obj('Studio floor',[(-200,-200,0),(200,-200,0),(200,200,0),(-200,200,0)],[(0,1,2,3)],material('Warm grey backdrop',(.16,.15,.135),.9))
for col in list(floor.users_collection):col.objects.unlink(floor)
studio.objects.link(floor)
camdata=bpy.data.cameras.new('Arjun review camera');camera=bpy.data.objects.new('Arjun review camera',camdata);studio.objects.link(camera);scene.camera=camera;camdata.type='ORTHO';camdata.ortho_scale=1.98
camera.location=(0,-4,.88);camera.rotation_euler=(Vector((0,0,.88))-camera.location).to_track_quat('-Z','Y').to_euler()
for area in bpy.context.screen.areas if bpy.context.screen else []:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_distance=2.7
        area.spaces.active.region_3d.view_location=(0,0,.88)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'arjun_reference_candidate.blend'))
report={'status':'WORK_IN_PROGRESS','source':'WorkingAssets/Arjun/arjun_character_v2.blend','mpfb_version':'2.0.17','workflow':'MPFB editable targets, game_engine rig, MPFB fitted eyes/eyebrows; custom core garments','body_vertex_count':len(body.data.vertices),'bone_count':len(rig.data.bones),'mesh_count':len([o for o in bpy.data.objects if o.type=='MESH']),'approval':{'likeness':False,'motion':False,'Godot':False,'production':False},'reference_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'WorkingAssets/Arjun/references').glob('*.png')}}
report['blend_sha256']=hashlib.sha256((OUT/'arjun_reference_candidate.blend').read_bytes()).hexdigest()
(REVIEW/'candidate_manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print('ARJUN_BUILD_SAVED',json.dumps(report),flush=True)
scene.render.filepath=str(REVIEW/'candidate_front.png');bpy.ops.render.render(write_still=True)
print('ARJUN_FRONT_RENDER_DONE',flush=True)
