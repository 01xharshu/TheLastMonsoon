"""Regularize garment corrective offsets without changing any human body data."""
import numpy as np

def smooth_offsets(obj,key,iterations=40,strength=.45):
 basis=obj.data.shape_keys.key_blocks['Basis']
 original=np.asarray([v.co[:] for v in basis.data],dtype=np.float64)
 displacement=np.asarray([v.co[:] for v in key.data],dtype=np.float64)-original
 edges=np.asarray([e.vertices[:] for e in obj.data.edges],dtype=np.int32)
 neighbors=np.concatenate([edges,edges[:,::-1]])
 counts=np.bincount(neighbors[:,0],minlength=len(displacement))
 for iteration in range(iterations):
  total=np.zeros_like(displacement)
  np.add.at(total,neighbors[:,0],displacement[neighbors[:,1]])
  average=total/np.maximum(counts[:,None],1)
  displacement+=(average-displacement)*strength*(counts[:,None]>0)
 for vertex,point in zip(key.data,original+displacement):vertex.co=point
