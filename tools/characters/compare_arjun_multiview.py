"""Contact sheet of unaltered reference/candidate renders, not an acceptance gate."""
from pathlib import Path
import argparse
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/characters/arjun/reference_fit'
parser=argparse.ArgumentParser()
parser.add_argument('--candidate-dir',type=Path)
parser.add_argument('--output',type=Path)
args=parser.parse_args()
reference=Image.open(ROOT/'WorkingAssets/Arjun/references/arjun_core_multiview.png').convert('RGB')
views=[('Front',(10,25,355,1000),'front_residual.png'),('Side',(425,25,675,1000),'side_residual.png'),('Back',(695,25,1075,1000),'back_residual.png'),('Three-quarter',(1080,25,1448,1010),'three_quarter_residual.png')]
canvas=Image.new('RGB',(1280,1500),(225,221,214));draw=ImageDraw.Draw(canvas)
font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',24)
small=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',18)
draw.text((20,12),'Arjun: owner multi-view / separate fit candidate',font=font,fill=(35,35,35))
draw.text((20,48),'REVIEW OPEN — body, face, hair, clothes and equipment are not certified exact.',font=small,fill=(115,35,28))
for index,(label,crop,file) in enumerate(views):
 x=index*320
 draw.text((x+16,84),label,font=font,fill=(35,35,35))
 ref=reference.crop(crop);ref.thumbnail((300,610))
 canvas.paste(ref,(x+(320-ref.width)//2,122))
 draw.text((x+16,738),'Reference',font=small,fill=(35,35,35))
 candidate_path=args.candidate_dir/(file.replace('_residual','')) if args.candidate_dir else OUT/file
 candidate=Image.open(candidate_path).convert('RGB').crop((155,20,550,930));candidate.thumbnail((300,610))
 canvas.paste(candidate,(x+(320-candidate.width)//2,776))
 draw.text((x+16,1392),'Candidate — studio render',font=small,fill=(35,35,35))
draw.text((20,1442),'Reference scale is visual; these are not metric scans or final motion/contact approval.',font=small,fill=(80,70,65))
output=args.output or OUT/'reference_comparison.png'
canvas.save(output)
print(output)
