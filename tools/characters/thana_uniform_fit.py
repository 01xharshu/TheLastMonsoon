"""Original low-poly uniform fittings; all pieces deform with the MPFB rig.
1857 fictional district design candidate, not a verified regulation pattern.
"""
import bpy, math, bmesh
from mathutils import Vector

def fit_uniform(rig,role):
 def mat(name,color):
  m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
  p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.84
  return m
 cotton=mat('Police drab cotton',(.36,.32,.23));blue=mat('Police indigo facing',(.035,.065,.10));leather=mat('Police worn leather',(.10,.055,.028));brass=mat('Plain brass fastenings',(.46,.32,.10));hair=mat('Sikh uncut beard',(.018,.012,.009))
 def skin(o,bone):
  group=o.vertex_groups.new(name=bone);group.add(list(range(len(o.data.vertices))),1,'REPLACE')
  o.parent=rig;o.matrix_parent_inverse=rig.matrix_world.inverted()
  mod=o.modifiers.new('Uniform skin','ARMATURE');mod.object=rig
  return o
 def box(name,loc,size,m,bone):
  bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=size
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m)
  bevel=o.modifiers.new('Cloth edges','BEVEL');bevel.width=.003;bevel.segments=2
  return skin(o,bone)
 def ring(name,z,rx,ry,height,m,bone):
  verts=[(rx*math.cos(i*math.tau/32),ry*math.sin(i*math.tau/32)-.015,z+h) for h in [0,height] for i in range(32)]
  faces=[(i,(i+1)%32,32+(i+1)%32,32+i) for i in range(32)]
  mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.materials.append(m)
  o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);return skin(o,bone)
 for o in list(bpy.data.objects):
  if o.type=='MESH' and any(s in o.name for s in ['wrapped dhoti','Dhoti woven']):bpy.data.objects.remove(o,do_unlink=True)
 body=next(o for o in bpy.data.objects if 'MakeHuman_body' in o.name)
 # The same skinned leg surface forms trousers and leather shoes, retaining weights.
 for name,low,high,m,inflate in [('Police full trousers',.095,.895,cotton,.016),('Police leather shoes',-.01,.105,leather,.006)]:
  o=body.copy();o.data=body.data.copy();bpy.context.collection.objects.link(o);o.name=name
  bm=bmesh.new();bm.from_mesh(o.data)
  bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z<low or v.co.z>high],context='VERTS');bm.to_mesh(o.data);bm.free()
  for v in o.data.vertices:
   center=Vector((.145 if v.co.x>0 else -.145,-.025,v.co.z));direction=v.co-center;direction.z=0
   if direction.length>0:v.co+=direction.normalized()*inflate
  o.data.materials.clear();o.data.materials.append(m)
  for p in o.data.polygons:p.material_index=0
 ring('Leather duty belt',.89,.229,.190,.048,leather,'pelvis')
 box('Plain belt buckle',(0,-.211,.915),(.047,.011,.041),brass,'pelvis')
 box('Tunic front placket',(0,-.240,1.165),(.025,.012,.24),blue,'spine_03')
 for z in [1.06,1.13,1.20,1.27]:
  bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=.006,location=(0,-.25,z));o=bpy.context.object;o.name='Tunic plain button';o.data.materials.append(brass);skin(o,'spine_03')
 ring('Standing cloth collar',1.36,.061,.067,.035,blue,'neck_01')
 # Headwear is purposefully differentiated without later regimental badges.
 for o in bpy.data.objects:
  if o.type=='MESH' and any(s in o.name for s in ['head wrap','Head wrap']):
   o.data.materials.clear();o.data.materials.append(blue)
 if role=='burkundaz':
  for j in range(5):
   o=ring('Sikh turban folded wrap',1.55+j*.023,.132-j*.005,.123-j*.003,.018,blue,'head');o.rotation_euler.y=.10 if j%2 else -.10
  # Layered beard follows the head, rather than being a floating prop.
  for j in range(5):
   bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=1,location=(0,-.106,1.455-j*.018));o=bpy.context.object;o.name='Sikh full beard layer';o.scale=(.068-j*.005,.038, .029)
   bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(hair);skin(o,'head')
 else:
  for o in list(bpy.data.objects):
   if o.type=='MESH' and any(s in o.name for s in ['head wrap','Head wrap']):bpy.data.objects.remove(o,do_unlink=True)
  ring('Indigo cloth cap',1.585,.092,.090,.065,blue,'head')
  bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=8,radius=1,location=(0,-.015,1.65));o=bpy.context.object;o.name='Cloth cap crown';o.scale=(.092,.09,.025)
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(blue);skin(o,'head')
 return {'uniform':'drab tunic/trousers, indigo facing, leather belt/shoes','identity':'Sikh turban and uncut beard' if role=='burkundaz' else 'cloth cap','historical_status':'fictional 1857 candidate; local pattern unverified'}
