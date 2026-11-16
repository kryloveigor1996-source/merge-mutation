# Merge Mutation — Godot 4 prototype

A standalone, playable 2D cartoon merge game prototype. No external assets, plugins, or internet required.

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
- **NEW GAME** opens a confirmation dialog before replacing progress with the initial board and 100 coins. Use it to restart a full or otherwise stuck board.

## Included
- 5 × 6 board, 10 evolution levels, coins, randomized spawn, drag/drop, merge, saving/loading.
- Temporary cartoon creatures drawn procedurally. Replace with individual transparent PNG assets later.
- Portrait 360 × 640 logical layout.

## Notes
- This is an MVP gameplay prototype, not a finished production app. No ads, IAP, sounds, animations, analytics or export presets.
- Mouse and primary-finger touch inputs are supported. Mouse/touch emulation is disabled to prevent duplicate purchases; extra fingers are ignored. Losing application focus cancels a drag.
- Saves are validated before loading and written to a temporary file before replacement. An invalid save starts a fresh game; write failures show an on-screen message.

## Automated checks

From this folder, run with your Godot executable:

```text
godot --headless --editor --import --quit --path .
godot --headless --path . --script res://tests/prototype_test.gd
godot --headless --path . --quit-after 10
```

The regression suite writes only to `res://.godot/prototype_test_save.json`, not the player's save. It checks all 30 cell centers and board edges, movement/cancellation, all nine merge transitions, rewards, maximum/mismatched levels, spawn cost and full/empty-wallet cases, reset, save/load, and malformed save data.

Validated on 16 November 2026 with Godot 4.7.2 Steam on Windows: 84 regression checks passed, headless editor import and main-scene startup completed without errors, and F5 launched the game in the editor. Touch-event routing is covered with synthetic events; physical-device testing remains manual.

## Manual validation in Godot 4.7.2

- Import this checkout's `project.godot`, press F5, and check Output/Debugger.
- Drag to empty cells, onto equal/different levels, and outside the board; switch windows mid-drag.
- Create a slime and check the 10-coin charge. Merge and check `15 × new level` coins.
- Close/reopen the game and confirm board, coins, merges, and best level survive.
- Test NEW GAME: cancel preserves progress; confirm restores four slimes and 100 coins.
- On a physical touch device, check one purchase per tap, primary-finger drag, and extra-finger isolation. Desktop/headless checks do not validate Android input or export.
