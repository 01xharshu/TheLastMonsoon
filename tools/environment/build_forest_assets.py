"""Blender authoring/rebuild: organic forest meshes with explicit three-level LODs.
Run Blender --background --python tools/environment/build_forest_assets.py.
Sources stay editable; generated GLBs are runtime assets, never baked placements.
Uses existing project mango PBR textures (no new external asset dependency).
"""
import bpy, math, random
from pathlib import Path
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'environment/forest/assets'
SOURCE = ROOT / 'WorkingAssets/Environment/Forest'
TEX = ROOT / 'environment/vegetation/mango_tree/textures'
OUT.mkdir(parents=True, exist_ok=True); SOURCE.mkdir(parents=True, exist_ok=True)
(SOURCE / '.gdignore').write_text('')

def material(name, color, prefix=None):
    m = bpy.data.materials.new(name); m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value = (*color,1)
    p.inputs['Roughness'].default_value = .85
    if prefix:
        for suffix, socket in [('color','Base Color'), ('roughness','Roughness'), ('normal','Normal')]:
            path = TEX / f'{prefix}_{suffix}.png'
            t = m.node_tree.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(str(path),check_existing=True)
            if suffix != 'color': t.image.colorspace_settings.name='Non-Color'
            if suffix == 'normal':
                n = m.node_tree.nodes.new('ShaderNodeNormalMap'); m.node_tree.links.new(t.outputs['Color'],n.inputs['Color']); m.node_tree.links.new(n.outputs['Normal'],p.inputs[socket])
            else: m.node_tree.links.new(t.outputs['Color'],p.inputs[socket])
    return m

class Mesh:
    def __init__(self): self.v=[]; self.f=[]; self.uv=[]
    def face(self, points, uvs):
        k=len(self.v); self.v.extend(points); self.f.append(tuple(range(k,k+len(points)))); self.uv.extend(uvs)
    def tube(self, points, radii, sides, hollow=False):
        points=[Vector(p) for p in points]
        for j in range(len(points)-1):
            axis=(points[j+1]-points[j]).normalized(); a=axis.cross(Vector((0,1,0))).normalized(); b=axis.cross(a)
            for i in range(sides):
                angles=[2*math.pi*i/sides,2*math.pi*(i+1)/sides]
                q=[]
                for t,k in [(angles[0],j),(angles[1],j),(angles[1],j+1),(angles[0],j+1)]:
                    irregular=1+.09*math.sin(t*3+k*.7)+.045*math.sin(t*7-k)
                    q.append(points[k]+(a*math.cos(t)+b*math.sin(t))*radii[k]*irregular)
                self.face(q,[(i/sides*2,j*.65),((i+1)/sides*2,j*.65),((i+1)/sides*2,(j+1)*.65),(i/sides*2,(j+1)*.65)])
        if hollow:
            axis=(points[-1]-points[-2]).normalized(); a=axis.cross(Vector((0,1,0))).normalized(); b=axis.cross(a)
            inner=points[-1]-axis*.55
            for i in range(sides):
                t=2*math.pi*i/sides; t1=2*math.pi*(i+1)/sides
                d=a*math.cos(t)+b*math.sin(t); d1=a*math.cos(t1)+b*math.sin(t1)
                r=radii[-1]
                self.face([points[-1]+d*r,points[-1]+d1*r,points[-1]+d1*r*.73,points[-1]+d*r*.73],[(0,0),(1,0),(1,1),(0,1)])
                self.face([points[-1]+d*r*.73,points[-1]+d1*r*.73,inner+d1*r*.53,inner+d*r*.53],[(0,0),(1,0),(1,1),(0,1)])
        else:
            # End caps are essential for broken wood and fallen logs.
            axis=(points[-1]-points[-2]).normalized(); a=axis.cross(Vector((0,1,0))).normalized(); b=axis.cross(a)
            self.face([points[-1]+(a*math.cos(2*math.pi*i/sides)+b*math.sin(2*math.pi*i/sides))*radii[-1] for i in range(sides)],[(.5+.5*math.cos(2*math.pi*i/sides),.5+.5*math.sin(2*math.pi*i/sides)) for i in range(sides)])
    def leaf(self, base, direction, length, width, segments):
        base=Vector(base); direction=Vector(direction).normalized()
        right=direction.cross(Vector((0,0,1))).normalized()
        if right.length < .1: right=Vector((1,0,0))
        for j in range(segments):
            q=[]; uv=[]
            for t,s in [(j/segments,-1),((j+1)/segments,-1),((j+1)/segments,1),(j/segments,1)]:
                span=width*.5*max(.02,math.sin(math.pi*t))**.7
                q.append(base+direction*length*t+right*span*s+Vector((0,0,1))*(math.sin(math.pi*t)*length*.13-span*.17))
                uv.append(((s+1)/2,t))
            self.face(q,uv)
    def object(self,name,mat):
        if not self.v: return None
        mesh=bpy.data.meshes.new(name); mesh.from_pydata(self.v,[],self.f); mesh.update()
        uv=mesh.uv_layers.new(name='UVMap')
        for loop in mesh.loops: uv.data[loop.index].uv=self.uv[loop.vertex_index]
        obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj); obj.data.materials.append(mat)
        for poly in mesh.polygons: poly.use_smooth=True
        if 'Bark' in name:
            bpy.context.view_layer.objects.active=obj; obj.select_set(True)
            bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.remove_doubles(threshold=.00001); bpy.ops.object.mode_set(mode='OBJECT'); obj.select_set(False)
        return obj

