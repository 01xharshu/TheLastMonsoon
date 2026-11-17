"""File names required before Mary dialogue can be checked end to end."""

def mary_required(first_extended=False):
    names = []
    for index in range(2):
        for kind in ('hello', 'farewell', 'collision', 'assault'):
            names.append(f'context_mary_female_{kind}_{index}.wav')
        names.extend((f'context_mary_pass_female_{index}.wav', f'context_mary_worker_female_{index}.wav'))
        names.extend(f'context_mary_peer_female_{index}_{part}.wav' for part in ('question', 'answer'))
        names.append(f'context_arjun_reply_{index}.wav')
        if not first_extended:
            names.append(f'context_mary_depart_{index}.wav')
    for index in range(1, 2 if first_extended else 5):
        names.extend((f'context_mary_flirt_{index}.wav', f'context_arjun_mary_flirt_{index}.wav',
                      f'context_mary_flirt_followup_{index}.wav', f'context_arjun_mary_flirt_close_{index}.wav'))
    return tuple(names)
