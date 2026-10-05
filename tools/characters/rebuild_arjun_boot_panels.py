"""Rebuild continuous vamp panels and smooth last/sole; separate visual candidate."""
import bpy,bmesh,math,json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2];SOURCE=ROOT/'WorkingAssets/Arjun/reference_fit/arjun_boot_contact_candidate.blend'
OUT=ROOT/'docs/characters/arjun/reference_fit/boot_panels_2026-10-02';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE));bpy.context.preferences.filepaths.save_version=0
rig=bpy.data.objects['Arjun_Rig'];leather=bpy.data.materials['Worn dark-brown leather'];soles=bpy.data.materials['Dark boot soles']
rows=[(.015,.071,.153,-.073),(.025,.073,.156,-.073),(.04,.071,.150,-.071),(.066,.069,.143,-.070),(.092,.063,.121,-.052),(.118,.056,.086,-.025),(.145,.053,.059,-.006),(.18,.056,.060,-.006),(.23,.061,.062,-.006),(.285,.065,.065,-.006),(.30,.065,.065,-.006)]
def weights(o):
 for v in o.data.vertices:
  side='l' if v.co.x>0 else 'r';t=max(0,min(1,(v.co.z-.145)/.13))
  for group in o.vertex_groups:group.remove([v.index])
  for name,w in [('foot_'+side,1-t),('calf_'+side,t)]:
   g=o.vertex_groups.get(name) or o.vertex_groups.new(name=name);g.add([v.index],w,'REPLACE')
for sign in [-1,1]:
 boot=bpy.data.objects['Arjun_Boot_'+str(sign)];assert len(boot.data.vertices)==704
 for j,(z,rx,ry,cy) in enumerate(rows):
  for i in range(64):
   a=math.tau*i/64;boot.data.vertices[j*64+i].co=(sign*.195+rx*math.cos(a),cy+ry*math.sin(a),z)
 weights(boot)
 sole=bpy.data.objects['Boot outsole '+str(sign)];assert len(sole.data.vertices)==192
 for j,(z,rx,ry) in enumerate([(.004,.073,.155),(.012,.076,.157),(.025,.075,.156)]):
  for i in range(64):
   a=math.tau*i/64;sole.data.vertices[j*64+i].co=(sign*.195+rx*math.cos(a),-.074+ry*math.sin(a),z)
 weights(sole)
 # Sole is rigid footwear, not corrugated fabric.
 for m in sole.modifiers:
  if m.type=='SUBSURF':m.show_render=False;m.show_viewport=False
for o in bpy.data.objects:
 if o.name.startswith('Flat vamp strap'):o.hide_render=True
# Remove the original merged boot buckles, retaining brass above boot level.
old=bpy.data.objects.get('Arjun_Detail_Aged brass hardware')
if old:
 bm=bmesh.new();bm.from_mesh(old.data);bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.calc_center_median().z<.32],context='FACES');bm.to_mesh(old.data);bm.free()
disabled=[]
for sign in [-1,1]:
 for m in bpy.data.objects['Arjun_Boot_'+str(sign)].modifiers:
  if m.type=='ARMATURE':disabled.append((m,m.show_viewport));m.show_viewport=False
bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();trees={}
for sign in [-1,1]:
 o=bpy.data.objects['Arjun_Boot_'+str(sign)].evaluated_get(deps);m=o.to_mesh();trees[sign]=BVHTree.FromPolygons([v.co for v in m.vertices],[tuple(p.vertices) for p in m.polygons]);o.to_mesh_clear()
