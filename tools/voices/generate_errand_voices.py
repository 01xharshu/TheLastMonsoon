#!/usr/bin/env python3
"""Generate Indic Parler errand calls and early Chacha training dialogue."""
import argparse
import hashlib
import os
import signal
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'assets/audio/dialogue'
LINES = (
    ('errand_medicine', 'Meera', 'Please help! My neighbour needs medicine.'),
    ('errand_money', 'Ravi', 'Can someone take money to my family at the port?'),
    ('errand_food', 'Dinesh', 'Please, traveller! Could you spare some food?'),
 )

# These early-game lessons are selected dynamically, so the main inquiry
# extractor cannot discover the speaker/text pairs. DevStory already loads
# the exact SHA-256 key and waits for the clip before advancing.
LESSONS = (
    "Hold the talwar ready, with room around you. Never swing at a friend without warning.",
    "Let the blade reach your consenting partner. Keep your feet under you.",
    "Jump, slash, then land balanced. I will show you; then you try.",
    "Carry the spear upright. Keep its point away from your companions.",
    "Thrust forward and recover the point. Your partner is ready.",
    "Jump and thrust, then recover your stance.",
    "Use the small blade at close range. Here we practise without injury.",
    "Approach quietly from behind. Q holds and knocks down a consenting partner. Practise on all three.",
)


# Two complete exchanges. Four stable resident voices add individual
# variety; Arjun retains the approved Raghav voice.
EXCHANGES = (
    ("Good day, traveller. Are you keeping well?", "I am well, thank you. How is your family?", "They are well. Safe travels."),
    ("The day is busy. Are you keeping well?", "Well enough, thank you for asking.", "Good. Take care on the road."),
)
COLLISIONS = (
    "Please, watch where you are going!",
    "Careful there, you nearly knocked me over!",
)
REPLIES = ("I am sorry. Are you all right?", "Mind your own way, then.")
ASSAULTS = ("Why did you strike me?", "Leave me alone!")
POLICE_ASSAULTS = ("Do not strike an officer!", "Stop! You will answer for that!")
ASSAULT_REPLIES = ("I am sorry. I should not have done that.", "Stay out of my way.")


