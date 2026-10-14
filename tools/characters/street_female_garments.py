"""Clothing and grooming over the retained, unchanged MakeHuman street body."""
import bpy,bmesh,math
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
from purpose_cloth_volume import VolumeSurface

def body_volume(body):
 bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();skin=body.evaluated_get(dg);mesh=skin.to_mesh();mesh.calc_loop_triangles()
 group=body.vertex_groups['body'].index
 human={v.index for v in body.data.vertices if any(g.group==group and g.weight>.5 for g in v.groups)}
 points=[skin.matrix_world@v.co for v in mesh.vertices]
 faces=[tuple(t.vertices) for t in mesh.loop_triangles if all(i in human for i in t.vertices)]
 tree=VolumeSurface.FromPolygons(points,faces,all_triangles=True,strict=True);skin.to_mesh_clear();return tree

def smooth_hems(obj):
 counts={}
 for face in obj.data.polygons:
  indices=list(face.vertices)
  for a,b in zip(indices,indices[1:]+indices[:1]):
   edge=tuple(sorted((a,b)));counts[edge]=counts.get(edge,0)+1
 neighbours={}
 for (a,b),count in counts.items():
  if count!=1:continue
  neighbours.setdefault(a,[]).append(b);neighbours.setdefault(b,[]).append(a)
 for iteration in range(4):
  points=[v.co.copy() for v in obj.data.vertices]
  for index,adjacent in neighbours.items():
   if len(adjacent)==2:obj.data.vertices[index].co=points[index].lerp((points[adjacent[0]]+points[adjacent[1]])*.5,.25)
 obj.data.update()

def natural_hairline(index):
 hair=bpy.data.objects.get('Farmer_hair')
 if hair is None:return
 original=bpy.data.objects.get('Street original MPFB hair')
 if original is None:
  original=hair.copy();original.data=hair.data.copy();bpy.context.collection.objects.link(original)
  original.name='Street original MPFB hair';original['street_source_only']=True;original.hide_render=True;original.hide_set(True)
 else:hair.data=original.data.copy()
 # Raise the retained fringe above the forehead; retain the existing braid/bun.
 for vertex in hair.data.vertices:
  p=vertex.co
  if p.z>1.40 and p.y<-.02:
   centre=1-min(1,abs(p.x)/.07)
   p.z=max(p.z,1.465+.012*centre)
 bm=bmesh.new();bm.from_mesh(hair.data)
 # A narrow deliberate scalp part in hair only; no human skin is removed.
 faces=[f for f in bm.faces if abs(f.calc_center_median().x)<.0035 and f.calc_center_median().y<-.025 and f.calc_center_median().z>1.465]
 bmesh.ops.delete(bm,geom=faces,context='FACES');bm.to_mesh(hair.data);bm.free();hair.data.update()
 hair['grooming']='Forehead-cleared central part; retained MPFB scalp, braid or bun'

def back_tail(rig,body,index,material):
 old=bpy.data.objects.get('Street sari back tail')
 if old:bpy.data.objects.remove(old,do_unlink=True)
 tree=body_volume(body);rows=12;columns=9;points=[];faces=[]
 blouse=bpy.data.objects['Street coherent cotton blouse and pallu']
 bpy.context.view_layer.update();evaluated=blouse.evaluated_get(bpy.context.evaluated_depsgraph_get());fabric=evaluated.to_mesh();fabric.calc_loop_triangles()
 cotton=BVHTree.FromPolygons([evaluated.matrix_world@v.co for v in fabric.vertices],[tuple(t.vertices) for t in fabric.loop_triangles],all_triangles=True)
 evaluated.to_mesh_clear()
 bottom=[.78,.86,.74,.80][index]
 for row in range(rows+1):
  t=row/rows;centre=-.125+.085*t;width=[.18,.14,.20,.16][index]
  for column in range(columns):
   x=centre+(column/(columns-1)-.5)*width
   shoulder=1.26-.045*abs(column/(columns-1)-.5)*2
   z=shoulder+(bottom-shoulder)*t
   hit=tree.ray_cast(Vector((x,.6,z)),Vector((0,-1,0)))
   surface=hit[0].y if hit[0] is not None else .10
   outer=cotton.ray_cast(Vector((x,.6,z)),Vector((0,-1,0)))
   if outer[0] is not None:surface=max(surface,outer[0].y+.018)
   loose=max(0,min(1,(t-.3)/.3));loose=loose*loose*(3-2*loose)
   y=max(surface+.026,(.20+.08*t)*loose)+.005*math.sin(column/(columns-1)*math.pi*4)*t
   points.append((x,y,z))
 for row in range(rows):
  for column in range(columns-1):
   a=row*columns+column;faces.append((a,a+1,a+columns+1,a+columns))
 mesh=bpy.data.meshes.new('Retained-body fitted cotton back tail');mesh.from_pydata(points,[],faces);mesh.update();mesh.materials.append(material)
 tail=bpy.data.objects.new('Street sari back tail',mesh);bpy.context.collection.objects.link(tail)
 tail.parent=rig;tail.matrix_parent_inverse=rig.matrix_world.inverted();tail.matrix_world=Matrix.Identity(4)
 for name in ['spine_02','spine_01','pelvis']:tail.vertex_groups.new(name=name)
 for row in range(rows+1):
  t=row/rows;upper=max(0,1-t*2);lower=max(0,(t-.45)/.55);middle=1-upper-lower
  indices=list(range(row*columns,(row+1)*columns))
  for name,weight in [('spine_02',upper),('spine_01',middle),('pelvis',lower)]:
   if weight>0:tail.vertex_groups[name].add(indices,weight,'REPLACE')
 tail.modifiers.new('Original MPFB rig','ARMATURE').object=rig
 for face in mesh.polygons:face.use_smooth=True
 tail['construction']='Cotton shoulder tail fitted around the complete retained MPFB body'
 return tail
