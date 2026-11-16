# Progressive mutant sizes and Godot compilation audit

## Base and preservation

Work starts at `656c2f8`, the main-branch merge of PR #6. Main gameplay, the 5×6
grid with 62px cell pitch, input-to-cell mapping, merge rules, spawn cost, rewards,
save schema, six original PNGs and sound code are unchanged. All tests/captures
use disposable saves. The player's existing save was hash-checked before and
after an actual F5/F8 editor run and remained byte-identical.

## The two compilation errors

Both wrappers originally assigned inherited fields directly in `_initialize()`:
`levels` in `mutant_levels_4_6_test.gd` and `captured_levels` in
`capture_mutants_1_6.gd`. These fields were introduced in the parent scripts by
PR #6. Their pre-PR6 parents do not declare them. Analysing a new wrapper against
that old parent API produces the reported missing-identifier errors, followed by
dependent-script load failures.

Evidence: both original wrappers passed a cold Godot 4.7.2 `--check-only` against
the current on-disk parents even before the fix. Pairing the same wrappers with
the parent versions from `5042a52^` reproduced the missing `levels`,
`captured_levels` and other new configuration fields. The open editor was using
the correct project path. This supports a stale/mixed parent-definition state
after updating PR #6, rather than a general prohibition on GDScript inheritance.
The previous live editor's internal cache cannot be reconstructed directly, so
that cache history is a diagnosis from the reproduction, not a claimed engine
source-code finding.

Fix: wrappers now override only `configuration() -> Dictionary`, returning literal
options. Each parent applies these options to its own fields in its own
`_initialize()`. No wrapper accesses inherited storage or duplicates runner logic.
The two affected entry points were checked separately, and both executed: the
level-4/5/6 suite ran all 66 checks; the six-species GPU capture completed.

`tools/check_gdscript.ps1` discovers all project GDScript files except generated
`.godot/` cache files. It launches a fresh Godot editor-mode `--check-only` process
per file and fails on a nonzero exit code OR any ERROR/WARNING log, so a successful
main-scene run or a misleading test summary cannot hide a helper compilation error.

## Single size configuration

Edit only `scripts/mutant_sizes.gd` to tune board size, portrait size and overlap
limits. Sizes below are the longest visible silhouette edge in design pixels,
not the transparent 256×256 canvas. PNG alpha bounds are cached from the imported
image and the exact source region is drawn proportionally. Procedural art uses
conservative geometry bounds including mitered outlines, crowns and tentacles;
its raster footprint can differ by a few pixels due to antialiasing and shadows.

| Level | Board visible edge | Collection visible edge |
| --- | --- | --- |
| 1 | 52px | 48px |
| 2 | 54px | 48px |
| 3 | 56px | 48px |
| 4 | 58px | 48px |
| 5 | 62px | 48px |
| 6 | 68px | 48px |
| 7 | 72px | 48px |
| 8 | 76px | 48px |
| 9 | 80px | 48px |
| 10 | 84px | 48px |

The last two values were reduced from the suggested 82/90px after reviewing a
fully occupied board: progression remains visible without obscuring most of a
neighbour. Normal silhouettes may overhang a 62px cell by at most 12px per side.
Selection allows a larger temporary envelope. Legacy asset checks sample rotation
and a 1.20 scale; the runtime guard uses 1.32 to cover the larger back-ease
overshoot when a character is selected during its initial tiny spawn scale. Tween
timings and the existing 1.17 lift target are unchanged.

The visual node is bounded within the tray's UI-safe area, including its shadow
and a conservative animation guard. Only the rendered position is bounded:
`pointer_pos`, `_cell_at()` and logical drop coordinates are not modified. A real
touch on visible wing pixels over another cell therefore selects that underlying
cell; a wing over an empty cell is not an enlarged hit target.

Selected/moving art uses z=18, above ordinary art and merge ghosts/particles. The
discovery banner uses z=19, and modal UI z=20. Selection stays on top until its
settle/drop Tween finishes. Spawn, lift, settle and merge durations are unchanged.
Collection art uses its own 48px normalization, without inheriting board sizes.

