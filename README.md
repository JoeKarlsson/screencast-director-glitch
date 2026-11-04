# screencast-director-glitch

Analog and glitch effects for [Screencast Director](https://github.com/JoeKarlsson/screencast-director): a worn VHS/CRT signal now, with datamosh cuts and pixel-sorted thumbnails to come.

## Effects

| Effect | Layer | What it does |
|---|---|---|
| `analog` | frame | Chroma split and bleed, bloom on highlights, an optional green-phosphor grade, scanlines, grain, a vignette, and a tape-tracking band that rolls through every 14 s |
| `cut-glitch` | frame | A few motivated moments instead of a glitch on every cut: a short VHS rewind with VCR `REW` / `PLAY` text when the video jumps back after a cold open, and a hard break-up at each new section (a chapter or slate title; six kinds take turns). Plain cuts stay clean |

`analog` params (defaults in brackets): `chroma` [5] and `bleed` [10] in pixels at 1080p, `scanlines` [0.2], `grain` [0.035], `bloom` [1], `vignette` [0.35], `tracking` [1] (the band's strength; 0 turns it off), `phosphor` [0] (0 keeps the picture's color, 1 is green-phosphor monochrome; 0.45 gives a Matrix-green cast).

`cut-glitch` params: `window` [0.12] (seconds each side of a section change), `amount` [1], `rewind` [0.35] (seconds the rewind takes), `osd` [1] (0 hides the VCR text).

For B-roll, pair it with Screencast Director's interlace transition: `"brollMotion": { "preset": "interlace", "seconds": 0.25 }` in the profile's `style`.

List `cut-glitch` before `analog` so the analog layer wears down the glitch too.

## Install

```sh
./install.sh
```

This copies each effect into `~/Library/Application Support/Screencast Director/Effects/`. It copies rather than links: a video freezes its own copy the first time it uses an effect, and a link would freeze as a link. Run it again after pulling changes. Videos that already use an effect keep their frozen copy until you delete their `effects/<name>/` folder.

Then turn an effect on in a video's `plan.json` or a profile's `profile.json`:

```json
"effects": [{ "name": "analog", "params": { "tracking": 0.5 } }]
```

Titles and captions are drawn on top of every effect, so they stay readable.

## Write your own

See [docs/effects.md](https://github.com/JoeKarlsson/screencast-director/blob/main/docs/effects.md) in Screencast Director. Each effect here is a folder with `effect.json` and `effect.metal`.

## License

MIT
