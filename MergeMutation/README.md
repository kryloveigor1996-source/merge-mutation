# Merge Mutation 0.2 — The Mutation Lab

A standalone, playable 2D cartoon merge game prototype. No external assets, plugins, or internet required.

Visual previews with illustrative sample progress: [laboratory](docs/preview-v0.2.png) · [collection](docs/collection-v0.2.png).

Level-1 sprite update: [current slime field](docs/slime-field.png) · [64px GPU edge proof on five backgrounds](docs/slime-cell-proof.png).

Levels 2–3 sprite update: [three-species field](docs/mutants-levels-1-3.png) · [64px edge and scale proof](docs/mutants-levels-1-3-proof.png).

Levels 4–6 sprite update: [six-species field](docs/mutants-levels-1-6.png) · [64px edge and scale proof](docs/mutants-levels-1-6-proof.png).

Progressive sizes: [before](docs/progressive-before.png) · [after](docs/progressive-after.png) · [dense ten-level board](docs/progressive-dense.png) · [technical report](docs/progressive-sizes.md).

## Open
1. Open Godot 4.7.2 (the version used for validation).
2. In Project Manager choose **Import** and select `project.godot` in this folder.
3. Open the project and press **F6** while `scenes/main.tscn` is open, or **F5** to run the project.

## Controls
- Click/tap **CREATE SLIME** to add a level-1 creature (costs 10 coins).
- Drag a creature to an empty cell to move it.
- Drag a creature onto another creature of the **same level** to merge them into the next level (up to level 10).
- Every merge earns `15 × new level` coins.
- Progress is automatically saved to `user://merge_mutation_save.json`.
- **COLLECTION** shows discovered species and locked silhouettes.
- **UPGRADES** previews future equipment. These buttons are disabled and never spend coins.
- **SETTINGS** provides a sound toggle and **NEW GAME**, which opens a confirmation dialog before replacing progress with the initial board and 100 coins.

## Included
- 5 × 6 board, 10 evolution levels, coins, randomized spawn, drag/drop, merge, saving/loading.
- Bright tiled laboratory, raised specimen pads, coin/discovery counters, and large native touch buttons.
- Glossy PNG sprites for levels 1–6 (`slime_lv1.png`, `mutant_lv2.png` … `mutant_lv6.png`), with original procedural silhouettes for levels 7–10. Optional transparent 256×256 replacements remain supported.
- Tween animations for spawning, selection, smoothed dragging, drops and merges; a gold AnimationPlayer discovery banner and short-lived particle bursts.
- Four original synthesized sound effects, optional WAV/OGG replacements in `assets/audio/`, and a persisted mute setting.
- Portrait 360 × 720 design, uniformly fitted and centered in the available viewport. Android display safe area is respected; touch coordinates use the inverse presentation transform.

## Notes
- This is a visual MVP, not a finished store build. No ads, IAP, analytics, functional paid upgrades or export presets.
- Mouse and primary-finger touch inputs are supported. Mouse/touch emulation is disabled to prevent duplicate purchases; extra fingers are ignored. Losing application focus cancels a drag.
- Saves are validated before loading and written to a temporary file before replacement. An invalid save starts a fresh game; write failures show an on-screen message.

## Automated checks

From this folder, run with your Godot executable:

```text
godot --headless --editor --import --quit --path .
godot --headless --path . --script res://tests/prototype_test.gd
godot --headless --path . --script res://tests/presentation_test.gd
godot --headless --path . --script res://tests/slime_sprite_test.gd
godot --headless --path . --script res://tests/mutant_sprites_test.gd
godot --headless --path . --script res://tests/mutant_levels_4_6_test.gd
godot --headless --path . --script res://tests/progressive_sizes_test.gd
godot --headless --path . --quit-after 10
```

The regression suite writes only to `res://.godot/prototype_test_save.json`, not the player's save. It checks all 30 cell centers and board edges, movement/cancellation, all nine merge transitions, rewards, maximum/mismatched levels, spawn cost and full/empty-wallet cases, reset, save/load, and malformed save data.

Version 0.2 was validated on 16 November 2026 with Godot 4.7.2 Steam on Windows: all original 84 checks are unchanged and pass, plus 55 presentation checks. The new suite covers layout/inverse input mapping, native button touch routing, animation completion and cancellation, particle cleanup, first/repeat discovery effects, ten art slots, replacement texture support, panels, muted/generated audio and the unchanged save schema. Test saves remain in `.godot/`; tests never reset the player's progress.

For reproducible GPU previews (requires a display rather than `--headless`):

```text
godot --path . --script res://tests/capture_preview.gd
```

