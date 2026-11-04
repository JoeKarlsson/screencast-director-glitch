# screencast-director-glitch

Analog and glitch effects for [Screencast Director](https://github.com/JoeKarlsson/screencast-director): a worn VHS/CRT signal now, with datamosh cuts and pixel-sorted thumbnails to come.

## Effects

| Effect | Layer | What it does |
|---|---|---|
| `analog` | frame | Chroma split and bleed, warm bloom on highlights, scanlines, grain, a vignette, and a tape-tracking band that rolls through every 14 s |

`analog` params (defaults in brackets): `chroma` [5] and `bleed` [10] in pixels at 1080p, `scanlines` [0.2], `grain` [0.035], `bloom` [1], `vignette` [0.35], `tracking` [1] (the band's strength; 0 turns it off).

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