## Images

- [Before: six PNG levels with the old 56px canvas](progressive-before.png)
- [After: identical sample board with progressive sizes](progressive-after.png)
- [Dense board containing all ten levels](progressive-dense.png)
- [Collection: higher levels remain inside their cards](progressive-collection.png)

The GPU proof captures use 128px transparent viewports at 1:1 design scale. A 64px
capture would intentionally clip larger levels under the new overlap policy.
All ten silhouettes were captured without touching the 128px border. The board
screenshots are illustrative progress, not the player's save.

## Validation, Godot 4.7.2 Steam / Windows

- **509 checks pass**: the existing 84 + 55 + 30 + 45 + 66 = 280, plus **229** new
  progressive-size checks. Old fixed-56px / strict-cell-containment assertions were
  updated for the requested controlled-overhang contract; PNG validation remains.
- New checks cover all ten board/collection sizes, PNG/procedural routing, all
  30 resting cells, every level's selection at the tray edges, visual pointer
  bounds, raw pointer preservation, cancel, move, merge, actual wing overlap touch
  routing, z-order above live merge effects, ten collection cards and the unchanged
  save schema. Rapid selection during spawn and cancel Tweens are sampled over
  multiple frames to check that UI remains clear throughout, not just at endpoints.
- **18 GDScript files** pass independent cold compilation, including the two
  reported wrappers, all test entry points and authoring/capture utilities.
- Actual editor F5/F8 launch observed, with zero error/warning counters.
- GPU rendering covers levels 1–6, all ten levels on a dense board and collection.
- Headless editor import and normal headless scene startup are clean. Repeated
  import is checked for a clean working tree after commit.

Commands, run from the project folder:

```text
pwsh -File tools/check_gdscript.ps1 -GodotPath "<path-to-godot.exe>"
godot --headless --path . --script res://tests/prototype_test.gd
godot --headless --path . --script res://tests/presentation_test.gd
godot --headless --path . --script res://tests/slime_sprite_test.gd
godot --headless --path . --script res://tests/mutant_sprites_test.gd
godot --headless --path . --script res://tests/mutant_levels_4_6_test.gd
godot --headless --path . --script res://tests/progressive_sizes_test.gd
godot --path . --script res://tests/capture_mutants_1_6.gd
godot --path . --script res://tests/capture_all_sizes.gd
```

## Changed files

- `.gitattributes`: LF rule for the Windows validation helper.
- `scripts/mutant_sizes.gd` (+ UID): central configuration, alpha-normalized
  geometry, portrait sizing and UI-safe visual placement.
- `scripts/mutant_art.gd`: apply visible size without altering PNGs or Tween code.
- `scripts/lab_view.gd`: bounded visual positioning, selection stacking, banner
  layer and independent collection sizing.
- `tests/mutant_sprites_test.gd`, `tests/mutant_levels_4_6_test.gd`: explicit
  configuration API and updated overlap assertions, shared runner retained.
- `tests/capture_mutants.gd`, `tests/capture_mutants_1_6.gd`: same configuration
  API, unclipped proof viewports and optional dense/collection captures.
- `tests/slime_sprite_test.gd`: use visible sizes/overhang rather than a 56px canvas.
- `tests/progressive_sizes_test.gd` (+ UID): 229 new checks.
- `tests/capture_all_sizes.gd` (+ UID): dense all-level GPU fixture.
- `tools/check_gdscript.ps1`: cold compile every GDScript with log validation.
- `README.md`, `assets/mutants/README.md`, this report and four screenshot PNGs
  with their `.png.import` sidecars.

Limits: no physical Android/cutout-device test or APK/AAB export was performed.
Touch routing is tested with synthetic events; perceived overlap and finger
comfort should still be reviewed on a real phone. No paid API or new library is
required. Source sprites and sound are unchanged.
