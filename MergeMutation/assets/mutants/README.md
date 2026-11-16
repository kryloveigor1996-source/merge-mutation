# Mutant artwork slot

The ten fallback characters are original Godot drawings in `scripts/mutant_art.gd`.
No external images or image-generation service are required.

To replace a character, add a **256 × 256 transparent PNG**, centered with a little
padding, using these filenames:

| File | Level | Character |
| --- | --- | --- |
| `01.png` | 1 | Slime |
| `02.png` | 2 | Eyeling |
| `03.png` | 3 | Hornling |
| `04.png` | 4 | Bubbler |
| `05.png` | 5 | Shellback |
| `06.png` | 6 | Wingling |
| `07.png` | 7 | Tentacly |
| `08.png` | 8 | Chimera |
| `09.png` | 9 | Mutant Rex |
| `10.png` | 10 | Ultra Mutant |

Godot imports the files automatically. Each slot independently falls back to its
procedural drawing. The same art node is used by the board and collection;
animations, drag behavior and save files do not need to change.
