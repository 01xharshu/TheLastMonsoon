"""Extract active CC0 TinyWorlds/PDSounds footsteps from the retained source ZIP."""
from pathlib import Path
import zipfile,subprocess,json,hashlib
root=Path(__file__).resolve().parents[2];source=root/'WorkingAssets/Audio/world_sources/footsteps.zip';output=root/'audio/ambience';items=[]
with zipfile.ZipFile(source) as z:
 for file in ['wood01.ogg','wood02.ogg','wood03.ogg','stone01.ogg','mud02.ogg','gravel.ogg']:
  target=output/('step_'+Path(file).stem+'.wav')
  subprocess.run(['/opt/homebrew/bin/ffmpeg','-y','-i','pipe:0','-ac','1','-ar','22050','-af','highpass=f=45,afade=t=in:d=0.003',str(target)],input=z.read(file),check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
  items.append({'archive_member':file,'runtime_file':str(target.relative_to(root))})
manifest={'source':'https://opengameart.org/content/different-steps-on-wood-stone-leaves-gravel-and-mud','download':'https://opengameart.org/sites/default/files/%5Bkdd%5DDifferentSteps_0.zip','author':'TinyWorlds, edited from PDSounds recordings','license':'CC0-1.0','license_url':'https://creativecommons.org/publicdomain/zero/1.0/','sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'changes':'Active subset converted to mono 22050 Hz PCM, high-pass and 3 ms fade-in','files':items}
(source.parent/'footsteps_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print('6 natural footstep variants prepared')
