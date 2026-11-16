# Merge Mutation — Godot 4 prototype

A standalone, playable 2D cartoon merge game prototype. No external assets, plugins, or internet required.

## Open
1. Open Godot 4.2+ (4.3/4.4/4.5/4.6 should also be compatible).
2. In Project Manager choose **Import** and select `project.godot` in this folder.
3. Open the project and press **F6** while `scenes/main.tscn` is open, or **F5** to run the project.

## Controls
- Click/tap **CREATE SLIME** to add a level-1 creature (costs 10 coins).
- Drag a creature to an empty cell to move it.
- Drag a creature onto another creature of the **same level** to merge them into the next level (up to level 10).
- Every merge earns `15 × new level` coins.
- Progress is automatically saved to `user://merge_mutation_save.json`.

## Included
- 5 × 6 board, 10 evolution levels, coins, randomized spawn, drag/drop, merge, saving/loading.
- Temporary cartoon creatures drawn procedurally. Replace with individual transparent PNG assets later.
- Portrait 360 × 640 logical layout.

## Notes
- This is an MVP gameplay prototype, not a finished production app. No ads, IAP, sounds, animations, analytics or export presets.
- Mouse and touch inputs are supported. On some platforms Godot can emulate mouse events from touch events; duplicate releases are harmless here.
- The current build has no reset button. To reset, remove the saved file via Godot's **Project > Open User Data Folder** while the game is closed.
