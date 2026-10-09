"""Compare isolated seated clerk body against live complete body; stdout only."""
import hashlib,json,struct,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def inspect(path):
 raw=path.read_bytes();length=struct.unpack_from('<I',raw,12)[0]
 doc=json.loads(raw[20:20+length]);binary=raw[28+length:]
 node=next(n for n in doc['nodes'] if n.get('name')=='record_clerk_export_full_body')
 count=0;digest=hashlib.sha256()
 for primitive in doc['meshes'][node['mesh']]['primitives']:
  accessor=doc['accessors'][primitive['attributes']['POSITION']];view=doc['bufferViews'][accessor['bufferView']]
  offset=view.get('byteOffset',0)+accessor.get('byteOffset',0);count+=accessor['count']
  digest.update(binary[offset:offset+accessor['count']*12])
 foundation=next(n for n in doc['nodes'] if n.get('name')=='Opaque fitted underwear foundation')
 assert 'skin' in node and 'skin' in foundation
 assert all(doc['materials'][p['material']].get('alphaMode','OPAQUE')=='OPAQUE' for p in doc['meshes'][foundation['mesh']]['primitives'])
 return count,digest.hexdigest()
live=inspect(ROOT/'characters/npcs/motion/record_clerk/record_clerk_rigged_candidate.glb')
study=inspect(Path(sys.argv[sys.argv.index('--candidate')+1]) if '--candidate' in sys.argv else ROOT/'characters/npcs/review/record_clerk_seat.glb')
assert live==study,(live,study)
print('CLERK_SEAT_BODY PASS: same complete body positions,',study[0],'vertices; separate opaque skinned foundation retained')