def context_pairs():
    pairs = []
    for index, (hello, reply, farewell) in enumerate(EXCHANGES):
        for gender, speaker in (('male', 'Ravi'), ('male_alt', 'Aakash'), ('female', 'Meera'), ('female_alt', 'Sneha')):
            pairs.append((f'context_{gender}_hello_{index}', speaker, hello))
            pairs.append((f'context_{gender}_farewell_{index}', speaker, farewell))
            pairs.append((f'context_{gender}_collision_{index}', speaker, COLLISIONS[index]))
            pairs.append((f'context_{gender}_assault_{index}', speaker, ASSAULTS[index]))
        pairs.append((f'context_police_collision_{index}', 'Dinesh', ("Watch where you are going.", "Be careful there. Keep your distance.")[index]))
        pairs.append((f'context_police_assault_{index}', 'Dinesh', POLICE_ASSAULTS[index]))
        pairs.append((f'context_arjun_assault_{index}', 'Raghav', ASSAULT_REPLIES[index]))
        pairs.append((f'context_arjun_reply_{index}', 'Raghav', reply))
        pairs.append((f'context_arjun_collision_{index}', 'Raghav', REPLIES[index]))
    for index, (hello, reply) in enumerate((
        ("Welcome. What would you like to see?", "Let me see what you have."),
        ("Good day. Are you looking for anything?", "Show me what is available, please."),
    )):
        pairs.append((f'context_shop_hello_{index}', 'Vikas', hello))
        pairs.append((f'context_arjun_shop_{index}', 'Raghav', reply))
    peer_exchanges = (
        ("How is your family these days?", "They are well, thank you. And yours?"),
        ("Have you heard any news from the market?", "Only that the traders arrived early today."),
    )
    for index, (question, answer) in enumerate(peer_exchanges):
        for profile, speaker in (('male', 'Ravi'), ('male_alt', 'Aakash'), ('female', 'Meera'), ('female_alt', 'Sneha')):
            pairs.append((f'context_peer_{profile}_{index}_question', speaker, question))
            pairs.append((f'context_peer_{profile}_{index}_answer', speaker, answer))
    # Put passing responses first so nearby walkers gain speech as a usable batch.
    passing = []
    for index, line in enumerate(("Good day. I must be going.", "Excuse me, I have work to do.")):
        for profile, speaker in (("male", "Ravi"), ("male_alt", "Aakash"), ("female", "Meera"), ("female_alt", "Sneha")):
            passing.append((f"context_pass_{profile}_{index}", speaker, line))
    worker = []
    for index, line in enumerate(("Good day. How are you?", "Hello. I must get back to my work.")):
        for profile, speaker in (("male", "Ravi"), ("male_alt", "Aakash"), ("female", "Meera"), ("female_alt", "Sneha")):
            worker.append((f"context_worker_{profile}_{index}", speaker, line))
    flirt = [
        ("context_flirt_female_0", "Meera", "Well, Arjun, you do know how to make an entrance."),
        ("context_flirt_female_alt_0", "Sneha", "You have a charming smile, Arjun."),
        ("context_arjun_flirt_0", "Raghav", "You are making me blush."),
    ]
    # Separate auditions: never replace approved or in-game character recordings.
    studio = []
    for profile, speaker in (("mary", "Mary"), ("gauri", "Gauri"), ("kavya", "Kavya")):
        for index, line in enumerate((
            "Well, Arjun, I was beginning to think you had forgotten me. Come, tell me how your day has been.",
            "You always know how to make me smile. Perhaps you will stay and talk a little longer?",
        )):
            studio.append((f"audition_female_{profile}_{index}", speaker, line))
    # Mary's full interaction set is staged separately until every line is ready.
    mary = [("context_mary_" + name[len("context_"):], "Mary", line)
            for name, speaker, line in flirt + passing + worker + pairs
            if speaker == "Meera"]
    mary_flirt = [
        ("context_mary_flirt_1", "Mary", "You always make me smile, Arjun. Will you stay and talk a little longer?"),
        ("context_mary_flirt_2", "Mary", "There you are. I was beginning to think you had forgotten me."),
        ("context_mary_flirt_3", "Mary", "You are looking rather handsome today. Has someone caught your eye?"),
        ("context_mary_flirt_4", "Mary", "Come back when you have a moment. I would like to hear more of your stories."),
    ]
    arjun_flirt = [(f"context_arjun_mary_flirt_{index}", "Raghav", text)
                   for index, text in enumerate((
                       "Then I would be happy to stay for a while.",
                       "Never. It is good to see you again.",
                       "Perhaps I am looking at her.",
                       "I will. Until then, take care.",
                   ), start=1)]
    mary_followups = (
        "Then tell me, did you find what you were looking for?",
        "Your family must be glad to have you near.",
        "Careful, Arjun. I might believe you.",
        "I will hold you to that. Safe travels.",
    )
    arjun_closings = (
        "Not yet, but talking with you has made the day kinder.",
        "They are. Please give your family my regards.",
        "Then perhaps I should come by again.",
        "Until next time. Take care.",
    )
    extended = []
    for index, (followup, closing) in enumerate(zip(mary_followups, arjun_closings), start=1):
        extended.append((f"context_mary_flirt_followup_{index}", "Mary", followup))
        extended.append((f"context_arjun_mary_flirt_close_{index}", "Raghav", closing))
    worker_dialogue = []
    for index, (reply, followup, closing) in enumerate((
        ("I am well, thank you. How is the work going?", "It keeps me busy, but I am glad to see you.", "I will let you get back to it. Take care."),
        ("Of course. Is everything all right here?", "Yes, thank you. There is just much to do.", "Then I will not keep you. See you later."),
    )):
        worker_dialogue.append((f"context_arjun_worker_reply_{index}", "Raghav", reply))
        worker_dialogue.append((f"context_arjun_worker_close_{index}", "Raghav", closing))
        for profile, speaker in (("male", "Ravi"), ("male_alt", "Aakash"), ("female", "Meera"), ("female_alt", "Sneha")):
            worker_dialogue.append((f"context_worker_followup_{profile}_{index}", speaker, followup))
        worker_dialogue.append((f"context_mary_worker_followup_female_{index}", "Mary", followup))
    busy_choice = [("context_arjun_choice_busy", "Raghav", "I am sorry, I have to go. Let us talk later.")]
    departures = [
        ("context_mary_depart_0", "Mary", "It was lovely seeing you. Take care, Arjun."),
        ("context_mary_depart_1", "Mary", "Come by again when you have time. Goodbye."),
    ]
    ordinary_closings = (
        ("context_arjun_goodbye_0", "Raghav", "I am glad to hear that. Until we meet again."),
        ("context_arjun_goodbye_1", "Raghav", "You too. I will let you get back to it."),
    )
    # Ordinary conversations also require Arjun's reply; produce those before
    # remaining nonessential auditions and other NPC variants.
    priority = [item for item in pairs if item[0].startswith(("context_arjun_reply_", "context_shop_", "context_arjun_shop_"))
                or (item[0].startswith("context_peer_") and item[0].endswith(("_0_question", "_0_answer")))]
    remaining = [item for item in pairs if item not in priority]
    return tuple(busy_choice + list(ordinary_closings) + departures + extended + worker_dialogue + arjun_flirt + mary_flirt + mary + priority + studio + flirt + passing + worker + remaining)