def tree(kind,tier,bark,leaves):
    wood=Mesh(); green=Mesh(); rng=random.Random(1771+sum(map(ord,kind)))
    hero=kind=='hero'; dead=kind=='dead_tree'; small=kind=='small_tree'
    h=12 if hero else (5.8 if small else (6 if dead else 9))
    r=.72 if hero else (.24 if small else .42)
    sides=[12,8,5][tier]
    trunk=[(0,0,-.3),(.15,-.06,h*.18),(-.16,.13,h*.39),(.38,.1,h*.61),(.8,-.15,h*.86),(1.2,.2,h)]
    wood.tube(trunk,[r*1.5,r,r*.8,r*.63,r*.39,r*.09],sides)
    # Narrow tapering roots embed below the base rather than forming a flat flange.
    for i in range(7 if hero else 5):
        a=2*math.pi*i/7+rng.uniform(-.2,.2); d=Vector((math.cos(a),math.sin(a),0))
        wood.tube([d*.1+Vector((0,0,.52)),d*r*1.4+Vector((0,0,.02)),d*r*2.5+Vector((0,0,-.28))],[r*.32,r*.16,.025],sides)
    branches=9 if hero else (5 if small else 7)
    for i in range(branches):
        br=random.Random(810+i*77+int(h)); a=i*2.399+br.uniform(-.4,.4)
        start=Vector(trunk[2 if i<3 else 3]); start.z+=i*.19
        reach=(5.8 if hero else (2.4 if small else 4.3))*br.uniform(.7,1.25)
        d=Vector((math.cos(a),math.sin(a),0))
        p1=start+d*reach*.4+Vector((0,0,.5)); p2=start+d*reach*.85+Vector((0,0,1.5+br.random()))
        end=start+d*reach+Vector((0,0,1.5+br.random()))
        wood.tube([start,p1,p2,end],[r*.45,r*.29,r*.12,.03],sides,hollow=hero and i==0)
        if dead: continue
        # Fine branches carry irregular sprays rather than spherical crown blobs.
        for t in range(5):
            twig_rng=random.Random(i*157+t*39+int(h)*23)
            root=p1.lerp(end,.3+t*.14)
            angle=a+twig_rng.uniform(-1.8,1.8)
            tip=root+Vector((math.cos(angle),math.sin(angle),twig_rng.uniform(.2,.9)))*twig_rng.uniform(1.0,2.0)
            if tier<2: wood.tube([root,tip],[.035,.009],5)
            for j in range(80):
                if j % [1,4,10][tier]: continue
                leaf_rng=random.Random(i*10013+t*71+j*31)
                base=root.lerp(tip,j/80)+Vector((leaf_rng.uniform(-.8,.8),leaf_rng.uniform(-.8,.8),leaf_rng.uniform(-.3,.55)))
                angle=leaf_rng.uniform(0,math.tau)
                green.leaf(base,(math.cos(angle),math.sin(angle),leaf_rng.uniform(-.3,.3)),leaf_rng.uniform(.38,.74)*[1,1.45,2.0][tier],(.17 if small else .24)*[1,1.45,2.0][tier],[3,2,1][tier])
    if hero:
        wood.tube([(.1,-.1,1.4),(.3,-.4,1.65),(.8,-.8,2.05)],[.35,.32,.26],sides,hollow=True)
    wood.object('Bark',bark); green.object('Leaves',leaves)

