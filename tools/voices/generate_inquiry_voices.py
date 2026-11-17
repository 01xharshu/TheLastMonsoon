#!/usr/bin/env python3
"""Generate offline inquiry dialogue with reproducible character voices."""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'assets/audio/dialogue'
BRITISH = {'District officer': 'bm_george', 'First official': 'bm_lewis',
           'Second official': 'bm_daniel', 'Guard': 'bm_lewis',
           'British male': 'bm_george', 'British female': 'bf_emma', 'Soldier': 'bm_lewis'}
INDIAN = {'Arjun': 'Raghav', 'Station officer': 'Dinesh', 'Chacha': 'Ravi',
          'Indian male': 'Raghav', 'Indian female': 'Meera', 'Mangal Pandey': 'Kabir', 'Mangal': 'Kabir',
          'Driver': 'Vikas', 'Witness': 'Aakash', 'Village protector': 'Tarun', 'Fighter': 'Dinesh'}


def lines():
    pairs = []
    for name in ('story/dev_inquiry.gd', 'story/dev_story.gd',
                 'world/suryagarh/settlements/chacha_advice.gd'):
        source = (ROOT / name).read_text()
        patterns = [r'\["([^"\n]+)","([^"\n]+)",\s*[\d.]',
                    r'line\("([^"\n]+)","([^"\n]+)",\s*[\d.]',
                    r'"speaker":"([^"\n]+)","text":"([^"\n]+)"']
        for pattern in patterns:
            pairs.extend(re.findall(pattern, source))
    for source_path in (ROOT / 'story').glob('community*.gd'):
        for speaker, text in re.findall(r'"(Mangal|Chacha|Arjun|Witness|Village protector): ([^"\n]+)"', source_path.read_text()):
            if not re.search(r'\b[A-Z][a-z]+: ', text):
                pairs.append((speaker, text))
    pairs.append(('Arjun', 'Still no word from Dev…'))
    pairs.extend([
        ('Witness', 'I am safe here. I will speak about what happened when I am ready.'),
        ('Chacha', 'We will keep watch. Thank you, Arjun.'),
        ('Soldier', 'Hand over the witness or I will drag him out.'),
        ('Arjun', 'This household is under our protection. Leave them alone.'),
    ])
    pairs.extend([
        ('Mangal', 'Bring the sealed ship consignment to camp. Stay hidden at the rear; the others will drive.'),
        ('Fighter', 'The shipment has reached camp.'),
        ('Mangal Pandey', 'We survived, Arjun. There is more work ahead.'),
        ('Fighter', 'A brave escape. The shipment is safe.'),
        ('Mangal Pandey', 'Shabash, Arjun. You kept our people and supplies safe. Take these 200 rupees.'),
    ])
    for source_path in (ROOT / 'world/suryagarh/settlements/story_community.gd',
                        ROOT / 'world/suryagarh/settlements/urban_west.gd'):
        for text in re.findall(r'"(?:Reader|Patron|Student|Printer): ([^"\n]+)"', source_path.read_text()):
            pairs.extend((speaker, text) for speaker in ('Indian male', 'Indian female'))
    rebellion = (ROOT / 'story/rebellion_story.gd').read_text()
    pairs.extend(('Mangal Pandey', text) for text in re.findall(r'"Mangal Pandey: ([^"\n]+)"', rebellion))
    pairs.extend(('Driver', f'We’re in {place}. Mind your step!')
                 for place in ('Bhairavpur', 'Police Station'))
    pairs.extend((speaker, text)
                 for speaker in ('British male', 'British female', 'Indian male', 'Indian female')
                 for text in ('Good morning.', 'How is your family?'))
    return list(dict.fromkeys((speaker, text) for speaker, text in pairs
                              if speaker in BRITISH or speaker in INDIAN))


def destination(speaker, text):
    key = hashlib.sha256((speaker + '\n' + text).encode()).hexdigest()
    return OUTPUT / f'{key}.wav'


