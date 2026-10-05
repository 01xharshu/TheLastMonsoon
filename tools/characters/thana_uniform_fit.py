"""Original low-poly uniform fittings; all pieces deform with the MPFB rig.
1857 fictional district design candidate, not a verified regulation pattern.
"""
import bpy, math, bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
from mathutils.geometry import closest_point_on_tri

def fit_uniform(rig,role):
 def mat(name,color):
  m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
  p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.84
  return m
 cotton=mat('Police drab cotton',(.62,.47,.29));blue=mat('Police tan fittings',(.57,.43,.26));leather=mat('Police worn leather',(.19,.075,.035));brass=mat('Plain brass fastenings',(.46,.32,.10));hair=mat('Sikh uncut beard',(.018,.012,.009))
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
  # Rounded folded edge gives cloth courses depth without a new texture atlas.
  profile=[(0,0),(.002,height*.12),(.002,height*.88),(0,height)]
  verts=[((rx+lip)*math.cos(i*math.tau/48),(ry+lip)*math.sin(i*math.tau/48)-.015,z+h) for lip,h in profile for i in range(48)]
  faces=[(j*48+i,j*48+(i+1)%48,(j+1)*48+(i+1)%48,(j+1)*48+i) for j in range(3) for i in range(48)]
  mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.materials.append(m)
  o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
  for face in mesh.polygons:face.use_smooth=True
  return skin(o,bone)
 for o in list(bpy.data.objects):
  if o.type=='MESH' and any(s in o.name for s in ['wrapped dhoti','Dhoti woven']):bpy.data.objects.remove(o,do_unlink=True)
 for o in bpy.data.objects:
  if o.type=='MESH' and any(s in o.name for s in ['cotton upper','Kurta loose']):
   o.data.materials.clear();o.data.materials.append(cotton)
   for face in o.data.polygons:face.material_index=0
   for v in o.data.vertices:
    if 'Kurta loose' in o.name:
     ease=max(0,min(1,(.92-v.co.z)/.26))
     v.co.x=(v.co.x-.008)*(1+.25*ease)+.008
     v.co.y=v.co.y*(.85+.47*ease)-.025*(1-ease)
    if .70<v.co.z<1.35:
     v.co.y+=.0018*math.sin(v.co.z*63+v.co.x*24)
 body=next(o for o in bpy.data.objects if o.name=='Uniform unmasked template')
 # Separate opaque adult foundation; never cut the original human body.
 foundation=body.copy();foundation.data=body.data.copy();foundation.name='Opaque adult police foundation'
 bpy.context.collection.objects.link(foundation)
 bm=bmesh.new();bm.from_mesh(foundation.data)
 bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z<.69 or v.co.z>.93],context='VERTS');bm.to_mesh(foundation.data);bm.free()
 for vertex in foundation.data.vertices:vertex.co+=vertex.normal*.003
 foundation.data.materials.clear();foundation.data.materials.append(mat('Opaque police foundation cotton',(.22,.16,.10)))
 for face in foundation.data.polygons:face.material_index=0
 foundation['presentation']='Separate opaque adult foundation beneath uniform'

 # Reuse the MakeHuman leg topology and deform weights for loose trousers.
 for name,low,high,m,inflate in [('Police full trousers',.095,.895,cotton,.016)]:
  o=body.copy();o.data=body.data.copy();bpy.context.collection.objects.link(o);o.name=name
  bm=bmesh.new();bm.from_mesh(o.data)
  bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z<low or v.co.z>high],context='VERTS');bm.to_mesh(o.data);bm.free()
  for v in o.data.vertices:
   center=Vector((.145 if v.co.x>0 else -.145,-.025,v.co.z));direction=v.co-center;direction.z=0
   if direction.length>0:
    # Extra ease through thigh/knee; taper into the shoe instead of skin-tight legs.
    ease=.010 if v.co.z<.49 else inflate+.060*math.sin(math.pi*max(0,min(1,(v.co.z-.49)/(high-.49))))
    v.co+=direction.normalized()*ease
  o.data.materials.clear();o.data.materials.append(m)
  for p in o.data.polygons:p.material_index=0
 # Wrapped lower legs use the same MPFB-derived clothing topology and weights.
 trousers=bpy.data.objects.get('Police full trousers')
 wraps=trousers.copy();wraps.data=trousers.data.copy();wraps.name='Tan wrapped puttees';bpy.context.collection.objects.link(wraps)
 bm=bmesh.new();bm.from_mesh(wraps.data)
 bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z<.18 or v.co.z>.49],context='VERTS');bm.to_mesh(wraps.data);bm.free()
 for vertex in wraps.data.vertices:
  vertex.co+=vertex.normal*(.004+.0015*math.cos(vertex.co.z*math.tau/.032))
 wraps.data.materials.clear();wraps.data.materials.append(mat('Police puttee cloth',(.57,.43,.26)))
 for face in wraps.data.polygons:face.material_index=0
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
 upper=next(o for o in bpy.data.objects if o.type=='MESH' and 'cotton upper' in o.name)
 points=[upper.matrix_world@v.co for v in upper.data.vertices]
 surface_points=list(points);surface_faces=[list(p.vertices) for p in upper.data.polygons]
 source_weights=[{upper.vertex_groups[g.group].name:g.weight for g in v.groups} for v in upper.data.vertices]
 for panel in [o for o in bpy.data.objects if o.type=='MESH' and 'Kurta loose' in o.name]:
  offset=len(surface_points);surface_points.extend(panel.matrix_world@v.co for v in panel.data.vertices)
  surface_faces.extend([offset+i for i in face.vertices] for face in panel.data.polygons)
  source_weights.extend({panel.vertex_groups[g.group].name:g.weight for g in v.groups} for v in panel.data.vertices)
 surface=BVHTree.FromPolygons(surface_points,surface_faces)
 nearest=KDTree(len(points))
 for i,point in enumerate(points):nearest.insert(point,i)
 nearest.balance()
 def front(x,z):
  hit=surface.ray_cast(Vector((x,-1,z)),Vector((0,1,0)),2)[0]
  return hit+Vector((0,-.003,0)) if hit is not None else Vector((x,-.23,z))
 def cloth_skin(o):
  # Use the source garment's deform weights so the strip follows torso bends.
  names=set(name for weights in source_weights for name in weights)
  for name in sorted(names):o.vertex_groups.new(name=name)
  for vertex in o.data.vertices:
   point=o.matrix_world@vertex.co
   contact,normal,face_id,distance=surface.find_nearest(point)
   indices=surface_faces[face_id]
   best=None
   for j in range(1,len(indices)-1):
    ids=[indices[0],indices[j],indices[j+1]];a,b,c=[surface_points[k] for k in ids]
    q=closest_point_on_tri(contact,a,b,c)
    if best is None or (q-contact).length<best[0]:best=((q-contact).length,ids,q)
   _,ids,q=best;a,b,c=[surface_points[k] for k in ids]
   u=b-a;v=c-a;w=q-a;uu=u.dot(u);uv=u.dot(v);vv=v.dot(v)
   determinant=uu*vv-uv*uv
   beta=(vv*w.dot(u)-uv*w.dot(v))/determinant if abs(determinant)>1e-12 else 0
   gamma=(uu*w.dot(v)-uv*w.dot(u))/determinant if abs(determinant)>1e-12 else 0
   weights={}
   for k,amount in zip(ids,[1-beta-gamma,beta,gamma]):
    for name,weight in source_weights[k].items():weights[name]=weights.get(name,0)+max(0,amount)*weight
   total=sum(weights.values())
   for name,weight in weights.items():
    if weight>1e-6:o.vertex_groups[name].add([vertex.index],weight/total,'REPLACE')
  o.parent=rig;o.matrix_parent_inverse=rig.matrix_world.inverted()
  mod=o.modifiers.new('Clothing deform','ARMATURE');mod.object=rig
 # Surface-fitted belt, with the same garment weights as the fabric beneath it.
 belt_vertices=[]
 belt_rows=9
 for z in [.89+j*.048/(belt_rows-1) for j in range(belt_rows)]:
  for i in range(64):
   angle=i*math.tau/64;direction=Vector((math.cos(angle),math.sin(angle),0))
   origin=Vector((0,-.015,z))+direction*.30
   hit=surface.ray_cast(origin,-direction,.60)[0]
   belt_vertices.append(hit+direction*.007 if hit is not None else Vector((.229*direction.x,.19*direction.y-.015,z)))
 belt_faces=[(j*64+i,j*64+(i+1)%64,(j+1)*64+(i+1)%64,(j+1)*64+i) for j in range(belt_rows-1) for i in range(64)]
 belt_mesh=bpy.data.meshes.new('Fitted duty belt');belt_mesh.from_pydata(belt_vertices,[],belt_faces);belt_mesh.materials.append(leather)
 belt=bpy.data.objects.new('Leather duty belt',belt_mesh);bpy.context.collection.objects.link(belt);cloth_skin(belt)
 for face in belt_mesh.polygons:face.use_smooth=True
 def patch(name,x0,x1,z0,z1,material,clearance=0,thickness=0):
  n=8;vertices=[front(x0+(x1-x0)*i/n,z0+(z1-z0)*j/n)+Vector((0,-clearance,0)) for j in range(n+1) for i in range(n+1)]
  faces=[(j*(n+1)+i,j*(n+1)+i+1,(j+1)*(n+1)+i+1,(j+1)*(n+1)+i) for j in range(n) for i in range(n)]
  if thickness>0:
   boundary=[i for i in range(n+1)]+[j*(n+1)+n for j in range(1,n+1)]+[n*(n+1)+i for i in range(n-1,-1,-1)]+[j*(n+1) for j in range(n-1,0,-1)]
   count=len(vertices);vertices.extend(v+Vector((0,thickness,0)) for v in list(vertices))
   faces.extend((i,boundary[(j+1)%len(boundary)],count+boundary[(j+1)%len(boundary)],count+i) for j,i in enumerate(boundary))
  mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.materials.append(material)
  o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);cloth_skin(o)
  for face in mesh.polygons:face.use_smooth=True
  return o
 # Narrow buckle frame wraps the fitted belt; its centre remains leather.
 for x0,x1,z0,z1 in [(-.023,-.018,.893,.935),(.018,.023,.893,.935),(-.023,.023,.893,.898),(-.023,.023,.930,.935)]:
  patch('Belt buckle frame',x0,x1,z0,z1,brass,.006)
 # Pocket bags/flaps sit millimetres above the actual tunic and share its weights.
 pocket_cloth=mat('Police drab cotton pocket',(.595,.445,.275))
 for side in [-1,1]:
  for z0,z1,cx,width in [(1.12,1.205,.10,.074),(.755,.825,.115,.080)]:
   cx*=side
   patch('Tunic sewn pocket',cx-width/2,cx+width/2,z0,z1,pocket_cloth)
   patch('Tunic attached pocket flap',cx-width/2,cx+width/2,z1-.022,z1+.005,cotton,.004)
   patch('Pocket centre pleat',cx-.003,cx+.003,z0+.004,z1-.022,blue,.002)
 patch('Attached brown belt pouch',.14,.20,.79,.94,leather,.012,.010)
 patch('Attached brown pouch flap',.14,.20,.912,.945,leather,.014,.004)
 # Diagonal leather strap fitted to both front and back of the tunic.
 def strap(back=False):
  vertices=[];n=40
  for j in range(n+1):
   t=j/n;z=1.355-t*.425;cx=-.17+t*(.29 if back else .33)
   for x in [cx-.013,cx+.013]:
    if back:
     hit=surface.ray_cast(Vector((x,1,z)),Vector((0,-1,0)),2)[0]
     q=hit+Vector((0,.006,0)) if hit is not None else surface.find_nearest(Vector((x,.15,z)))[0]+Vector((0,.006,0))
    else:q=front(x,z)+Vector((0,-.007,0))
    vertices.append(q)
  faces=[(j*2,j*2+1,j*2+3,j*2+2) for j in range(n)]
  if back:faces=[tuple(reversed(face)) for face in faces]
  mesh=bpy.data.meshes.new('Fitted diagonal leather strap');mesh.from_pydata(vertices,[],faces);mesh.materials.append(leather)
  o=bpy.data.objects.new('Reference diagonal strap '+('back' if back else 'front'),mesh);bpy.context.collection.objects.link(o);cloth_skin(o)
  for face in mesh.polygons:face.use_smooth=True
 strap();strap(True)
 # Plain shoulder cloth tabs follow the garment surface; no invented rank badge.
 for sign in [-1,1]:
  vertices=[]
  for x in [sign*(.14+j*.09/8) for j in range(9)]:
   for y in [-.035,.025]:
    hit,normal,_,_=surface.find_nearest(Vector((x,y,1.415)))
    vertices.append(hit+normal*.004)
  faces=[(j*2,j*2+1,j*2+3,j*2+2) for j in range(8)]
  mesh=bpy.data.meshes.new('Attached shoulder cloth tab');mesh.from_pydata(vertices,[],faces);mesh.materials.append(blue)
  o=bpy.data.objects.new('Attached shoulder tab',mesh);bpy.context.collection.objects.link(o);cloth_skin(o)
 rows=17
 vertices=[front(x,1.045+j*.24/(rows-1)) for j in range(rows) for x in [-.0125,.0125]]
 faces=[(j*2,j*2+1,j*2+3,j*2+2) for j in range(rows-1)]
 mesh=bpy.data.meshes.new('Surface fitted tunic placket');mesh.from_pydata(vertices,[],faces);mesh.materials.append(blue)
 placket=bpy.data.objects.new('Tunic fitted front placket',mesh);bpy.context.collection.objects.link(placket)
 cloth_skin(placket)
 for face in mesh.polygons:face.use_smooth=True
 for z in [1.01,1.075,1.14,1.205,1.27,1.335]:
  bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=.0045,location=front(0,z)+Vector((0,-.003,0)))
  o=bpy.context.object;o.name='Tunic plain button';o.data.materials.append(brass);cloth_skin(o)
 ring('Standing cloth collar',1.36,.061,.067,.035,blue,'neck_01')
 # Remove the source farmer wrap before fitting either police headwear variant.
 for o in list(bpy.data.objects):
  if o.type=='MESH' and 'head wrap' in o.name.lower():bpy.data.objects.remove(o,do_unlink=True)
 if role=='burkundaz':
  # Continuous underlying cloth prevents sky/skin gaps between overlapping folds.
  core=ring('Turban underlying cloth',1.55,.104,.099,.120,blue,'head')
  for vertex in core.data.vertices:
   taper=1-.16*max(0,min(1,(vertex.co.z-1.55)/.12))
   vertex.co.x*=taper;vertex.co.y=(vertex.co.y+.015)*taper-.015
  bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=12,radius=1,location=(0,-.015,1.669))
  crown=bpy.context.object;crown.name='Turban cloth crown';crown.scale=(.088,.084,.026)
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  crown.data.materials.append(blue)
  for face in crown.data.polygons:face.use_smooth=True
  skin(crown,'head')
  for j in range(7):
   o=ring('Sikh turban folded wrap',1.555+j*.016,.112-j*.004,.106-j*.0035,.023,blue,'head')
   for v in o.data.vertices:
    angle=math.atan2(v.co.y+.015,v.co.x)
    v.co.z+=.018*math.sin(angle+(0.85 if j%2 else -.85))
    # Crossing cloth courses retain overlap rather than separate horizontal hoops.
    v.co.y-=.004*math.cos(angle*2+j*.65)
   for face in o.data.polygons:face.use_smooth=True
  # Layered beard follows the head, rather than being a floating prop.
  for label,loc,size in [('Full beard',(0,-.111,1.431),(.061,.038,.075)),('Moustache',(0,-.139,1.491),(.043,.012,.009)),('Left beard cheek',(.043,-.105,1.475),(.020,.027,.035)),('Right beard cheek',(-.043,-.105,1.475),(.020,.027,.035))]:
   bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=1,location=loc);o=bpy.context.object;o.name='Sikh '+label;o.scale=size
   bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
   # Hair envelope, not skin: break the smooth oval silhouette with fine clumps.
   for vertex in o.data.vertices:
    if label=='Full beard':
     depth=max(0,min(1,(-vertex.co.z+.02)/.095))
     vertex.co.x*=1-.16*depth
     vertex.co.y+=.0018*math.sin(vertex.co.x*420+vertex.co.z*150)*depth
     vertex.co.z-=.002*depth*(.5+.5*math.sin(vertex.co.x*330))
   for face in o.data.polygons:face.use_smooth=True
   o.data.materials.append(hair);skin(o,'head')
 else:
  for o in list(bpy.data.objects):
   if o.type=='MESH' and any(s in o.name for s in ['head wrap','Head wrap']):bpy.data.objects.remove(o,do_unlink=True)
  ring('Indigo cloth cap',1.585,.092,.090,.065,blue,'head')
  bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=8,radius=1,location=(0,-.015,1.65));o=bpy.context.object;o.name='Cloth cap crown';o.scale=(.092,.09,.025)
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(blue);skin(o,'head')
 return {'uniform':'owner-reference tan tunic/trousers/headwear, fitted brown leather belt/shoes','identity':'Sikh turban and uncut beard' if role=='burkundaz' else 'cloth cap','historical_status':'fictional 1857 candidate; local pattern unverified'}
