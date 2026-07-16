# Music overrides

Drop `.ogg` or `.wav` files here (or into `user://music_overrides/` in the Godot
user data folder) named after a track id from `data/music_manifest.json`, e.g.
`item_shop.ogg` or `boss_battle.wav`. When a correctly named file exists it is
used instead of the default track.

Format notes:
- `.mov`, `.mp4`, `.mp3` etc. are NOT supported — convert to OGG first:
  `ffmpeg -i input.mov -c:a libvorbis -q:a 6 track_name.ogg`
- Beware WAVs exported from video tools: they often have a broken (streaming)
  header that Godot cannot import. If a `.wav` doesn't stick, re-encode it with
  the ffmpeg command above. OGG is preferred for music (much smaller).
- Files in THIS folder are baked in when exporting the game. Files in
  `user://music_overrides/` work with an already-exported build, no rebuild.
