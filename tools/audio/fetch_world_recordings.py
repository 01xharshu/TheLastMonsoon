"""Fetch verified licensed source recordings; retain originals and metadata."""
from pathlib import Path
import urllib.request,json,hashlib,subprocess,concurrent.futures,wave,struct
root=Path(__file__).resolve().parents[2];source=root/'WorkingAssets/Audio/world_sources';output=root/'audio/ambience'
clips=[
 dict(key='fire',download='https://opengameart.org/sites/default/files/fire-1.wav',page='https://opengameart.org/content/fire-crackling',author='AntumDeluge',license='CC0-1.0',license_url='https://creativecommons.org/publicdomain/zero/1.0/',context='Fireplace crackling'),
 dict(key='cow',download='https://upload.wikimedia.org/wikipedia/commons/4/48/Mudchute_cow_1.ogg',page='https://commons.wikimedia.org/wiki/File:Mudchute_cow_1.ogg',author='Secretlondon',license='CC-BY-SA-3.0',license_url='https://creativecommons.org/licenses/by-sa/3.0/',context='Irish Moiled cow in London; generic cattle vocalization candidate, not breed-specific zebu approval'),
 dict(key='river',download='https://upload.wikimedia.org/wikipedia/commons/3/32/Rivernoise.ogg',page='https://commons.wikimedia.org/wiki/File:Rivernoise.ogg',author='Secretlondon',license='CC-BY-SA-3.0',license_url='https://creativecommons.org/licenses/by-sa/3.0/',context='River Esk, Scotland; water texture candidate, not a recording of the game location'),
 dict(key='sparrow',download='https://upload.wikimedia.org/wikipedia/commons/0/01/House_Sparrow.ogg',page='https://commons.wikimedia.org/wiki/File:House_Sparrow.ogg',author='Gypsypkd',license='Public-domain dedication',license_url='https://commons.wikimedia.org/wiki/File:House_Sparrow.ogg#Licensing',context='House sparrow recorded in India')]
def fetch(clip):
 path=source/(clip['key']+Path(clip['download']).suffix)
 if not path.exists():
  req=urllib.request.Request(clip['download'],headers={'User-Agent':'TheLastMonsoonAssetPreparation/1.0'})
  path.write_bytes(urllib.request.urlopen(req,timeout=30).read())
 clip['sha256']=hashlib.sha256(path.read_bytes()).hexdigest();clip['source_file']=str(path.relative_to(root))
 target=output/(clip['key']+'.wav')
 filters='highpass=f=45,lowpass=f=10000,afade=t=in:d=0.04'
 args=['/opt/homebrew/bin/ffmpeg','-y','-i',str(path),'-ac','1','-ar','22050','-af',filters]
 if clip['key']=='sparrow':args+=['-t','5']
 args += [str(target)]
 subprocess.run(args,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 if clip['key'] in ['fire','river']:
  with wave.open(str(target),'rb') as f:
   parameters=f.getparams();samples=list(struct.unpack('<'+'h'*f.getnframes(),f.readframes(f.getnframes())))
  overlap=min(2205,len(samples)//8)
  blend=[round(samples[-overlap+i]*(1-i/(overlap-1))+samples[i]*i/(overlap-1)) for i in range(overlap)]
  samples=samples[overlap:-overlap]+blend
  with wave.open(str(target),'wb') as f:f.setparams(parameters);f.writeframes(struct.pack('<'+'h'*len(samples),*samples))
 clip['runtime_file']=str(target.relative_to(root));clip['changes']='Mono 22050 Hz PCM, high/low pass, 40 ms fade-in; loop recordings overlap-crossfaded by 100 ms; sparrow excerpt first 5 seconds'
 return clip
source.mkdir(parents=True,exist_ok=True);output.mkdir(parents=True,exist_ok=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:results=list(pool.map(fetch,clips))
(source/'manifest.json').write_text(json.dumps(results,indent=2)+'\n')
print('Retained and converted',len(results),'licensed recordings')
