"""Compare disposable native surface samples to their authoring source."""
import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree
ROOT=Path(__file__).resolve().parents[2]
folder=Path(sys.argv[sys.argv.index('--')+1])
sys.path.insert(0,str(ROOT/'tools/characters'))
from purpose_seat_topology import native_triangles
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/record_clerk/desk_study/record_clerk_seat.blend'))
rig=bpy.data.objects['record_clerk_rig'];rig.animation_data.action=bpy.data.actions['seat_entry'];rig.data.pose_position='POSE'
samples=sorted(folder.glob("clerk_*.json"))
for sample in [14,31]:
 phase=sample/(len(samples)-1);position=phase*120;first=int(position);fraction=position-first
 for obj in bpy.data.objects:
  if obj.type=='MESH' and obj.data.shape_keys:
   for key in obj.data.shape_keys.key_blocks:
    if key.name.startswith(('Walk cloth ','Seat cloth ')):
     key.value=1-fraction if key.name=='Seat cloth %02d'%first else fraction if key.name=='Seat cloth %02d'%(first+1) else 0
 frame=1+phase*60;bpy.context.scene.frame_set(int(frame),subframe=frame%1);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
 data=json.loads((folder/('clerk_%02d.json'%sample)).read_text())
 saved=[]
 for o in bpy.data.objects:
  if o.type=='MESH' and o.data.shape_keys:
   for k in o.data.shape_keys.key_blocks:
    if k.name.startswith(('Walk cloth ','Seat cloth ')):saved.append((k,k.value));k.value=0
 objects=[bpy.data.objects['record_clerk_MakeHuman_body']]+[bpy.data.objects[e['name']] for e in data['garments']]
 frozen=native_triangles(rig,objects,ROOT/'characters/npcs/review/record_clerk_seat.glb')
 for k,v in saved:k.value=v
 bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
 for entry in data['body']+data['garments']:
  name=entry['name'];obj=bpy.data.objects['record_clerk_MakeHuman_body' if 'export_full_body' in name else name]
  mapping=None
  if 'rest_vertices' in entry:
   shape_values=[]
   if obj.data.shape_keys:
    for k in obj.data.shape_keys.key_blocks:
     if k.name.startswith(('Walk cloth ','Seat cloth ')):shape_values.append((k,k.value));k.value=0
   rig.data.pose_position='REST';bpy.context.view_layer.update();rest_ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());rest_mesh=rest_ev.to_mesh();lookup=KDTree(len(rest_mesh.vertices))
   for vertex in rest_mesh.vertices:lookup.insert(rest_ev.matrix_world@vertex.co,vertex.index)
   lookup.balance();mapping=[lookup.find(Vector((point[0],-point[2],point[1])))[1] for point in entry['rest_vertices']]
   rest_ev.to_mesh_clear()
   for k,v in shape_values:k.value=v
   rig.data.pose_position='POSE';bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
  ev=obj.evaluated_get(dg);mesh=ev.to_mesh();tree=KDTree(len(mesh.vertices))
  for vertex in mesh.vertices:tree.insert(ev.matrix_world@vertex.co,vertex.index)
  tree.balance();errors=[]
  for point in entry['vertices']:
   point=Vector((point[0],-point[2],point[1]))
   if point.z>1.1:continue # Native head observation is deliberately independent.
   errors.append(tree.find(point)[2])
  if mapping is not None:
   ids=entry['indices'];native_faces={tuple(sorted(mapping[i] for i in ids[j:j+3])) for j in range(0,len(ids),3)};frozen_faces={tuple(sorted(f)) for f in frozen[obj.name]}
   print('FACE_MAPPING_DIFFERENCES',name,len(native_faces-frozen_faces),len(frozen_faces-native_faces),flush=True)
   if 'export_full_body' in name:
    def oriented(face):return min(tuple(face[i:]+face[:i]) for i in range(3))
    native_oriented=set()
    for j in range(0,len(ids),3):
     face=[mapping[i] for i in ids[j:j+3]]
     if entry.get('winding_sign',1)<0:face.reverse()
     native_oriented.add(oriented(face))
    original_oriented={oriented(list(face)) for face in frozen[obj.name]}
    print('BODY_WINDING_DIFFERENCES',len(native_oriented-original_oriented),'sign',entry.get('winding_sign'),flush=True)
    from mathutils.bvhtree import BVHTree
    source_tree=BVHTree.FromPolygons([ev.matrix_world@v.co for v in mesh.vertices],frozen[obj.name],all_triangles=True)
    if sample==31:
     import numpy as np
     from purpose_cloth_volume import inside_surface
     disputed=Vector((-.02119288221001625,-.06075752526521683,.4044097363948822))
     native_points=[Vector((p[0],-p[2],p[1])) for p in entry['vertices']]
     native_faces=[tuple(reversed(ids[j:j+3])) if entry.get('winding_sign',1)<0 else tuple(ids[j:j+3]) for j in range(0,len(ids),3)]
     native_tree=BVHTree.FromPolygons(native_points,native_faces,all_triangles=True)
     tris=np.asarray(native_points,dtype=np.float64)[np.asarray(native_faces)]-np.asarray(disputed)
     a,b,c=tris[:,0],tris[:,1],tris[:,2]
     la,lb,lc=[np.linalg.norm(v,axis=1) for v in [a,b,c]]
     numerator=np.einsum('ij,ij->i',a,np.cross(b,c))
     denominator=la*lb*lc+np.einsum('ij,ij->i',a,b)*lc+np.einsum('ij,ij->i',b,c)*la+np.einsum('ij,ij->i',c,a)*lb
     winding=np.arctan2(numerator,denominator).sum()/(2*math.pi)
     print('DISPUTED_NATIVE_WINDING',winding,'native_ray',inside_surface(native_tree,disputed),'source_ray',inside_surface(source_tree,disputed),flush=True)
     raw_tree=BVHTree.FromPolygons(entry['vertices'],native_faces,all_triangles=True)
     raw_point=Vector((disputed.x,disputed.z,-disputed.y))
     from purpose_cloth_volume import _DIRECTIONS
     for direction in _DIRECTIONS:
      cursor=raw_point.copy();trace=[]
      for hit in range(128):
       near,normal,face,distance=raw_tree.ray_cast(cursor,direction,4)
       if near is None:break
       trace.append((face,1 if normal.dot(direction)>0 else -1,distance))
       cursor=near+direction*.00001
      print('DISPUTED_RAW_RAY',trace,'winding',sum(item[1] for item in trace),flush=True)


    point=Vector((.088142924,-.203314707,.594310284));near,normal,_,distance=source_tree.find_nearest(point)
    print('SOURCE_WORST_NATIVE_POINT',list(near),list(normal),'depth', (near-point).dot(normal),flush=True)
   maximum=0;worst=None
   for i,raw in enumerate(entry['vertices']):
    actual=Vector((raw[0],-raw[2],raw[1]));expected=ev.matrix_world@mesh.vertices[mapping[i]].co
    if actual.z>1.1:continue
    error=(actual-expected).length
    if error>maximum:maximum=error;worst=(i,mapping[i],list(actual),list(expected))
   print('BODY_VERTEX_CORRESPONDENCE',maximum,'worst',worst,flush=True)
  print('SOURCE_NATIVE_SURFACE',sample,name,'max_mm',max(errors,default=0)*1000,'rms_mm',math.sqrt(sum(e*e for e in errors)/max(1,len(errors)))*1000,'source_world',obj.matrix_world,flush=True)
  ev.to_mesh_clear()