for m,state in disabled:m.show_viewport=state
bpy.context.view_layer.update()
misses=0;panels=[]
for sign in [-1,1]:
 cx=sign*.195;tree=trees[sign]
 for index,centre_y in enumerate([-.112,-.171]):
  verts=[];faces=[]
  for row in range(9):
   y=centre_y+(row/8-.5)*.016
   hits=[]
   for i in range(161):
    x=cx-.08+i*.001;hit,n,idx,d=tree.ray_cast(Vector((x,y,.4)),Vector((0,0,-1)))
    if hit is not None:hits.append((x,hit))
   assert len(hits)>50,'Vamp projection footprint unexpectedly missing'
   left=hits[0][0]+.001;right=hits[-1][0]-.001
   for col in range(65):
    x=left+(right-left)*col/64;hit,n,idx,d=tree.ray_cast(Vector((x,y,.4)),Vector((0,0,-1)))
    if hit is None:misses+=1;raise RuntimeError('Hole in continuous vamp projection')
    if n.z<0:n=-n
    verts.append(tuple(hit+n*.003))
  for row in range(8):
   for col in range(64):
    a=row*65+col;faces.append((a,a+1,a+66,a+65))
  mesh=bpy.data.meshes.new('Continuous vamp panel');mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new('Arjun_ContinuousVamp_'+str(sign)+'_'+str(index),mesh);bpy.context.scene.collection.objects.link(o);mesh.materials.append(leather)
  for p in mesh.polygons:p.use_smooth=True
  solid=o.modifiers.new('Leather thickness','SOLIDIFY');solid.thickness=.0012;solid.offset=0
  weights(o);o.parent=rig;arm=o.modifiers.new('Boot matching deformation','ARMATURE');arm.object=rig;panels.append(o.name)
# Replace two-edge ribbons with continuous rows across the leather width.
for o in bpy.data.objects:
 if o.name.startswith('Flat boot wrap '):o.hide_render=True
for sign in [-1,1]:
 cx=sign*.195;tree=trees[sign]
 for layer,height in enumerate([.148,.211,.269]):
  for crossing in [-1,1]:
   verts=[];faces=[]
   for row in range(9):
    for col in range(192):
     a=math.tau*col/192;z=height+crossing*.018*math.sin(a)+(row/8-.5)*.014
     out=Vector((math.cos(a),math.sin(a),0));hit,n,idx,d=tree.ray_cast(Vector((cx,-.006,z))+out*.3,-out)
     if hit is None:raise RuntimeError('Missing shaft panel surface')
     if n.dot(out)<0:n=-n
     verts.append(tuple(hit+n*(.0025+(.0015 if crossing>0 else 0))))
   for row in range(8):
    for col in range(192):
     n=(col+1)%192;a=row*192+col;faces.append((a,row*192+n,(row+1)*192+n,a+192))
   data=bpy.data.meshes.new('Continuous shaft wrap');data.from_pydata(verts,[],faces);data.update();o=bpy.data.objects.new('Arjun_ContinuousShaft_'+str(sign)+'_'+str(layer)+'_'+str(crossing),data);bpy.context.scene.collection.objects.link(o);data.materials.append(leather)
   for f in data.polygons:f.use_smooth=True
   solid=o.modifiers.new('Flat leather thickness','SOLIDIFY');solid.thickness=.0012;solid.offset=0;weights(o);o.parent=rig;arm=o.modifiers.new('Boot skin blend','ARMATURE');arm.object=rig
 # Existing four-piece buckle frames: relocate to the matching shaft level/surface.
 for o in bpy.data.objects:
  if not o.name.startswith('Reference boot buckle '+('l' if sign>0 else 'r')):continue
  mid=sum(v.co.z for v in o.data.vertices)/len(o.data.vertices)
  old_height=min([.146,.220,.278],key=lambda z:abs(z-mid));new_height={.146:.148,.220:.211,.278:.269}[old_height]
  hit,n,idx,d=tree.ray_cast(Vector((cx+sign*.3,-.026,new_height)),Vector((-sign,0,0)))
  assert hit is not None
  for v in o.data.vertices:
   v.co.z+=new_height-old_height;v.co.x=hit.x+sign*.006+(v.co.x-(cx+sign*.069))
  weights(o)
