# Merge Mutation repository

- This repository is exclusively for Merge Mutation. Check the working directory
  and `git rev-parse --show-toplevel` before changing files.
- Godot project: `MergeMutation/`. Store game captures, logs and temporary test
  profiles in `MergeMutation/.godot/`; reviewed documentation belongs in
  `MergeMutation/docs/`. Keep generated Godot caches out of Git.
- Save APAC, IWG, ENQ, competitor research, spreadsheets and reports for other
  projects outside this repository. If the destination is unclear, ask the user.
- Never read work documents merely to classify their filenames. Never add them
  to this game's Git history.
- Before every commit inspect the complete staged file list and run
  `MergeMutation/tools/check_staged.ps1`. Stage explicit game paths; never use
  `git add .` or automatically include unrelated files.
- Preserve local user changes and saves. Moving this repository or existing work
  documents requires explicit approval and checks for active apps/workspaces.
- User-approved relocation after PR19:
  `ChatGPT/Plus upgrade` → `ChatGPT/Games/Merge Mutation`.
  Close/check Godot and GitHub Desktop first. Keep Git history and all files;
  never overwrite an existing destination. Reconnect the Codex project afterward.
- Run checks with the installed Godot 4.7.2. Keep existing gameplay regressions,
  isolate test profiles, and report Windows synthetic touch separately from
  physical Android verification.
- These repository instructions are guidance, not global isolation for other
  Codex projects or a security boundary. Never merge a PR automatically.
