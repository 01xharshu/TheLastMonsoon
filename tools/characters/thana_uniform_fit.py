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
 for o in bpy.data.objects:
  if o.type=='MESH' and any(s in o.name for s in ['cotton upper','Kurta loose']):
   o.data.materials.clear();o.data.materials.append(cotton)
   for face in o.data.polygons:face.material_index=0
   for v in o.data.vertices:
    if .70<v.co.z<1.35:
     v.co.y+=.0018*math.sin(v.co.z*63+v.co.x*24)
 body=next(o for o in bpy.data.objects if o.name=='Uniform unmasked template')
 # The same skinned leg surface forms trousers and leather shoes, retaining weights.
 for name,low,high,m,inflate in [('Police full trousers',.095,.895,cotton,.016)]:
  o=body.copy();o.data=body.data.copy();bpy.context.collection.objects.link(o);o.name=name
  bm=bmesh.new();bm.from_mesh(o.data)
  bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z<low or v.co.z>high],context='VERTS');bm.to_mesh(o.data);bm.free()
  for v in o.data.vertices:
   center=Vector((.145 if v.co.x>0 else -.145,-.025,v.co.z));direction=v.co-center;direction.z=0
   if name=="Police leather shoes":v.co+=v.normal*inflate
   elif direction.length>0:v.co+=direction.normalized()*inflate
  o.data.materials.clear();o.data.materials.append(m)
  for p in o.data.polygons:p.material_index=0
 # Closed shoe uppers cover the toes instead of recolouring exposed foot geometry.
 for side,sign in [('l',1),('r',-1)]:
  levels=[(-.002,-.070,.065,.137),(.023,-.070,.066,.137),(.055,-.070,.064,.135),(.085,-.060,.062,.120),(.140,-.010,.055,.073),(.200,-.005,.053,.065)]
  verts=[(sign*.182+rx*math.cos(i*math.tau/32),cy+ry*math.sin(i*math.tau/32),z) for z,cy,rx,ry in levels for i in range(32)]
  faces=[(j*32+i,j*32+(i+1)%32,(j+1)*32+(i+1)%32,(j+1)*32+i) for j in range(len(levels)-1) for i in range(32)]
  faces.append(tuple(reversed(range(32))))
  mesh=bpy.data.meshes.new('Closed police shoe '+side);mesh.from_pydata(verts,[],faces);mesh.materials.append(leather)
  shoe=bpy.data.objects.new('Closed leather shoe '+side,mesh);bpy.context.collection.objects.link(shoe);skin(shoe,'foot_'+side)
  for face in mesh.polygons:face.use_smooth=True
  sole=mat('Worn shoe sole '+side,(.027,.022,.018))
  mesh.materials.append(sole)
  for face in mesh.polygons:
   if face.center.z<.036:face.material_index=1
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
   for face in o.data.polygons:face.material_index=0
 if role=='burkundaz':
  for j in range(5):
   o=ring('Sikh turban folded wrap',1.55+j*.023,.130-j*.004,.120-j*.003,.026,blue,'head')
   for v in o.data.vertices:v.co.z+=.006*math.sin(math.atan2(v.co.y+.015,v.co.x)*2+j*.7)
   for face in o.data.polygons:face.use_smooth=True
  # Layered beard follows the head, rather than being a floating prop.
  for label,loc,size in [('Full beard',(0,-.111,1.431),(.061,.038,.075)),('Moustache',(0,-.139,1.491),(.043,.012,.009)),('Left beard cheek',(.043,-.105,1.475),(.020,.027,.035)),('Right beard cheek',(-.043,-.105,1.475),(.020,.027,.035))]:
   bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=1,location=loc);o=bpy.context.object;o.name='Sikh '+label;o.scale=size
   bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
   for face in o.data.polygons:face.use_smooth=True
   o.data.materials.append(hair);skin(o,'head')
 else:
  for o in list(bpy.data.objects):
   if o.type=='MESH' and any(s in o.name for s in ['head wrap','Head wrap']):bpy.data.objects.remove(o,do_unlink=True)
  ring('Indigo cloth cap',1.585,.092,.090,.065,blue,'head')
  bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=8,radius=1,location=(0,-.015,1.65));o=bpy.context.object;o.name='Cloth cap crown';o.scale=(.092,.09,.025)
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(blue);skin(o,'head')
 return {'uniform':'drab tunic/trousers, indigo facing, leather belt/shoes','identity':'Sikh turban and uncut beard' if role=='burkundaz' else 'cloth cap','historical_status':'fictional 1857 candidate; local pattern unverified'}
