"""Map the delivered GLB's actual triangles onto unchanged source vertices."""
import bpy,json,struct
from mathutils import Vector
from mathutils.kdtree import KDTree
def native_triangles(rig,objects,path):
 raw=path.read_bytes();length=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+length]);binary=raw[28+length:]
 def values(index):
  accessor=doc['accessors'][index];view=doc['bufferViews'][accessor['bufferView']]
  fmt,size={5126:('f',4),5125:('I',4),5123:('H',2),5121:('B',1)}[accessor['componentType']]
  width={'SCALAR':1,'VEC3':3}[accessor['type']];stride=view.get('byteStride',width*size)
  offset=view.get('byteOffset',0)+accessor.get('byteOffset',0)
  return [struct.unpack_from('<'+fmt*width,binary,offset+i*stride) for i in range(accessor['count'])]
 previous=rig.data.pose_position;rig.data.pose_position='REST';bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();result={}
 for obj in objects:
  name='record_clerk_export_full_body' if obj.name=='record_clerk_MakeHuman_body' else obj.name
  node=next(n for n in doc['nodes'] if n.get('name')==name)
  ev=obj.evaluated_get(dg);mesh=ev.to_mesh();lookup=KDTree(len(mesh.vertices))
  for vertex in mesh.vertices:lookup.insert(ev.matrix_world@vertex.co,vertex.index)
  lookup.balance();faces=[];maximum=0
  for primitive in doc['meshes'][node['mesh']]['primitives']:
   mapping=[]
   for point in values(primitive['attributes']['POSITION']):
    _,index,distance=lookup.find(Vector((point[0],-point[2],point[1])));mapping.append(index);maximum=max(maximum,distance)
   ids=[v[0] for v in values(primitive['indices'])]
   faces.extend(tuple(mapping[index] for index in ids[i:i+3]) for i in range(0,len(ids),3))
  ev.to_mesh_clear()
  if maximum>.00001:raise RuntimeError('Native/source rest topology mismatch '+obj.name+': '+str(maximum))
  result[obj.name]=faces
 rig.data.pose_position=previous;bpy.context.view_layer.update()
 return result