This renders an illustrative ten-species board and collection to `.godot/v02-preview.png` and `.godot/v02-collection.png` using a separate disposable save. This is sample data, not the player's live board.

`godot --path . --script res://tests/capture_slime.gd` additionally renders an isolated
slime field and an actual transparent 64×64 SubViewport, then checks its alpha bounds
and produces a five-background edge proof in `.godot/`. The sprite-specific suite
checks RGBA8 PNG data, exact size, alpha/padding, 62/64px resting and lifted bounds,
imported mipmaps, retained animations and procedural fallbacks for levels 7–10.

The slime was prepared with imagegen from the supplied reference pose; it is not a
pixel-identical mask of the flattened sheet. See `assets/mutants/slime_lv1.provenance.md`
for the full prompt, alpha-processing steps and fidelity limitation.

Levels 2 and 3 use the supplied artwork's existing transparency without AI
reconstruction. `assets/mutants/levels-2-3.provenance.md` records source hashes,
rebuild instructions and scale policy. Its 45 checks cover assets, animations,
cell bounds and merge-result textures and remain part of the full suite.
`godot --path . --script res://tests/capture_mutants.gd` creates a three-species
field screenshot and actual 64x64 GPU captures on five backgrounds in `.godot/`.

Levels 4–6 follow the same source-preserving process. Their source hashes, scale
and alpha measurements are recorded in `assets/mutants/levels-4-6.provenance.md`.
The shared sprite checks are data-driven; the new 4–6 entry adds 66 checks, for
**280 passing checks** overall. `tests/capture_mutants_1_6.gd` captures all six PNG
species and verifies their actual GPU alpha bounds in 64×64 cells. Existing PNGs
for levels 1–3, gameplay rules, save data and animations are unchanged.

Display sizes now come from `scripts/mutant_sizes.gd`: visible edges grow from
52px to 84px; collection portraits stay at 48px. PNG alpha padding is excluded
without changing the files. Controlled overlap never changes which logical cell
is touched; visual drag positions stay clear of resource/action UI. The full suite
now has 509 passing checks. Strict old 64px-capture fixtures are historical; new
proofs use unclipped 128px viewports. See the technical report for the final table.

On Windows, `pwsh -File tools/check_gdscript.ps1 -GodotPath "<path-to-godot.exe>"`
independently compiles every project GDScript, including all tests/helpers. The
two specialized runners return configuration dictionaries rather than assigning
inherited fields during `_initialize()`, avoiding stale parent-member lookup.

Slime integration validation (Godot 4.7.2): all existing 84 gameplay and 55
presentation checks pass unchanged, plus 30 new sprite checks. Headless import and
startup are clean. GPU-rendered 64×64 alpha bounds are `(7,10,50,49)`, leaving a
transparent border; the field and five-background proof were visually inspected.

## Implementation and replacement assets

- `scripts/main.gd`: existing gameplay state, rules and JSON saves; presentation receives events after state changes.
- `scripts/lab_view.gd`: scalable lab, native buttons, scrollable panels and visual orchestration.
- `scripts/mutant_art.gd`: shared board/collection art and character Tweens.
- `scripts/merge_burst.gd`: deterministic short-lived particles, independent of the spawn RNG.
- `scripts/lab_audio.gd`: audio routing and original synthesized placeholders.
- `assets/mutants/README.md` and `assets/audio/README.md`: filenames and replacement instructions.

The save filename and four JSON fields (`cells`, `coins`, `merges`, `highest`) are unchanged. Sound preference is separate in `user://merge_mutation_settings.cfg`. No migration, external dependencies or downloaded media are required. Static panel styles are cached and the board redraws only on interaction/state changes; character Tweens and bursts animate independently.

## Manual validation in Godot 4.7.2

- Import this checkout's `project.godot`, press F5, and check Output/Debugger.
- Drag to empty cells, onto equal/different levels, and outside the board; switch windows mid-drag.
- Create a slime and check the 10-coin charge. Merge and check `15 × new level` coins.
- Close/reopen the game and confirm board, coins, merges, and best level survive.
- Test SETTINGS → NEW GAME: cancel preserves progress; confirm restores four slimes and 100 coins.
- Inspect all ten species in COLLECTION, including the locked silhouettes and scrolling. UPGRADES should show future equipment without charging coins.
- Check appearance/selection/drop/merge animations, rapid repeated actions and first-discovery stars/banner.
- Listen to spawn/select/merge/discovery effects. Toggle sound off/on, then restart to verify the setting.
- Resize the desktop window and test tall/narrow Android screens with a cutout; the field and bottom buttons must stay visible and input must align with cells.
- On a physical touch device, check one purchase per tap, primary-finger drag, and extra-finger isolation. Desktop/headless checks do not validate Android input or export.
