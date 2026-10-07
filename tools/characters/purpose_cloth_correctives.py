"""Pose-fitted cloth corrections over intact MPFB bodies, seventy-two wrap walk samples."""
import bpy,math,json
from mathutils import Matrix,Vector

def fit_walk_cloth(rig,body,role):
 names=['Fitted cotton upper base','Knee length wrapped dhoti','Dhoti woven border',
        'Wide madder waist sash','Narrow indigo waist binding',
        'Porter fitted short work trousers','Clerk full length trousers','Clerk buttoned sleeveless waistcoat']
 objects=[bpy.data.objects[n] for n in names if n in bpy.data.objects]
 scene=bpy.context.scene;rig.data.pose_position='REST';bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
 for obj in objects:
  if any(m.type in ['MASK','SOLIDIFY'] for m in obj.modifiers):
   obj.data=bpy.data.meshes.new_from_object(obj.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
   for m in list(obj.modifiers):
    if m.type in ['MASK','SOLIDIFY']:obj.modifiers.remove(m)
  if obj.name in ['Knee length wrapped dhoti','Dhoti woven border','Wide madder waist sash','Narrow indigo waist binding']:
   import bmesh
   bm=bmesh.new();bm.from_mesh(obj.data)
   bmesh.ops.subdivide_edges(bm,edges=list(bm.edges),cuts=2,use_grid_fill=True)
   bm.to_mesh(obj.data);bm.free()
  if obj.name in ['Knee length wrapped dhoti','Dhoti woven border']:obj.shape_key_add(name='Basis')
 objects=[o for o in objects if o.name in ['Knee length wrapped dhoti','Dhoti woven border']]
 rig.data.pose_position='POSE';rig.animation_data.action=bpy.data.actions['walk']
 report={}
 for sample in range(72):
  frame=1+sample/72*36;scene.frame_set(int(frame),subframe=frame%1);bpy.context.view_layer.update()
  dg=bpy.context.evaluated_depsgraph_get();evaluated=body.evaluated_get(dg);skin_mesh=evaluated.to_mesh()
  body_points=[body.matrix_world@v.co for v in skin_mesh.vertices]
  leg_groups={g.index for g in body.vertex_groups if g.name=='pelvis' or g.name.startswith(('thigh_','calf_'))}
  leg_points=[body_points[v.index] for v in skin_mesh.vertices if sum(g.weight for g in v.groups if g.group in leg_groups)>.5]
  evaluated.to_mesh_clear()
  hull_cache={}
  def wrap_surface(world,normal):
   band=round(world.z/.015)
   if band not in hull_cache:
    points=sorted(set((p.x,p.y) for p in leg_points if abs(p.z-band*.015)<.025))
    def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    lower=[];upper=[]
    for point in points:
     while len(lower)>1 and cross(lower[-2],lower[-1],point)<=0:lower.pop()
     lower.append(point)
    for point in reversed(points):
     while len(upper)>1 and cross(upper[-2],upper[-1],point)<=0:upper.pop()
     upper.append(point)
    hull_cache[band]=lower[:-1]+upper[:-1]
   hull=hull_cache[band]
   if len(hull)<3:return world
   center=Vector(((min(p[0] for p in hull)+max(p[0] for p in hull))*.5,(min(p[1] for p in hull)+max(p[1] for p in hull))*.5,world.z))
   direction=world-center;direction.z=0;direction.normalize()
   radius=10.0
   for i,a in enumerate(hull):
    b=hull[(i+1)%len(hull)];out=Vector((b[1]-a[1],a[0]-b[0],0))
    denominator=out.dot(direction)
    if denominator>1e-8:radius=min(radius,out.dot(Vector((a[0],a[1],world.z))-center)/denominator)
   clearance=.037 if normal.dot(direction)>0 else .035
   return center+direction*(radius+clearance)

  for obj in objects:
   posed=obj.evaluated_get(dg);mesh=posed.to_mesh();key=obj.shape_key_add(name='Walk cloth %02d'%sample)
   maximum=0;count=0
   to_rig=rig.matrix_world.inverted()@obj.matrix_world
   original=[posed.matrix_world@v.co for v in mesh.vertices]
   # Wrap cloth spans both legs. Fit its continuous cross-section around the
   # posed legs; generic nearest-surface projection spikes layered upper cloth.
   desired=[wrap_surface(p,posed.matrix_world.to_3x3()@mesh.vertices[i].normal)
            for i,p in enumerate(original)]
   for v in obj.data.vertices:
    shift=desired[v.index]-original[v.index]
    if shift.length>.00001:
     blend=Matrix.Identity(4)*0;total=0
     for assignment in v.groups:
      bone=rig.pose.bones.get(obj.vertex_groups[assignment.group].name)
      if bone:
       blend+=(bone.matrix@bone.bone.matrix_local.inverted())*assignment.weight;total+=assignment.weight
     if total:blend*=1/total
     else:blend=Matrix.Identity(4)
     correction=to_rig.inverted().to_3x3()@blend.inverted_safe().to_3x3()@rig.matrix_world.inverted().to_3x3()@shift
     key.data[v.index].co=v.co+correction;maximum=max(maximum,correction.length);count+=1
   posed.to_mesh_clear();key.value=0
   report.setdefault(obj.name,[]).append({'sample':sample,'corrected_vertices':count,'max_rest_correction_m':maximum})
 for obj in objects:obj['cloth_correctives']='Seventy-two original full-body walk poses; applied by NPC driver with interpolation'
 from purpose_local_cloth import fit_local_walk_cloth
 fit_local_walk_cloth(rig,body)
 rig.animation_data.action=bpy.data.actions['idle'];scene.frame_set(1)
 return report
