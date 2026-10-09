"""Oriented ray winding for the full skin volume, including overlapping folds."""
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import numpy as np

class VolumeSurface:
 """BVH broad phase, solid-angle confirmation for ray-positive points.

 Marching rays can skip one boundary of a skin fold thinner than their origin
 offset. Confirm their positive result against every oriented triangle instead
 of moving cloth away from an exterior point. The exact test is invariant under
 the Blender-to-Godot coordinate rotation.
 """
 @classmethod
 def FromPolygons(cls,vertices,faces,all_triangles=True,strict=True):
  if not all_triangles:raise ValueError('VolumeSurface requires frozen triangles')
  result=cls();result.tree=BVHTree.FromPolygons(vertices,faces,all_triangles=True);result.strict=strict
  result.triangles=np.asarray(vertices,dtype=np.float64)[np.asarray(faces,dtype=np.int32)]
  return result
 def find_nearest(self,point):return self.tree.find_nearest(point)
 def ray_cast(self,*args):return self.tree.ray_cast(*args)
 def exact_inside(self,point):
  triangles=self.triangles-np.asarray(point,dtype=np.float64)
  a,b,c=triangles[:,0],triangles[:,1],triangles[:,2]
  la,lb,lc=[np.linalg.norm(v,axis=1) for v in [a,b,c]]
  numerator=np.einsum('ij,ij->i',a,np.cross(b,c))
  denominator=la*lb*lc+np.einsum('ij,ij->i',a,b)*lc+np.einsum('ij,ij->i',b,c)*la+np.einsum('ij,ij->i',c,a)*lb
  return abs(np.arctan2(numerator,denominator).sum())>np.pi
_DIRECTIONS=[Vector((1,.173,.319)).normalized(),Vector((.271,1,.137)).normalized(),Vector((.193,.257,1)).normalized()]
def inside_surface(tree,point):
 if isinstance(tree,VolumeSurface) and not tree.strict:
  # Fitting needs many trial points. Only use the cheaper classification when
  # all six opposite rays agree; disputed folds still use the exact formula.
  # Acceptance audits keep strict=True and confirm every ray-positive point.
  windings=[]
  for direction in _DIRECTIONS+[-value for value in _DIRECTIONS]:
   cursor=point.copy();winding=0
   for hit in range(128):
    near,normal,face,distance=tree.ray_cast(cursor,direction,4.0)
    if near is None:break
    winding+=1 if normal.dot(direction)>0 else -1
    cursor=near+direction*.00001
   windings.append(winding!=0)
  if all(windings):return True
  if not any(windings):return False
  return tree.exact_inside(point)
 votes=0
 for index,direction in enumerate(_DIRECTIONS):
  cursor=point.copy();winding=0
  for hit in range(128):
   near,normal,face,distance=tree.ray_cast(cursor,direction,4.0)
   if near is None:break
   winding+=1 if normal.dot(direction)>0 else -1
   cursor=near+direction*.00001
  votes+=winding!=0
  if votes>=2:return tree.exact_inside(point) if isinstance(tree,VolumeSurface) else True
  if index+1-votes>=2:return False
 return votes>=2