# Subdued stitched edges and varied leather finish, kept on the same rig.
thread=bpy.data.materials.new('Worn brown boot stitching');thread.use_nodes=True
bs=thread.node_tree.nodes['Principled BSDF'];bs.inputs['Base Color'].default_value=(.09,.055,.028,1);bs.inputs['Roughness'].default_value=.86
curve=bpy.data.curves.new('Boot edge stitches','CURVE');curve.dimensions='3D';curve.bevel_depth=.00022;curve.bevel_resolution=1
stitch_count=0
for obj in list(bpy.data.objects):
 if not(obj.name.startswith('Arjun_ContinuousShaft_') or obj.name.startswith('Arjun_ContinuousVamp_')):continue
 columns=192 if 'Shaft' in obj.name else 65
 for row in [0,8]:
  for col in range(3,columns-3,5):
   p=obj.data.vertices[row*columns+col].co.copy()
   tangent=(obj.data.vertices[row*columns+col+1].co-obj.data.vertices[row*columns+col-1].co).normalized()
   normal=obj.data.vertices[row*columns+col].normal.copy()
   if 'Shaft' in obj.name:
    outward=Vector((p.x-(.195 if p.x>0 else -.195),p.y+.006,0))
    if normal.dot(outward)<0:normal=-normal
   elif normal.z<0:normal=-normal
   p+=normal*.0008
   spline=curve.splines.new('POLY');spline.points.add(1)
   for point,sign in zip(spline.points,[-1,1]):point.co=(*(p+tangent*sign*.0012),1)
   stitch_count+=1
obj=bpy.data.objects.new('Arjun_BootEdgeStitches',curve);bpy.context.scene.collection.objects.link(obj);curve.materials.append(thread)
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj;bpy.ops.object.convert(target='MESH');obj=bpy.context.object;weights(obj);obj.parent=rig;arm=obj.modifiers.new('Boot matching stitch skin','ARMATURE');arm.object=rig
nt=leather.node_tree;bs=nt.nodes['Principled BSDF'];coord=nt.nodes.new('ShaderNodeTexCoord');noise=nt.nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=175;noise.inputs['Detail'].default_value=3;nt.links.new(coord.outputs['Object'],noise.inputs['Vector']);ramp=nt.nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.18;ramp.color_ramp.elements[0].color=(.026,.013,.007,1);ramp.color_ramp.elements[1].position=.82;ramp.color_ramp.elements[1].color=(.058,.031,.016,1);nt.links.new(noise.outputs['Fac'],ramp.inputs[0]);nt.links.new(ramp.outputs[0],bs.inputs['Base Color'])
rough=nt.nodes.new('ShaderNodeMapRange');rough.inputs['To Min'].default_value=.60;rough.inputs['To Max'].default_value=.84;nt.links.new(noise.outputs['Fac'],rough.inputs['Value']);nt.links.new(rough.outputs[0],bs.inputs['Roughness']);bs.inputs['Specular IOR Level'].default_value=.22
scene=bpy.context.scene;c=scene.camera;scene.cycles.samples=20;scene.render.resolution_x=700;scene.render.resolution_y=700;c.data.ortho_scale=.36
c.location=(.195,-2,.18);c.rotation_euler=(Vector((.195,-.07,.16))-c.location).to_track_quat('-Z','Y').to_euler()
candidate=ROOT/'WorkingAssets/Arjun/reference_fit/arjun_boot_panels_candidate.blend';bpy.ops.wm.save_as_mainfile(filepath=str(candidate))
for name,pos in [('boot_front',(.195,-2,.18)),('boot_side',(2,-.07,.18)),('boot_quarter',(1,-2,.18))]:
 c.location=pos;c.rotation_euler=(Vector((.195,-.07,.16))-c.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
scene.render.resolution_x=700;scene.render.resolution_y=950;c.data.ortho_scale=1.92
for name,pos in [('front',(0,-4,.88)),('side',(4,0,.88)),('back',(0,4,.88)),('three_quarter',(3,-4,.88))]:
 c.location=pos;c.rotation_euler=(Vector((0,0,.88))-c.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
(OUT/'manifest.json').write_text(json.dumps({'status':'VISUAL_REVIEW_OPEN','source':str(SOURCE.relative_to(ROOT)),'candidate':str(candidate.relative_to(ROOT)),'panels':panels,'projection_misses':misses,'edge_stitches':stitch_count,'runtime_replaced':False,'exact_match':False},indent=2)+'\n')