def plant(kind,tier,bark,leaves):
    green=Mesh(); wood=Mesh(); rng=random.Random(31+sum(map(ord,kind)))
    sides=[8,6,4][tier]
    if kind in ('fallen_log','debris'):
        length=4.8 if kind=='fallen_log' else 1.2; r=.32 if kind=='fallen_log' else .06
        wood.tube([(0,0,0),(.08,.03,length*.35),(-.12,.06,length*.72),(0,.15,length)],[r,r*.9,r*.75,r*.55],sides,hollow=kind=='fallen_log')
        for j in range(3):
            z=length*(.22+j*.21); a=j*2.4
            wood.tube([(0,0,z),(.5*math.cos(a),.5*math.sin(a),z+.3),(math.cos(a),math.sin(a),z+.55)],[r*.32,r*.15,.025],sides)
    elif kind=='shelf_fungus':
        for ring in range(3):
            z=ring*.14
            for j in range(12//(tier+1)):
                a=math.pi*j/(12//(tier+1)); b=math.pi*(j+1)/(12//(tier+1))
                green.face([(0,0,z),(.5*math.cos(a),.5*math.sin(a),z+.05),(.5*math.cos(b),.5*math.sin(b),z+.05)],[(.5,0),(j/12,1),((j+1)/12,1)])
    elif kind=='fern':
        for i in range([9,6,4][tier]):
            a=i*2.399; d=Vector((math.cos(a),math.sin(a),0)); end=d*.65+Vector((0,0,.65+rng.random()*.18))
            wood.tube([(0,0,0),end*.6,end],[.008,.006,.001],4)
            for j in range([12,8,5][tier]):
                t=.1+.85*j/[12,8,5][tier]; base=end*t+Vector((0,0,.12*math.sin(t*math.pi)))
                for sign in (-1,1):
                    side=Vector((-d.y,d.x,0))*sign+d*.3
                    green.leaf(base,side,.30*(1-t)+.04,.07,[2,1,1][tier])
    else:
        grass='grass' in kind
        n=28 if grass else (20 if kind=='shrub' else 9)
        h=.72 if kind=='tall_grass' else (.22 if kind in ('short_grass','floor') else (.95 if kind=='shrub' else .48))
        for i in range(n):
            a=rng.random()*math.tau; b=Vector((rng.uniform(-.15,.15),rng.uniform(-.15,.15),0)); length=h*rng.uniform(.65,1.3)
            if i%[1,2,3][tier]: continue
            if grass: green.leaf(b,(math.cos(a)*.4,math.sin(a)*.4,1),length,.025,[4,2,1][tier])
            else:
                stem=b+Vector((math.cos(a)*.13,math.sin(a)*.13,length*.6))
                if tier==0: wood.tube([b,stem],[.006,.002],4)
                green.leaf(stem,(math.cos(a),math.sin(a),.35),length*.65,.22 if kind=='broadleaf' else .13,[4,2,1][tier])
    wood.object('Bark',bark); green.object('Leaves',leaves)

bpy.ops.wm.read_factory_settings(use_empty=True)
bark=material('Forest_Bark_PBR',(.28,.22,.15),'mango_bark')
leaves=material('Forest_Leaves_PBR',(.19,.30,.08),'mango_leaf')
fungus=material('Forest_Fungus',(.53,.40,.24))
kinds=['hero','canopy','canopy_broad','small_tree','dead_tree','fallen_log','fern','shrub','broadleaf','tall_grass','short_grass','floor','debris','shelf_fungus']
for kind in kinds:
    for tier in range(3):
        for obj in list(bpy.data.objects): bpy.data.objects.remove(obj,do_unlink=True)
        if kind in ['hero','canopy','canopy_broad','small_tree','dead_tree']: tree(kind,tier,bark,leaves)
        else: plant(kind,tier,bark,fungus if kind=='shelf_fungus' else leaves)
        if tier==0:
            for image in bpy.data.images:
                if image.source=='FILE': image.pack()
            bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/f'{kind}.blend'),check_existing=False)
        bpy.ops.export_scene.gltf(filepath=str(OUT/f'{kind}_lod{tier}.glb'),export_format='GLB',export_image_format='NONE',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
        print('FOREST_ASSET',kind,tier,sum(len(o.data.polygons) for o in bpy.data.objects if o.type=='MESH'))
