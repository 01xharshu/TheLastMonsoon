"""Constrain neighbouring pose keys together at interpolation contact samples."""
import bpy,math
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from village_cloth_fit import _fit_pose,sample_faces

def tree_for(body,extra=()):
 dg=bpy.context.evaluated_depsgraph_get();vertices=[];faces=[];skin_tree=None
 for obj in [body,*extra]:
  ev=obj.evaluated_get(dg);mesh=ev.to_mesh();offset=len(vertices)
  vertices.extend(ev.matrix_world@v.co for v in mesh.vertices)
  for p in mesh.polygons:
   if obj != body and skin_tree is not None:
    center=ev.matrix_world@p.center
    _,skin_normal,_,_=skin_tree.find_nearest(center)
    normal=ev.matrix_world.to_3x3().inverted().transposed()@p.normal
    if normal.dot(skin_normal)<.25:continue
   faces.append(tuple(i+offset for i in p.vertices))
  ev.to_mesh_clear()
  if obj == body:skin_tree=BVHTree.FromPolygons(vertices,faces)
 return BVHTree.FromPolygons(vertices,faces)

def refine(rig,body,objects,fit_layers=True):
 for track in rig.animation_data.nla_tracks:track.mute=True
 for obj in objects:
  keys=obj.data.shape_keys
  if keys.animation_data:
   keys.animation_data.action=None
   for track in keys.animation_data.nla_tracks:track.mute=True
 rig.data.pose_position='POSE';repairs=0
 for sweep in range(3):
  for clip,duration in [('idle',120),('walk',72)]:
   rig.animation_data.action=bpy.data.actions[clip]
   # Include authored poses so a neighbour constraint cannot invalidate an endpoint.
   for sample in range(duration*2+1):
    frame=1+sample/2;first=int(frame);fraction=frame-first
    active={}
    for obj in objects:
     keys=obj.data.shape_keys.key_blocks
     for key in keys:
      if key.name!='Basis':key.value=0
     a=keys[f'{clip} fit {first:03d}'];a.value=1-fraction
     active[obj]=[a]
     if fraction:
      b=keys[f'{clip} fit {first+1:03d}'];b.value=fraction;active[obj].append(b)
    bpy.context.scene.frame_set(first,subframe=fraction);bpy.context.view_layer.update()
    skin=tree_for(body)
    for obj in objects:
     inner_names={'Kurta loose lower panel':['Knee length wrapped dhoti'], 'Wrapped sari lower drape':['Fitted cotton upper base'], 'Woven sari pallu over blouse':['Fitted cotton upper base']}
     inner=[bpy.data.objects[n] for n in inner_names.get(obj.name,[])] if fit_layers or obj.name=='Kurta loose lower panel' else []
     tree=tree_for(body,inner) if inner else skin
     dg=bpy.context.evaluated_depsgraph_get();ev=obj.evaluated_get(dg);mesh=ev.to_mesh()
     mesh.calc_loop_triangles()
     points=[ev.matrix_world@v.co for v in mesh.vertices]+[ev.matrix_world@(sum((mesh.vertices[i].co for i in p),Vector())/len(p)) for p in sample_faces(mesh)]
     penetrate=False
     for point in points:
      near,normal,_,distance=tree.find_nearest(point)
      if (near-point).dot(normal)>.001:penetrate=True;break
     ev.to_mesh_clear()
     if penetrate:
      # Same rest-space displacement on both keys moves the interpolated surface
      # once, without splitting a correction across independent neighbouring poses.
      _fit_pose(rig,obj,tree,active[obj]);repairs+=1
   print('INTERPOLATION_FIT',body.name,sweep,clip,repairs,flush=True)
 for track in rig.animation_data.nla_tracks:track.mute=False
 rig.animation_data.action=None
 for obj in objects:
  for key in obj.data.shape_keys.key_blocks:
   if key.name!='Basis':key.value=0
  if obj.data.shape_keys.animation_data:
   for track in obj.data.shape_keys.animation_data.nla_tracks:track.mute=False
 bpy.context.scene.frame_set(1)
 return repairs