def write_voice(target, audio, sample_rate):
    import numpy as np
    import soundfile as sf
    audio = np.asarray(audio, dtype=np.float32)
    if audio.size == 0 or not np.isfinite(audio).all():
        raise RuntimeError(f'Invalid generated speech for {target}')
    rms = float(np.sqrt(np.mean(audio * audio)))
    peak = float(np.max(np.abs(audio)))
    if rms < 0.0001 or peak < 0.0001:
        raise RuntimeError(f'Silent generated speech for {target}')
    gain = min(0.06 / rms, 0.89 / peak)
    sf.write(target, audio * gain, sample_rate)


def british(pairs):
    from kokoro import KPipeline
    pipeline = KPipeline(lang_code='b', repo_id='hexgrad/Kokoro-82M')
    for speaker, text in pairs:
        target = destination(speaker, text)
        if speaker not in BRITISH or target.exists():
            continue
        chunks = [result.audio.numpy() for result in pipeline(text, voice=BRITISH[speaker])]
        if not chunks:
            raise RuntimeError(f'No audio generated for {speaker}: {text}')
        import numpy as np
        write_voice(target, np.concatenate(chunks), 24000)
        print(speaker, target.name, flush=True)


def indian(pairs, model_id, device, limit):
    import torch
    from parler_tts import ParlerTTSForConditionalGeneration
    from transformers import AutoTokenizer
    device = device or ('mps' if torch.backends.mps.is_available() else 'cpu')
    if device == 'cpu':
        torch.set_num_threads(2)
    dtype = torch.float16 if device == 'cpu' else torch.float32
    model = ParlerTTSForConditionalGeneration.from_pretrained(model_id, torch_dtype=dtype).to(device)
    prompt_tokenizer = AutoTokenizer.from_pretrained(model_id)
    description_tokenizer = AutoTokenizer.from_pretrained(model.config.text_encoder._name_or_path)
    model.eval()
    generated = 0
    for speaker, text in pairs:
        target = destination(speaker, text)
        if speaker not in INDIAN or target.exists():
            continue
        description = f"{INDIAN[speaker]} speaks English with an Indian accent, in a natural expressive voice. The recording is very clear, with no background noise."
        description_ids = description_tokenizer(description, return_tensors='pt').to(device)
        prompt_ids = prompt_tokenizer(text, return_tensors='pt').to(device)
        torch.manual_seed(2026)
        with torch.inference_mode():
            audio = model.generate(input_ids=description_ids.input_ids,
                                   attention_mask=description_ids.attention_mask,
                                   prompt_input_ids=prompt_ids.input_ids,
                                   prompt_attention_mask=prompt_ids.attention_mask)
        write_voice(target, audio.cpu().numpy().squeeze(), model.config.sampling_rate)
        print(speaker, target.name, flush=True)
        generated += 1
        if limit and generated >= limit:
            break


def write_opening_envelope():
    import numpy as np
    import soundfile as sf
    audio, rate = sf.read(destination('Arjun', 'Still no word from Dev…'))
    step = int(rate * 0.02)
    amplitudes = [float(np.sqrt(np.mean(audio[index:index + step] ** 2)))
                  for index in range(0, len(audio), step)]
    peak = max(amplitudes)
    amplitudes = [round(min(1.0, value / max(peak * 0.7, 0.001)), 5)
                  for value in amplitudes]
    amplitudes.append(0.0)
    (OUTPUT / 'opening_arjun_envelope.json').write_text(json.dumps({
        'step_seconds': 0.02,
        'duration_seconds': len(audio) / rate,
        'amplitudes': amplitudes,
    }))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('group', choices=('british', 'indian'))
    parser.add_argument('--indian-model', default='naklitechie/indic-parler-tts')
    parser.add_argument('--device', choices=('cpu', 'mps'))
    parser.add_argument('--limit', type=int, default=0)
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    if args.group == 'british':
        british(lines())
    else:
        indian(lines(), args.indian_model, args.device, args.limit)
        write_opening_envelope()


if __name__ == '__main__':
    main()
