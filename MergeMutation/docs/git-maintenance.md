# Git / Godot 4.7.2 maintenance audit

Validated on 16 November 2026 with Godot 4.7.2 Steam on Windows.

## Initial seven entries

All seven files were inspected before any normalization. Their original bytes and
SHA-256 manifest were copied to the ignored local directory
`.godot/maintenance-backups/git-cleanup-b726f12d7ba7428c82176d6774a22669/`.
No local file was deleted, reset, or replaced with an older revision.

| Path (relative to this project) | Finding | Resolution |
| --- | --- | --- |
| `project.godot` | Godot removed explicit `pointing/emulate_touch_from_mouse=false`. | Accept omission of the engine default; runtime query still returns `false`. |
| `assets/mutants/slime_lv1.png.import` | Raw file hash exactly matches HEAD; no import-setting change. | Keep tracked, refresh EOL policy/index. Preserve lossless mode, mipmaps and alpha correction. |
| `docs/slime-cell-64.png.import` | Raw file hash exactly matches HEAD. | Keep tracked with LF. |
| `docs/slime-cell-proof.png.import` | Raw file hash exactly matches HEAD. | Keep tracked with LF. |
| `docs/slime-field.png.import` | Raw file hash exactly matches HEAD. | Keep tracked with LF. |
| `docs/collection-v0.2.png.import` | Previously untracked, automatically created metadata for an existing PNG. | Add the reviewed relative cache paths, stable UID and import parameters to Git. |
| `docs/preview-v0.2.png.import` | Previously untracked, automatically created metadata for an existing PNG. | Add reviewed import metadata to Git. |

## Cause and policy

The global Git installation has `core.autocrlf=true`; Godot writes its text files
using LF. Without repository attributes, Git expected CRLF worktree files and
warned that LF would be replaced. Four sidecars appeared modified even though raw
and filtered blob hashes matched HEAD. The other two sidecars had never been
tracked, so opening Godot generated new untracked entries.

`.gitattributes` now explicitly keeps Godot scripts, scenes, text resources,
configuration, import settings and UID sidecars as LF in both index and worktree.
Documentation and other common text configurations also use LF; binary assets are
marked binary. No global/local `core.autocrlf` configuration was changed.

Twenty-five previously clean tracked text files were normalized from CRLF to LF
in the worktree. Their normalized repository contents are unchanged; no gameplay
or resource-content diff is introduced. The index was refreshed with
`git add --renormalize` only after inspecting the existing changes.

`.gitignore` already correctly excluded every `.godot/` cache directory and logs.
Its behavior is unchanged; a comment documents why `.png.import` and `.gd.uid`
files must remain tracked. Import settings are not the generated `.ctex` cache:
keeping their relative paths, UIDs and parameters makes import reproducible.
No blanket `*.import` ignore, tracked-file deletion, or cache commit was used.

## Validation

- Every tracked text file now reports `i/lf w/lf` with `text eol=lf`; binary assets
  report `-text`. Staging produced no LF/CRLF conversion warnings.
- `.godot/` is ignored and contains no tracked files. All six PNG import sidecars
  are tracked and are not ignored.
- Both pointing-emulation settings evaluate to `false`; level 1 resolves to the
  existing `assets/mutants/slime_lv1.png`.
- Two consecutive headless editor imports preserved SHA-256 for all 40 source
  files in the pre-import snapshot, including binary assets and import metadata.
- Existing suites passed unchanged: 84 gameplay + 55 presentation + 30 sprite
  checks = 169, with no Godot errors or warnings.
- Headless main-scene launch passed. GPU capture showed the Slime on the board;
  64x64 render alpha bounds remain `(7,10,50,49)`, with no clipping.
- Existing player save/preferences were fingerprinted before validation and
  remain byte-identical afterwards. Test captures use separate disposable saves.

Gameplay scripts, scene contents, PNG pixels, audio and save schema are unchanged.
