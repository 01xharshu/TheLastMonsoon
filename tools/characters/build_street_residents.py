"""Private street variants: articulated wrapped lower cloth and shaped leather shoes."""
import bpy, math, sys, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
role=sys.argv[sys.argv.index('--')+1]
private_source=ROOT/f'WorkingAssets/NPCs/street_residents/{role}/{role}.blend'
bpy.ops.wm.open_mainfile(filepath=str(private_source if private_source.exists() else ROOT/f'WorkingAssets/NPCs/households/{role}/{role}.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
rig.data.pose_position='REST'
# Close the shirt over the new waist fold instead of leaving navy panels inside the wrap.
import bmesh
shirt=bpy.data.objects['Fitted cotton upper base']
bm=bmesh.new();bm.from_mesh(shirt.data)
bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=(0,0,.985),plane_no=(0,0,1),clear_inner=True)
bm.to_mesh(shirt.data);bm.free()
cream=(bpy.data.objects.get('Street folded dhoti l') or bpy.data.objects['Knee length wrapped dhoti']).data.materials[0]
leather=(bpy.data.objects.get('Street leather shoe l') or bpy.data.objects['Leather shoe l']).data.materials[0]
for o in list(bpy.data.objects):
 if o.name.startswith(('Knee length wrapped dhoti','Dhoti woven border','Leather shoe','Street dhoti','Street folded dhoti','Street leather shoe','Street opaque foundation')):bpy.data.objects.remove(o,do_unlink=True)
def mesh(name,verts,faces,material,weight):
 data=bpy.data.meshes.new(name);data.from_pydata(verts,[],[tuple(reversed(face)) for face in faces]);data.materials.append(material)
 o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o)
 for poly in data.polygons:poly.use_smooth=True
 for i,v in enumerate(verts):
  for bone,w in weight(v).items():
   g=o.vertex_groups.get(bone) or o.vertex_groups.new(name=bone);g.add([i],w,'REPLACE')
 mod=o.modifiers.new('Independent garment skin','ARMATURE');mod.object=rig;o.parent=rig
 return o
# Continuous waist fold closes the seam above the two moving leg wraps.
verts=[];faces=[]
for row in range(4):
 for col in range(48):
  a=col/48*math.tau;verts.append((.237*math.cos(a),-.007+.175*math.sin(a),1.018-row*.025))
for row in range(3):
 for col in range(48):
  a=row*48+col;b=row*48+(col+1)%48;faces.append((a,b,b+48,a+48))
mesh('Street dhoti waist fold',verts,faces,cream,lambda v:{'pelvis':1})
# Two continuous loose leg wraps: thigh motion reaches the hem without a pelvis-only skirt cutting through knees.
for side,sign in [('l',1),('r',-1)]:
 verts=[];faces=[];N=48;R=12
 for row in range(R+1):
  t=row/R;z=1.00-t*.51;cx=sign*(.115+.067*t)
  for col in range(N):
   a=2*math.pi*col/N;pleat=.006*math.cos(a*8+t*.6)
   verts.append((cx+(.122+pleat)*math.cos(a),-.007+(.147+pleat)*math.sin(a),z))
 for row in range(R):
  for col in range(N):
   a=row*N+col;b=row*N+(col+1)%N;faces.append((a,b,b+N,a+N))
 def weights(v):
  t=max(0,min(1,(.98-v[2])/.24));t=t*t*(3-2*t);return {'pelvis':1-t,'thigh_'+side:t}
 cloth=mesh('Street folded dhoti '+side,verts,faces,cream,weights)
 sol=cloth.modifiers.new('Folded cloth edge','SOLIDIFY');sol.thickness=.004
 # Shaped closed shoe: flat sole, narrower heel, low vamp and squared rounded toe.
 verts=[];faces=[];sections=[(-.300,.026,.031),(-.282,.052,.038),(-.235,.056,.047),(-.170,.051,.062),(-.105,.044,.071),(-.055,.037,.046),(-.039,.025,.032)]
 for y,width,height in sections:
  for col in range(16):
   a=2*math.pi*col/16
   verts.append((sign*.184+math.cos(a)*width,y,.004+max(0,math.sin(a))*height))
 for row in range(len(sections)-1):
  for col in range(16):
   a=row*16+col;b=row*16+(col+1)%16;faces.append((a,b,b+16,a+16))
 faces.extend([tuple(range(15,-1,-1)),tuple(range((len(sections)-1)*16,len(sections)*16))])
 mesh('Street leather shoe '+side,verts,faces,leather,lambda v:{'foot_'+side:1})
# Separate fitted opaque foundation; never remove the adult MPFB body.
body=bpy.data.objects['village_farmer_MakeHuman_body']
import sys
sys.path.insert(0,str(ROOT/'tools/characters'))
from whole_body_contract import retain_complete_body
retain_complete_body(body)
foundation_material=bpy.data.materials.new('Street opaque cotton foundation');foundation_material.diffuse_color=(.16,.13,.095,1);foundation_material.use_nodes=True
foundation_material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.16,.13,.095,1)
foundation_material.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.95
arm_groups={group.index for group in body.vertex_groups if group.name.startswith(('hand_', 'thumb_', 'index_', 'middle_', 'ring_', 'pinky_', 'lowerarm_', 'upperarm_', 'clavicle_'))}
selected=[f for f in body.data.polygons if all(.70<(body.matrix_world@body.data.vertices[i].co).z<1.025 and sum(assignment.weight for assignment in body.data.vertices[i].groups if assignment.group in arm_groups)<.15 for i in f.vertices)]
indices=sorted({i for f in selected for i in f.vertices});mapping={old:new for new,old in enumerate(indices)}
data=bpy.data.meshes.new('Separate opaque fitted foundation')
data.from_pydata([body.matrix_world@(body.data.vertices[i].co+body.data.vertices[i].normal*.0045) for i in indices],[],[tuple(mapping[i] for i in f.vertices) for f in selected]);data.materials.append(foundation_material)
foundation=bpy.data.objects.new('Street opaque foundation',data);bpy.context.collection.objects.link(foundation)
for face in data.polygons:face.use_smooth=True
for old,new in mapping.items():
 for assignment in body.data.vertices[old].groups:
  name=body.vertex_groups[assignment.group].name
  group=foundation.vertex_groups.get(name) or foundation.vertex_groups.new(name=name);group.add([new],assignment.weight,'REPLACE')
modifier=foundation.modifiers.new('Same MPFB rig','ARMATURE');modifier.object=rig;foundation.parent=rig
# Retain full provenance and donor rig; export only this candidate, no shared resident replacement.
out=ROOT/f'WorkingAssets/NPCs/street_residents/{role}';out.mkdir(parents=True,exist_ok=True)
runtime=ROOT/'characters/npcs/street_residents';runtime.mkdir(parents=True,exist_ok=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/f'{role}.blend'))
bpy.ops.export_scene.gltf(filepath=str(runtime/f'{role}.glb'),export_format='GLB',export_skins=True,export_animations=False,export_cameras=False,export_lights=False)
(out/'manifest.json').write_text(json.dumps({'source':f'WorkingAssets/NPCs/households/{role}/{role}.blend','changes':'original articulated lower wraps and shaped shoes','status':'complete MPFB body retained with separate opaque foundation; garment contact and period approval separate','complete_body_vertices':len(body.data.vertices),'foundation_vertices':len(data.vertices)},indent=2))
