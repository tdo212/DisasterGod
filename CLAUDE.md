# DisasterGod — Project Guidelines

Roblox asymmetric survival game. See [docs/GameDesign.md](docs/GameDesign.md) for the design.

## Luau rules
- Every Luau file starts with `--!strict` on line 1. No exceptions.
- Files use the `.luau` extension. Bootstrap scripts use `.server.luau` / `.client.luau`; everything else is a ModuleScript.

## Dual-Sync Workflow (mandatory)
Every code change is applied in **both** places:
1. Written to disk under `src/`.
2. Updated in the live Studio DataModel via Roblox Studio MCP (`execute_luau` setting `.Source`, or `multi_edit`).

Disk is the source of truth for git; Studio must never drift from it. If they disagree, the disk version wins and is re-synced to Studio.

## DataModel mapping
| Disk | DataModel |
|---|---|
| `src/shared/` | `ReplicatedStorage.Shared` |
| `src/server/Services/` | `ServerScriptService.Server.Services` |
| `src/server/Main.server.luau` | `ServerScriptService.Server.Main` (Script) |
| `src/client/Controllers/` | `StarterPlayer.StarterPlayerScripts.Controllers` |
| `src/client/Main.client.luau` | `StarterPlayer.StarterPlayerScripts.ClientMain` (LocalScript) |

Instance names equal the file name without extension/suffix (e.g. `MatchService.luau` → `MatchService`).

## Configuration
- All numeric gameplay constants — match/round timers, disaster timings, spawn intervals, player stats, rewards — live in `src/shared/Config.luau`. No magic numbers in services or controllers.
- Shared types live in `src/shared/Types.luau`.

## UI
- UI code lives under `src/client/` (controllers build or drive UI).
- Use the shared design tokens (colors, fonts, sizes, corner radius) instead of ad-hoc values, and `TweenService` with consistent `TweenInfo` presets for transitions.

## Pre-push validation
1. Run Play Solo in Studio and confirm **zero errors** in Output (`get_console_output`).
2. Review `git status` and `git diff`; make sure no place files, secrets, or local config are staged.
3. Commit with [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `chore:`, `refactor:`, `docs:` …).
