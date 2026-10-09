"""Read-only GLB structure check. Prints results; retains no test output."""
import json,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
FILES=['households/merchant','households/landowner','british/official_man','british/official_woman','households/staff_farmer','households/staff_woman']
def run():
    errors=[]
    for family in FILES:
        p=ROOT/'characters/npcs'/f'{family}.glb';data=p.read_bytes()
        doc=json.loads(data[20:20+struct.unpack_from('<I',data,12)[0]])
        bodies=[];foundations=[]
        for node in doc['nodes']:
            if 'mesh' not in node:continue
            name=node.get('name','').lower()
            if 'foundation' in name:foundations.append(node)
            elif 'makehuman_body' in name or 'mpfb_body' in name:bodies.append(node)
        if len(bodies)!=1 or not foundations:errors.append(f'{family}: body/foundation count')
        vertices=sum(doc['accessors'][q['attributes']['POSITION']]['count'] for n in bodies for q in doc['meshes'][n['mesh']]['primitives'])
        if vertices<13000:errors.append(f'{family}: unexpectedly small body')
        for node in bodies+foundations:
            if 'skin' not in node:errors.append(f'{family}: unskinned {node.get("name")}')
        for node in foundations:
            for primitive in doc['meshes'][node['mesh']]['primitives']:
                material=doc['materials'][primitive['material']]
                if material.get('alphaMode','OPAQUE')!='OPAQUE':errors.append(f'{family}: transparent foundation')
        print(f'{family}: body export vertices={vertices}, separate foundations={len(foundations)}')
    print('HOUSEHOLD_FOUNDATIONS', 'PASS' if not errors else errors)
    return not errors
if __name__=='__main__':raise SystemExit(0 if run() else 1)
