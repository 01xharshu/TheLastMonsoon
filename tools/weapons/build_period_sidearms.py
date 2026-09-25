"""Original visual props based on 1851 Adams silhouette and a plain utility knife.
Not a mechanical reconstruction. Blender source retained; no downloaded meshes.
"""
import bpy, math
from pathlib import Path
R=Path(__file__).resolve().parents[2]
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,color,metal=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.3 if metal else .65;return m
steel=mat('Worn blued steel',(.055,.065,.075),.85);silver=mat('Honed steel',(.45,.47,.48),.9);wood=mat('Walnut grip',(.12,.047,.018));wood_wear=mat('Raised walnut checkering',(.19,.085,.039));brass=mat('Brass pins',(.42,.29,.09),.7)
def cube(name,loc,size,material,rot=(0,0,0)):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc,rotation=rot);o=bpy.context.object;o.name=name;o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material);mod=o.modifiers.new('Soft machined edges','BEVEL');mod.width=.0015;mod.segments=3;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');return o
def cyl(name,loc,radius,depth,material,verts=32):
 bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=radius,depth=depth,location=loc,rotation=(0,math.pi/2,0));o=bpy.context.object;o.name=name;o.data.materials.append(material);mod=o.modifiers.new('Edge bevel','BEVEL');mod.width=.0008;mod.segments=2;return o
def tube(name,points,radius,material):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.bevel_depth=radius;c.bevel_resolution=3;s=c.splines.new('POLY');s.points.add(len(points)-1)
 for p,v in zip(s.points,points):p.co=(*v,1)
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.data.materials.append(material)
def save(name):
 out=R/'environment/weapons'/name;out.mkdir(parents=True,exist_ok=True)
 bpy.ops.wm.save_as_mainfile(filepath=str(out/(name+'.blend')))
 bpy.ops.export_scene.gltf(filepath=str(out/(name+'.glb')),export_format='GLB',export_apply=True)
# +X is barrel direction, +Z source up.
cube('Solid frame',(-.06,0,.035),(.095,.043,.023),steel)
cube('Top strap',(-.045,0,.088),(.13,.022,.012),steel)
cube('Rear frame',(-.115,0,.064),(.022,.041,.061),steel)
cyl('Five chamber cylinder',(-.048,0,.063),.029,.066,steel)
for i in range(5):
 a=i*2*math.pi/5;cyl('Chamber mouth',(-.013,math.sin(a)*.017,.063+math.cos(a)*.017),.0055,.0015,mat('Chamber black '+str(i),(.006,.006,.006)),16)
cyl('Octagonal barrel',(.08,0,.064),.014,.185,steel,8)
cyl('Muzzle bore',(.173,0,.064),.008,.0015,mat('Bore',(.004,.004,.004)),24)
cube('Front blade sight',(.154,0,.081),(.01,.004,.008),silver)
cube('Grip',(-.126,0,-.015),(.049,.039,.099),wood,(0,-.26,0))
cube('Grip butt',(-.139,0,-.062),(.047,.042,.009),steel)
cube('Hammer',(-.123,0,.102),(.025,.012,.012),steel,(0,-.3,0))
cube('Rear sight notch',(-.105,0,.101),(.009,.021,.004),steel)
tube('Trigger guard',[(-.102,0,.025),(-.091,0,-.020),(-.046,0,-.023),(-.020,0,.015),(-.025,0,.03)],.003,steel)
tube('Trigger',[(-.065,0,.03),(-.058,0,.004),(-.069,0,-.01)],.0025,silver)
cyl('Loading lever',(.048,0,.038),.003,.13,steel,12)
for side in [-1,1]:
 y=side*.0215
 for i in range(6):
  z=-.048+i*.012
  tube('Fine grip checkering', [(-.144,y,z),(-.111,y,z+.011)],.00055,wood_wear)
  tube('Cross grip checkering', [(-.111,y,z),(-.144,y,z+.011)],.00055,wood_wear)
 for x,z in [(-.111,.064),(-.064,.034),(.020,.044)]:
  bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=.0023,location=(x,side*.025,z))
  bpy.context.object.name='Frame and lock screw head'
  bpy.context.object.data.materials.append(silver)
 tube('Cylinder stop witness line',[(-.044,side*.029,.036),(-.044,side*.029,.09)],.0008,silver)
 tube('Loading lever hinge',[(-.012,side*.008,.037),(.002,side*.008,.037)],.0028,brass)
for x,z in [(-.125,-.008),(-.11,.047)]:
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=.003,location=(x,-.021,z));bpy.context.object.data.materials.append(brass)
save('adams_1851')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
cube('Wood handle',(-.045,0,0),(.095,.026,.029),wood)
cube('Small steel bolster',(.005,0,0),(.012,.034,.037),steel)
verts=[(.01,-.001,-.015),(.01,.001,-.015),(.01,-.002,.015),(.01,.002,.015),(.14,0,-.006),(.105,-.001,.014),(.105,.001,.014)]
faces=[(0,2,5,4),(1,4,6,3),(0,4,1),(2,3,6,5),(5,6,4),(0,1,3,2)]
m=bpy.data.meshes.new('Forged blade');m.from_pydata(verts,[],faces);o=bpy.data.objects.new('Plain utility blade',m);bpy.context.collection.objects.link(o);o.data.materials.append(silver)
for x in [-.07,-.025]:
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=.0025,location=(x,-.014,0));bpy.context.object.data.materials.append(brass)
save('period_utility_knife')
