"""Retain original MPFB bodies; clothing masks remain on clothing only."""
def retain_complete_body(body):
    for modifier in body.modifiers:
        if modifier.type == 'MASK':
            enabled = modifier.name == 'Hide helpers'
            modifier.show_viewport = enabled
            modifier.show_render = enabled
    body['complete_runtime_body'] = True
    body['body_retention'] = 'Complete original MPFB anatomy beneath separate clothing'
    return body
