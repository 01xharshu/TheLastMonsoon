"""Original editable Peepal/Banyan/Palmyra with three runtime LODs.
Blender --background --python tools/environment/build_indian_tree_species.py
Reuses the existing organic tube builder, never executes its forest rebuild.
"""
import ast, bpy, math, random, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'environment/vegetation/indian_trees'
SOURCE=ROOT/'WorkingAssets/Environment/IndianTrees'
OUT.mkdir(parents=True,exist_ok=True);SOURCE.mkdir(parents=True,exist_ok=True)
(SOURCE/'.gdignore').write_text('')
namespace=dict(bpy=bpy,math=math,random=random,Vector=Vector)
module=ast.parse((ROOT/'tools/environment/build_forest_assets.py').read_text())
exec(compile(ast.Module(body=[x for x in module.body if isinstance(x,ast.ClassDef) and x.name=='Mesh'],type_ignores=[]),'<organic tree mesh>','exec'),namespace)
Mesh=namespace['Mesh']

def mat(name,color):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.86
 return m

def leaf(mesh,base,direction,length,width,heart=False,tier=0):
 base=Vector(base);d=Vector(direction).normalized();right=d.cross(Vector((0,0,1))).normalized()
 if right.length<.1:right=Vector((1,0,0))
 outline=([(0,.10),(-.23,-.08),(-.48,.01),(-.57,.25),(-.40,.50),(-.12,.78),(0,1.14),(.12,.78),(.40,.50),(.57,.25),(.48,.01),(.23,-.08)] if heart else [(0,0),(-.45,.2),(-.5,.53),(0,1),(.5,.53),(.45,.2)])
 if tier==2:outline=outline[::2] if heart else [(0,0),(-.5,.4),(0,1),(.5,.4)]
 points=[base+right*x*width+d*y*length for x,y in outline]
 centre=base+d*length*.45+Vector((0,0,length*.07))
 for i in range(len(points)):
  mesh.face([centre,points[i],points[(i+1)%len(points)]],[(.5,.45),((outline[i][0]+.6)/1.2,outline[i][1]),((outline[(i+1)%len(points)][0]+.6)/1.2,outline[(i+1)%len(points)][1])])

def broad(kind,tier,wood,foliage,prop):
 rng=random.Random(713 if kind=='peepal' else 931);h=6.4 if kind=='peepal' else 6.2
 wood.tube([(0,0,-.55 if kind=='banyan' else -.3),(.10,0,.65),(-.2,.08,2),(.15,-.15,3.8),(.6,.2,6.1),(.4,.2,h)],[.72 if kind=='banyan' else .42,.64 if kind=='banyan' else .36,.52 if kind=='banyan' else .29,.36,.18,.025],[12,8,6][tier])
 for i in range(7 if kind=='banyan' else 5):
  a=i*math.tau/(7 if kind=='banyan' else 5);d=Vector((math.cos(a),math.sin(a),0))
  wood.tube([d*.1+Vector((0,0,.9)),d*.7+Vector((0,0,.2)),d*1.2+Vector((0,0,-.55 if kind=='banyan' else -.25))],[.25,.18,.025],[8,6,4][tier])
 roots=[]
 for i in range(10 if kind=='banyan' else 8):
  rng=random.Random((713 if kind=='peepal' else 931)+i*7919)
  a=i*2.399;r=(6.0 if kind=='banyan' else 4.0)*rng.uniform(.8,1.15);d=Vector((math.cos(a),math.sin(a),0))
  start=Vector((.1,0,3.0+(i%3)*.6));bend=start+d*r*.43+Vector((0,0,.9));end=d*r+Vector((0,0,6.0+rng.uniform(-.5,1.5)))
  wood.tube([start,bend,end],[.32 if kind=='banyan' else .2,.19,.035],[10,7,5][tier])
  for twig in range(6):
   rng=random.Random((713 if kind=='peepal' else 931)+i*7919+twig*113)
   angle=a+rng.uniform(-1,1);side=Vector((math.cos(angle),math.sin(angle),0));base=bend.lerp(end,.25+twig*.13);tip=base+side*rng.uniform(.8,2)+Vector((0,0,rng.uniform(.4,1.3)))
   wood.tube([base,tip],[.055,.009],[6,5,4][tier])
   for j in range([42,24,10][tier]):
    point=base.lerp(tip,rng.random())+Vector((rng.uniform(-.65,.65),rng.uniform(-.65,.65),rng.uniform(-.15,.6)))
    direction=Vector((rng.uniform(-1,1),rng.uniform(-1,1),rng.uniform(-.65,.7)))
    size=rng.uniform(.30,.48)*[1,1.25,1.65][tier]
    leaf(foliage,point,direction,size,size*(.85 if kind=='peepal' else .65),kind=='peepal',tier)
  if kind=='banyan':
   anchor=bend.lerp(end,.35)
   if i in [0,2,5,7]:
    foot=Vector((anchor.x,anchor.y,-.55));prop.tube([foot,anchor*.0+Vector((anchor.x+.12,anchor.y,.9)),anchor],[.16,.12,.08],[8,6,5][tier]);roots.append(dict(x=anchor.x,y=anchor.y,top=anchor.z,radius=.16))
   for strand in range([5,3,2][tier]):
    top=bend.lerp(end,.25+strand*.13);bottom=top-Vector((rng.uniform(-.1,.1),rng.uniform(-.1,.1),rng.uniform(1.5,3.5)))
    prop.tube([top,top.lerp(bottom,.5)+Vector((.08,0,0)),bottom],[.024,.018,.009],[5,4,3][tier])
 # A high inner crown closes the central hole between the spreading limbs.
 for crown in range(3):
  rng=random.Random(1901+crown*79+(0 if kind=='peepal' else 200))
  a=crown*math.tau/3;tip=Vector((math.cos(a)*1.4,math.sin(a)*1.4,7.9))
  wood.tube([(.3,.1,5.7),tip],[.12,.012],[7,5,4][tier])
  for j in range([160,100,35][tier]):
   point=tip+Vector((rng.uniform(-1.25,1.25),rng.uniform(-1.25,1.25),rng.uniform(-.6,.8)))
   direction=Vector((rng.uniform(-1,1),rng.uniform(-1,1),rng.uniform(-.6,.7)))
   size=rng.uniform(.30,.46)*[1,1.25,1.65][tier]
   leaf(foliage,point,direction,size,size*(.85 if kind=='peepal' else .65),kind=='peepal',tier)
 return roots

