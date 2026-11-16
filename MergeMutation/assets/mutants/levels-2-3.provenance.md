# Levels 2 and 3: source-preserving PNG preparation

## Sources

The supplied drawings already contain genuine RGBA transparency. The black
background shown by some viewers is not an opaque black matte. No image generation,
redrawing, color key, geometric replacement or background hallucination was used.

| Output | User-supplied source | SHA-256 of unchanged source |
| --- | --- | --- |
| `mutant_lv2.png` | `assets/references/eyeball_reference.png` | `919de88db2c90e1a8df0b810dc53e082cc7fc3c2465c07b914727a05bc38b6c2` |
| `mutant_lv3.png` | `assets/references/horned_reference.png` | `0ed4c2ef444103709773f47c93ca58ea2917e7bd434c9105a758f99da7ade82d` |

Both originals are retained in Git for authoring/reproducibility. Their `.gdignore`
prevents importing the large reference sheets as runtime textures. The offline
preparation utility reads them directly with FileAccess, so no plugin is needed.

## Deterministic preparation

Run from the Godot project directory:

```text
godot --headless --path . --script res://tools/prepare_mutant_sprites.gd
```

This explicitly rebuilds the two final PNGs. It clears only alpha below 0.01,
removing almost invisible stray pixels around the existing cutout; it does not
remove dark pupils/outlines, white eye regions or cream horns. It crops using
the remaining alpha, fixes edge RGB, applies a proportional Lanczos resize and
centers the entire character on a transparent 256x256 RGBA8 canvas.

| Level | Source alpha bounds after noise cleanup | Final alpha bounds |
| --- | --- | --- |
| 2 | `(140,145,942,948)` | `(20,20,215,216)` |
| 3 | `(146,99,932,1029)` | `(30,20,196,216)` |

Both full silhouettes use the same 216px longest edge, about 4% below the existing
Slime's 224px extent. This preserves a comparable on-board scale while reserving
space for horns, antennae and the selection Tween's overshoot. The shared 56x56
draw rectangle, rotation and animation timings are unchanged. PNGs use lossless
import, alpha-border correction and mipmaps, matching the Slime's filtering.

## Validation

- 84 gameplay + 55 presentation + 30 Slime + 45 level-2/3 checks = 214 passing.
- The Slime suite's two obsolete expectations of procedural level 2/3 art now
  check their named PNGs; remaining gameplay assertions are unchanged.
- New checks cover RGBA8/256x256, actual alpha-zero borders and gaps between horns
  or antennae, texture routing, uniform silhouette extent, imported mipmaps,
  lossless settings, retained animations and 62/64px cell bounds. Selected bounds
  use a conservative 1.20 scale, exceeding the Tween's 1.17 target.
- Actual GPU 64px alpha bounds, including the existing procedural ground shadow:
  level 1 `(7,10,50,49)`, level 2 `(7,7,50,52)`, level 3 `(9,7,47,52)`; none touch
  the cell edge. Art and cutout edges were inspected on five backgrounds.
- A separate disposable save is used by all tests and captures.

Use `tests/capture_mutants.gd` without `--headless` for the GPU proof. It writes
`.godot/mutants-field.png` and `.godot/mutants-cell-proof.png`. The proof's rows are
levels 1, 2 and 3; columns are cream, dark blue, teal, magenta and checkerboard.

Main gameplay logic, rewards, spawn cost, save schema, Slime PNG and level 4–10
art are unchanged. Physical Android devices still need visual/touch QA.
