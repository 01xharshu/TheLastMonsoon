# World effects — 2026-10-06

Nine original deterministic synthesized effects are rebuilt by `tools/audio/build_world_effects.py`; five quiet work/contact textures are rebuilt by `tools/audio/build_work_effects.py`. Their synthesis uses no external samples. Arjun/NPC dirt, stone and timber footsteps now use six recorded CC0 variants from `audio/ambience`, prepared by `tools/audio/build_recorded_footsteps.py`. The original synthesized dirt step remains the cattle hoof contact candidate.

The action pool has 25 keys with 24 concurrent spatial voices. Six footstep variants share three of those keys. Environment fire loops use eight separate bounded voices plus one river voice; wind uses one non-positional player. All new recordings, source archives, processing changes and licences are retained in [audio credits](../../AUDIO_CREDITS.md) and `WorkingAssets/Audio/world_sources` manifests.

The quill cue is bound to the seated writing candidate, which is not installed in the current live office. Static workshop props receive no fictitious active work sounds. Successful market sorting, live office paperwork, currency handling, fodder transfer, water carrying and moving carts have activity-specific cues. Mix/asset naturalness remains subject to listening and owner approval.

2026-10-09: wind uses a 24-second filtered noise texture, with low rumble removed and PCM import for runtime loop crossfading. Ambient audio has a separate saved volume bus, default 40%; current status: [ambient audio settings](../../docs/world/ambient_audio_settings.md).
