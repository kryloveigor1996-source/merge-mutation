# Merge Mutation repository

- This repository is exclusively for Merge Mutation. Check the working directory
  and `git rev-parse --show-toplevel` before changing files.
- Godot sources and resources: `MergeMutation/` (do not rename the inner folder).
  Engine cache and disposable test profiles/captures: `MergeMutation/.godot/`.
  Logs: repository `logs/import/`, `logs/runtime/`, `logs/tests/`; historical
  artifacts/backups: ignored `logs/archive/`. Builds: `builds/android/` and
  `builds/windows/`. Reviewed documentation/media: `MergeMutation/docs/`.
- Never write temporary reports or logs directly into the repository root.
  Use `tools/run_godot.ps1`, `check_gdscript.ps1` and `check_landscape.ps1`:
  they resolve paths from their own location and run Godot in the inner project.
  For a manual launch set both the project directory and an absolute log path
  inside `logs/`. Never use the repository root as the Godot project directory.
- Keep generated outputs, engine caches, local secrets and Android signing keys
  out of Git. Preserve import settings, script UIDs, fixtures and approved docs.
- Save APAC, IWG, ENQ, competitor research, spreadsheets and reports for other
  projects outside this repository. If the destination is unclear, ask the user.
- Never read work documents merely to classify their filenames. Never add them
  to this game's Git history.
- Before every commit inspect the complete staged file list and run
  `MergeMutation/tools/check_staged.ps1`. Stage explicit game paths; never use
  `git add .` or automatically include unrelated files.
- Preserve local user changes and saves. Moving this repository or existing work
  documents requires explicit approval and checks for active apps/workspaces.
- Actual repository: ChatGPT/Games/MergeMutation. Relocation is complete.
  Never recreate Plus upgrade or move the repository again without authorization.
- Run checks with the installed Godot 4.7.2. Keep existing gameplay regressions,
  isolate test profiles, and report Windows synthetic touch separately from
  physical Android verification.
- These repository instructions are guidance, not global isolation for other
  Codex projects or a security boundary. Never merge a PR automatically.
