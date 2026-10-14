"""Disposable non-human geometric fixtures for bounded foundation repair."""
import sys,bpy
from pathlib import Path
from types import SimpleNamespace
from mathutils import Matrix,Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from purpose_cloth_volume import VolumeSurface
from river_foundation_contact import fit_foundation_contacts

# This closed cube is a mathematical exclusion volume, not a human asset.
points=[Vector((x,y,z)) for z in [-.4,-.2] for y in [-1,1] for x in [-1,1]]
faces=[(0,2,3),(0,3,1),(4,5,7),(4,7,6),(0,1,5),(0,5,4),
       (2,6,7),(2,7,3),(0,4,6),(0,6,2),(1,3,7),(1,7,5)]
body=VolumeSurface.FromPolygons(points,faces,all_triangles=True)
foundation=[Vector((0,0,0)),Vector((1,0,0)),Vector((0,1,0))]
rig=SimpleNamespace(matrix_world=Matrix.Identity(4))
def fixture(vertices,expected_error=None):
    mesh=bpy.data.meshes.new('Temporary cloth triangle')
    mesh.from_pydata(vertices,[],[(0,1,2)]);mesh.update()
    obj=bpy.data.objects.new('Temporary cloth triangle',mesh);bpy.context.collection.objects.link(obj)
    try:
        obj.shape_key_add(name='Basis');key=obj.shape_key_add(name='Fixture');key.value=1
        try:shift=fit_foundation_contacts(rig,obj,body,key,foundation,[(0,1,2)])
        except RuntimeError as error:
            if expected_error and expected_error in str(error):return
            raise
        if expected_error:raise RuntimeError('Expected rejection: '+expected_error)
        if not .025<shift<.027 or any(vertex.co.z<.0059 for vertex in key.data):
            raise RuntimeError('Incorrect geometric clearance')
    finally:
        bpy.data.objects.remove(obj,do_unlink=True);bpy.data.meshes.remove(mesh)
fixture([(.2,.2,-.02),(.4,.2,.02),(.2,.4,.02)])
fixture([(.2,.2,-.10),(.4,.2,.02),(.2,.4,.02)],'bounded finite')
fixture([(.2,.2,-.3),(.4,.2,-.3),(.2,.4,-.3)],'penetrates body')
print('RIVER_FOUNDATION_REPAIR PASS fixtures=3',flush=True)
