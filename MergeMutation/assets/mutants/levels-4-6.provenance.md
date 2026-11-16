# Levels 4–6: source-preserving sprite preparation

All three originals are 1254×1254 RGBA images with real alpha-zero background.
No black/white color key, AI redraw, geometric replacement or painted background
was used. The original pixels, proportions, colors, gloss and outlines are retained
through proportional downsampling.

| Level | Source | Alpha-zero source pixels | Output alpha bounds |
| --- | --- | --- | --- |
| 4 / Bubbler / Пузырник | `bubble_reference.png` | 720444 | `(20,20,216,215)` |
| 5 / Shellback / Панцирник | `shell_reference.png` | 719461 | `(20,24,216,208)` |
| 6 / Wingling / Крылатик | `wing_reference.png` | 873099 | `(20,45,216,166)` |

Unchanged originals are versioned in `assets/references/`; its existing `.gdignore`
keeps large authoring references out of runtime texture import. SHA-256:

- Bubble: `314c46925c2f17abd0d7aa3b3712c3a3552ce0f82c69c396b387cb0156118a11`
- Shell: `c3387935f2097df0e93749df03772c08a69f464c657b93bd640c67732145d461`
- Wing: `5daf408a063aef842876ddc8e06fc3118433911a8c6239cf296676ef16cd21d5`

## Preparation and scale

`tools/prepare_mutant_sprites.gd` now handles levels 2–6. It clears only invisible
alpha below 0.01, crops to the remaining alpha, corrects edge RGB, resizes with
Lanczos and centers the result on a transparent 256×256 RGBA8 canvas. No color key
is applied, so white highlights, cream spikes and dark contours are preserved.

The full silhouette's longest side is 216px, matching levels 2–3. Wings/spikes are
included when measuring bounds; proportions are never stretched to fill a square.
The existing 56×56 draw rectangle and Tween timings/rotation/scales are unchanged.
All three imports are lossless with alpha-border correction and mipmaps. The
existing level-1/2/3 PNGs remain byte-identical.

## Validation in Godot 4.7.2

- 84 gameplay + 55 presentation + 30 Slime + 45 level-2/3 + 66 level-4/5/6 checks:
  **280 passing**, with no Godot errors/warnings.
- Tests check PNG/RGBA8/256×256, real alpha-zero margins, shared 216px extent,
  correct texture selection, import settings and retained spawn/lift/settle Tweens.
- Full alpha-bounds corners fit 62px and 64px cells, both at rest and with a
  conservative 1.20 scale plus rotation (above the 1.17 selection Tween target).
- Actual merges 3→4, 4→5 and 5→6 retain rewards of 60, 75 and 90 coins and display
  the right PNG. Collection opening and save/load remain functional.
- Actual GPU 64px alpha bounds, including the existing shadow:
  level 4 `(7,7,50,52)`, level 5 `(7,8,50,51)`, level 6 `(7,12,50,47)`.
  No bounds touch a cell edge. Five contrasting backgrounds were inspected.
- Levels 7–10 still use procedural art; main gameplay, save format and scene are
  unchanged. All tests/captures use separate disposable saves.

## Reproduce

```text
godot --headless --path . --script res://tools/prepare_mutant_sprites.gd
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/mutant_levels_4_6_test.gd
godot --path . --script res://tests/capture_mutants_1_6.gd
```

GPU capture requires a display. It writes `.godot/mutants-levels-1-6-field.png` and
`.godot/mutants-levels-1-6-cell-proof.png`, with illustrative progress. The proof
rows are levels 1–6; columns are cream, dark blue, teal, magenta and checkerboard.
Physical Android display/touch QA and APK/AAB export are not covered by this run.
