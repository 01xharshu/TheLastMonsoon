"""Keep existing MPFB anatomy and an opaque foundation beneath Arjun clothing."""
import hashlib
import bpy

def ensure_full_body():
 body=bpy.data.objects['Arjun_MakeHuman_Body']
 before=hashlib.sha256(b''.join(bytes(str(tuple(v.co)),'utf-8') for v in body.data.vertices)).hexdigest()
 disabled=[]
 for mod in body.modifiers:
  if mod.type=='MASK' and mod.name!='Hide helpers':
   mod.show_viewport=False;mod.show_render=False;disabled.append(mod.name)
 body.hide_render=False;body.hide_set(False)
 foundation=bpy.data.objects.get('Arjun_Foundation_FittedShorts')
 if foundation is None:raise RuntimeError('Arjun opaque foundation is missing')
 foundation.hide_render=False;foundation.hide_set(False)
 for material in foundation.data.materials:
  if not material:continue
  material.diffuse_color=(*material.diffuse_color[:3],1)
  if material.use_nodes:
   for node in material.node_tree.nodes:
    if node.type=='BSDF_PRINCIPLED':
     socket=node.inputs['Alpha']
     for link in list(socket.links):material.node_tree.links.remove(link)
     socket.default_value=1
 after=hashlib.sha256(b''.join(bytes(str(tuple(v.co)),'utf-8') for v in body.data.vertices)).hexdigest()
 assert before==after,'Complete-body enforcement must not alter physique/topology'
 return {'disabled_clothing_masks':disabled,'body_vertices':len(body.data.vertices),'body_coordinate_sha256':after,'foundation':foundation.name,'foundation_visible':not foundation.hide_render,'helpers_only_mask':'Hide helpers'}
