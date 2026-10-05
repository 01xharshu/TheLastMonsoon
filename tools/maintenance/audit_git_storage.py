"""Account for checkout/Git size; remove only duplicate closed Git temp objects.
No history rewriting, pruning or cache clearing. Default audit; --apply-temp cleans.
"""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys,time,zlib
ROOT=Path(__file__).resolve().parents[2]
GIT=ROOT/'.git'
REPORT=ROOT/'docs/assets/git_storage_maintenance.json'
def git(*args): return subprocess.check_output(['git',*args],cwd=ROOT,stderr=subprocess.DEVNULL)
def bytes_under(path): return sum(p.stat().st_size for p in path.rglob('*') if p.is_file() and not p.is_symlink())
def writers():
    lines=subprocess.check_output(['ps','-axo','pid,comm,args'],text=True).splitlines()
    commands={'add','commit','gc','repack','pack-objects','index-pack','prune','fetch','pull','push','merge','reset','checkout','restore','update-index','update-ref','maintenance','hash-object'}
    found=[]
    for line in lines:
        parts=line.strip().split(maxsplit=2)
        if len(parts)!=3 or not Path(parts[1]).name.startswith('git'): continue
        if any(word in commands for word in parts[2].split()): found.append({'pid':int(parts[0]),'command':parts[2]})
    return found
before={name:bytes_under(ROOT/name) for name in ['.git','.godot','docs','WorkingAssets','assets']}
before['checkout_total']=bytes_under(ROOT)
objects=git('count-objects','-v').decode()
removed=[];retained=[];candidates=[]
for path in sorted((GIT/'objects').glob('??/tmp_obj_*')):
    entry={'path':str(path.relative_to(ROOT)),'bytes':path.stat().st_size}
    try:
        raw=path.read_bytes(); unpacked=zlib.decompress(raw)
        kind_size,body=unpacked.split(b'\0',1)
        kind,length=kind_size.split(b' ',1)
        if len(body)!=int(length) or kind not in [b'blob',b'tree',b'commit',b'tag']: raise ValueError('Invalid object header')
        oid=hashlib.sha1(unpacked).hexdigest()
        if subprocess.run(['git','cat-file','-e',oid],cwd=ROOT,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode:
            entry['reason']='No retained identical object in Git database; kept'; retained.append(entry);continue
        # Resolve and read retained content, not merely an object-name match.
        if git('cat-file',kind.decode(),oid)!=body: raise ValueError('Retained object differs')
        entry.update({'object_id':oid,'compressed_sha256':hashlib.sha256(raw).hexdigest(),'retained_replacement':'Git object '+oid,'reason':'Valid temporary object duplicates retained Git object content'})
        candidates.append(entry)
    except Exception as error:
        entry['reason']='Not established redundant: '+str(error);retained.append(entry)
apply='--apply-temp' in sys.argv
for entry in candidates:
    path=ROOT/entry['path']
    active=writers();locks=list(GIT.rglob('*.lock'))
    # A writer can start after the first audit: recheck for each removal.
    if active or locks:
        entry['reason']='Active Git writer or lock; kept'; retained.append(entry);continue
    opened=subprocess.run(['/usr/sbin/lsof','-Fn','--',str(path)],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True)
    if opened.stdout.strip():
        entry['reason']='File is open; kept';retained.append(entry);continue
    if hashlib.sha256(path.read_bytes()).hexdigest()!=entry['compressed_sha256']:
        entry['reason']='File changed during audit; kept';retained.append(entry);continue
    if apply: path.unlink();removed.append(entry)
    else: retained.append({**entry,'reason':'Redundant closed temp object; audit only'})
after={name:bytes_under(ROOT/name) for name in ['.git','.godot','docs','WorkingAssets','assets']}
report={'status':'APPLIED_TEMP_DUPLICATES' if apply else 'AUDIT','before_bytes':before,'after_bytes':after,'count_objects_before':objects,'removed':removed,'retained':retained,'reclaimed_bytes':sum(x['bytes'] for x in removed),'policy':'Only byte-proven redundant closed Git temporary objects; no history rewrite, prune or import cache deletion'}
REPORT.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'status':report['status'],'before_bytes':before,'after_bytes':after,'removed_count':len(removed),'retained_temp_count':len(retained),'reclaimed_bytes':report['reclaimed_bytes']},indent=2))