def palm(tier,wood,foliage):
 h=13;wood.tube([(0,0,-.3),(.1,0,1),(.18,.05,4),(.3,.1,8),(.4,.1,h)],[.42,.36,.32,.29,.38],[14,10,7][tier])
 # Persisted leaf scars, rather than a plain smooth cylinder.
 for j in range(4,44,[1,2,3][tier]):
  z=j*.29;radius=.33+.02*math.sin(j*.7)
  wood.tube([(.4*z/h,.1*z/h,z-.035),(.4*z/h,.1*z/h,z+.035)],[radius+.035,radius],[14,10,7][tier])
 for i in range([22,18,14][tier]):
  a=i*2.399;direction=Vector((math.cos(a),math.sin(a),0));side=Vector((-direction.y,direction.x,0));crown=Vector((.4,.1,h))
  tip=crown+direction*2.2+Vector((0,0,1.2-(i%4)*.7))
  wood.tube([crown,crown.lerp(tip,.6)+Vector((0,0,.3)),tip],[.055,.037,.015],[6,5,4][tier])
  n=[28,20,12][tier]
  for j in range(n):
   angle=-1.2+2.4*j/max(1,n-1);angle2=-1.2+2.4*(j+1)/max(1,n-1)
   fan_axis=(direction*(.25 if i%3 else .85)+Vector((0,0,.97 if i%3 else -.45))).normalized()
   def at(t,angle):return tip+(fan_axis*math.cos(angle)+side*math.sin(angle))*t+Vector((0,0,-.12*t*t+.08*math.sin(angle*8)))
   inner=.9;length=1.7+.25*math.cos(j*2.1)
   # Fan centre plus individually split, folded segments.
   foliage.face([tip,at(inner,angle),at(inner,angle2)],[(.5,0),(0,.3),(1,.3)])
   foliage.face([at(inner,angle),at(length,angle+.006),at(length,angle2-.006),at(inner,angle2)],[(0,.3),(0,1),(1,1),(1,.3)])
 return []

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
manifest={}
for kind in ['peepal','banyan','palm']:
 for tier in range(3):
  for obj in list(bpy.data.objects):bpy.data.objects.remove(obj,do_unlink=True)
  wood,green,prop=Mesh(),Mesh(),Mesh()
  roots=palm(tier,wood,green) if kind=='palm' else broad(kind,tier,wood,green,prop)
  bark=mat('Species_Bark_'+kind, (.16,.12,.07) if kind=='palm' else (.38,.34,.27))
  foliage=mat('Species_Leaves_'+kind,dict(peepal=(.22,.39,.09),banyan=(.12,.28,.07),palm=(.23,.34,.13))[kind])
  foliage.surface_render_method='DITHERED';foliage.use_backface_culling=False
  wood.object('Bark',bark);green.object('Leaves',foliage);prop.object('PropBranch',mat('PropBranch_Bark',(.32,.27,.19)))
  if tier==0:
   bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/f'{kind}.blend'),check_existing=False)
   manifest[kind]={'botanical_name':dict(peepal='Ficus religiosa',banyan='Ficus benghalensis',palm='Borassus flabellifer')[kind],'prop_roots':roots,'height':13 if kind=='palm' else 10 if kind=='peepal' else 9}
  bpy.ops.export_scene.gltf(filepath=str(OUT/f'{kind}_lod{tier}.glb'),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
  print('INDIAN_TREE',kind,tier,sum(len(o.data.polygons) for o in bpy.data.objects if o.type=='MESH'))
(OUT/'species.json').write_text(json.dumps(manifest,indent=2)+'\n')
