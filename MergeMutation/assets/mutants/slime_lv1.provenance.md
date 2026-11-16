# Slime level 1 — source and preparation

- User-supplied sheet: `assets/references/slime_reference.png.png` (the actual local
  filename has a duplicated extension; the source was left untouched).
- Selected pose: second row, first column, labelled «Обычный».
- Tool: built-in imagegen, edit/background-extraction mode, transparent background.
- Limitation: imagegen reconstructs the isolated character; this is not a
  pixel-identical source mask. The flattened reference cannot provide the original
  jelly's exact alpha. The glossy/translucent appearance is painted into the body;
  exterior alpha is real, with antialiased edges. For strict original-pixel fidelity,
  provide the separate transparent source PNG/PSD or a manually prepared mask.
- No text, arrows, other characters, floor, white rectangle or checkerboard was
  retained in the sprite.

## Final imagegen prompt

> Use case: background-extraction. Edit target: the supplied reference sheet.
> Extract ONLY the normal green slime in the SECOND ROW, FIRST COLUMN, directly
> above the Russian label 'Обычный' (approximately x45–270 y430–625 in the 1536x1024
> reference). Preserve this exact character's pear/dome silhouette, lime-green
> glossy jelly body, huge cream-and-black open eyes, joyful small open smiling mouth,
> translucent internal lime bubbles, wet white highlights and dark-green outline.
> This is a clean cutout, not a new design: retain the original pose, face,
> proportions and colors. Remove EVERYTHING else: all background, floor/cast shadow,
> text, numbers, arrows, symbols, other characters, UI, frame. Do not retain a
> rectangular crop, colored halo, white matte or checkerboard pixels. Output one
> centered character on a genuinely transparent RGBA background, a square sprite
> with small equal transparent margins around the entire silhouette. Keep the
> character whole, including the low pooled jelly base. Intended output asset
> slime_lv1.png 256x256; make details clean and readable at 64x64. If output resolution
> is larger, keep square composition and alpha intact for later technical
> downsampling. No extra elements, no text.

## Technical normalization

The tool returned a 1254×1254 RGBA image. Alpha below 0.01 was cleared to remove
invisible background speckles. The remaining bounds `(193,251,866,728)` were fitted
proportionally into 224×188, using Godot's Lanczos resize and alpha-edge correction,
then placed at `(16,34)` on a transparent 256×256 RGBA8 canvas. No white/green color
key was applied, so eye whites and glossy highlights remain intact.

The final PNG and its import settings are committed; runtime has no generation,
extraction, network or API dependency. Gameplay and save format are unchanged.
