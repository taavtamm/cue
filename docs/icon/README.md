# App icon

`App/Resources/AppIcon.icon` is an Icon Composer document (macOS 26+ layered
format). Xcode compiles it into `Assets.car` (Light, Dark and Tinted
appearances) plus an `AppIcon.icns` fallback.

It reproduces `CueIcon.dc.html` from the design canvas:

| Group | Layers | Treatment |
|---|---|---|
| Play (top) | `triangle.svg`, rounded play triangle | System glass on, translucency 0.45, specular, opacity 0.55 |
| Glow | `glow.png` blurred conic blob, `rim.png` rainbow edge | Flat, no glass, no shadow |
| Background | Linear gradient `#33333B → #050507` | Fill on the document |

The system derives the Dark, Clear and Tinted looks. Icon Composer's
"Default" slot is the light-appearance icon, so Cue's Default is the dark
tile from the design.

## Small sizes

The `.icon` format has no per-size artwork: 16 and 32 px are rendered from
the same layers. They still read as tile plus triangle (see
`renditions.png`, last two). The glow just softens into a colour wash. If
hand-drawn small sizes are ever needed, the fallback is to drop the `.icon`
and ship a classic `AppIcon.appiconset`, losing the system glass looks.

## Changing it

- Edit `icon.json` by hand or open the document in Icon Composer
  (Xcode ▸ Open Developer Tool).
- Regenerate `glow.png` and `rim.png` with `generate-layers.swift`.
- Preview without the GUI:

```sh
ictool App/Resources/AppIcon.icon --export-image --output-file out.png \
  --platform macOS --rendition Default --width 512 --height 512 --scale 1
```

`ictool` lives in `Icon Composer.app/Contents/Executables/`.