def lesson_key(text):
    return hashlib.sha256(('Chacha\n' + text).encode()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model', default='naklitechie/indic-parler-tts')
    parser.add_argument('--device', choices=('cpu', 'mps'), default='cpu')
    args = parser.parse_args()
    # Ensure a normal termination removes any unfinished output file.
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    import numpy as np
    import soundfile as sf
    import torch
    from parler_tts import ParlerTTSForConditionalGeneration
    from transformers import AutoTokenizer
    if args.device == 'cpu':
        torch.set_num_threads(2)
    dtype = torch.float16 if args.device == 'cpu' else torch.float32
    model = ParlerTTSForConditionalGeneration.from_pretrained(args.model, torch_dtype=dtype).to(args.device)
    prompt_tokenizer = AutoTokenizer.from_pretrained(args.model)
    description_tokenizer = AutoTokenizer.from_pretrained(model.config.text_encoder._name_or_path)
    model.eval()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    pairs = LINES + tuple((lesson_key(text), 'Ravi', text) for text in LESSONS) + context_pairs()
    for name, speaker, text in pairs:
        target = OUTPUT / (name + '.wav')
        if target.exists():
            try:
                prior, prior_rate = sf.read(target)
                if prior.size and prior_rate > 0 and len(prior) / prior_rate > .2 and np.isfinite(prior).all() and float(np.sqrt(np.mean(prior * prior))) >= .0001:
                    continue
            except (OSError, RuntimeError, ValueError):
                pass
            print(f'Regenerating invalid existing clip: {target}', flush=True)
        if name.startswith('audition_female_') or name.startswith('context_mary_'):
            mood = 'startled and indignant, with urgency' if any(part in name for part in ('collision', 'assault')) else ('warm and playful, with a gentle smile' if 'flirt' in name or name.startswith('audition_') else 'warm and attentive')
            description = f'{speaker} speaks English in an expressive Indian accent, like a professional actress in a close-microphone studio. She sounds {mood}, with natural varied intonation and a conversational pace. Her voice is clear, with no background noise or reverberation.'
        elif name.startswith('context_flirt_female'):
            description = f'{speaker} speaks English with an Indian accent, with a warm playful smile, gentle teasing and natural conversational rhythm. Her voice is expressive and human, softly spoken in a clear close recording.'
        else:
            description = f'{speaker} speaks English with an Indian accent, in a natural expressive voice. The recording is very clear, with no background noise.'
        desc = description_tokenizer(description, return_tensors='pt').to(args.device)
        prompt = prompt_tokenizer(text, return_tensors='pt').to(args.device)
        torch.manual_seed(2026)
        with torch.inference_mode():
            output = model.generate(input_ids=desc.input_ids, attention_mask=desc.attention_mask,
                                    prompt_input_ids=prompt.input_ids, prompt_attention_mask=prompt.attention_mask)
        audio = output.cpu().numpy().squeeze().astype(np.float32)
        if not audio.size or not np.isfinite(audio).all():
            raise RuntimeError(f'Invalid audio for {name}')
        rms = float(np.sqrt(np.mean(audio * audio)))
        peak = float(np.max(np.abs(audio)))
        if rms < 0.0001 or peak < 0.0001:
            raise RuntimeError(f'Silent audio for {name}')
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(prefix='.context-voice-', suffix='.wav', dir=OUTPUT, delete=False) as handle:
                temporary = Path(handle.name)
            sf.write(temporary, audio * min(0.06 / rms, 0.89 / peak), model.config.sampling_rate)
            os.replace(temporary, target)
        finally:
            if temporary is not None and temporary.exists():
                temporary.unlink()
        print(f'{name}: {speaker} -> {target}', flush=True)


if __name__ == '__main__':
    main()
