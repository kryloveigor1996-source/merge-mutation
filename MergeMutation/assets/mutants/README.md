# Mutant artwork slot

Level 1 uses `slime_lv1.png`, a glossy green character prepared from the supplied
reference with the built-in imagegen editor. See `slime_lv1.provenance.md` for its
source, prompt and extraction limitation. Levels 2–6 use the original supplied
cutout drawings, normalized to `mutant_lv2.png` … `mutant_lv6.png` without redrawing;
see `levels-2-3.provenance.md` and `levels-4-6.provenance.md`. Levels 7–10 retain the original Godot
drawings in `scripts/mutant_art.gd` unless an optional numbered replacement exists.
No image-generation service is needed at runtime.

To replace a character, add a **256 × 256 transparent PNG**, centered with a little
padding, using these filenames:

| File | Level | Character |
| --- | --- | --- |
| `slime_lv1.png` | 1 | Slime |
| `mutant_lv2.png` | 2 | Eyeling / Глазастик |
| `mutant_lv3.png` | 3 | Hornling / Рогач |
| `mutant_lv4.png` | 4 | Bubbler / Пузырник |
| `mutant_lv5.png` | 5 | Shellback / Панцирник |
| `mutant_lv6.png` | 6 | Wingling / Крылатик |
| `07.png` | 7 | Tentacly |
| `08.png` | 8 | Chimera |
| `09.png` | 9 | Mutant Rex |
| `10.png` | 10 | Ultra Mutant |

Godot imports the files automatically. Each slot independently falls back to its
procedural drawing. The same art node is used by the board and collection;
animations, drag behavior and save files do not need to change.

The slime is RGBA8, exactly 256×256, with alpha bounds `(16,34,224,188)` and no
opaque background. Its import is lossless, with alpha-border correction and mipmaps.
The existing 56×56 art rectangle remains unchanged, fitting both the current
62-pixel board pitch and a 64×64 preview cell. Linear mipmapped minification keeps
this glossy illustration smooth without adding a blur effect.
