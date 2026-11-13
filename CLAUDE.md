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

Sync notes:
- Studio's Assistant HTTP allowlist blocks localhost, so sources can't be pulled over HTTP. Push whole files inline with `execute_luau` (long-bracket `[==[ ... ]==]` strings) or apply the same exact replacements with `multi_edit`.
- Verify after every sync: `python tools/checksum.py` prints byte length + checksum per file; compute the same checksum on each script's `.Source` in Studio (`sum = (sum + byte_i * ((i-1) % 251 + 1)) % 2147483647`) and compare. `.gitattributes` keeps files LF so the numbers match.

## DataModel mapping
| Disk | DataModel |
|---|---|
| `src/shared/` | `ReplicatedStorage.Shared` |
| `src/server/Main.server.luau` | `ServerScriptService.Server.Main` (Script) |
| `src/server/Services/` | `ServerScriptService.Server.Services` |
| `src/server/World/` | `ServerScriptService.Server.World` (procedural map / lobby builders) |
| `src/client/Main.client.luau` | `StarterPlayer.StarterPlayerScripts.ClientMain` (LocalScript) |
| `src/client/Controllers/` | `StarterPlayer.StarterPlayerScripts.Controllers` |
| `src/client/UI/` | `StarterPlayer.StarterPlayerScripts.UI` (Theme tokens + Components) |
| `src/client/Util/` | `StarterPlayer.StarterPlayerScripts.Util` |

Instance names equal the file name without extension/suffix (e.g. `MatchService.luau` → `MatchService`).

## World
- Maps and the lobby are built **from code at runtime** (`src/server/World/*`), so geometry is version-controlled. Don't hand-build arena geometry in Studio; change the builders.
- The one exception to code-built geometry is `Workspace.TimePlayedLeaderboard` (a third-party board model): it must stay in Workspace, and `LeaderboardService` clones it for the other lobby boards at runtime.
- Destructible parts are marked with `Builder.structural(part, level, isSupport)`. A level collapses when its intact supports fall below `Config.Destruction.CollapseSupportFraction`.

## Configuration
- All numeric gameplay constants — match/round timers, disaster timings, spawn intervals, player stats, rewards — live in `src/shared/Config.luau`. No magic numbers in services or controllers.
- Shared types live in `src/shared/Types.luau`.

## Monetization
- Developer product and game pass IDs live in `Config.Monetization` (Products / Passes). Grants live in `MonetizationService`; every product grant must be idempotent (receipt IDs are stored per profile).
- Never commit Open Cloud API keys or other credentials. Create new items through the Studio MCP `open_cloud_invoke` tool once its scopes are granted, or with a key held only outside the repo.
- Test grants in Play Solo with `ServerStorage.DevPurchase:Invoke(userId, "Product" | "Pass", key)` (Studio only). It also grants placeholder products (Id 0).
- New products start with `Id = 0` (placeholder): the shop shows SOON and receipts never match them until the real id is filled in. Cosmetic and panic-save products are wired from their `Cosmetic` / `Save` fields; no per-product grant code needed.

## UI
- UI code lives under `src/client/` (controllers build or drive UI).
- Use the shared design tokens in `src/client/UI/Theme.luau` (colors, font, radii, strokes, `TweenInfo` presets) and the builders in `UI/Components.luau` (label, button, panel, window, tile) instead of ad-hoc values.
- Set `UIListLayout.SortOrder = LayoutOrder` explicitly; the default sorts by name.
- Each controller's ScreenGui gets `layer = Components.scaledRoot(gui)`; parent all content to `layer` (not `gui`) so the UI scales with the viewport.
- Surfaces use the stud texture and lipped gradient from Components (`studs`, `gradient(..., lip)`); branch layout on `Components.isTouch()` for phones. Set the workspace attribute `ForceTouchUI = true` in Studio to preview the touch layout.

## Audio
- All sound IDs and volumes live in `Config.Audio`. World/disaster sounds go through `AudioService` (server, positional); UI sounds through `UI/Sound.luau`; music and ambience through `AudioController`.

## Pre-push validation
1. Run Play Solo in Studio and confirm **zero errors** in Output (`get_console_output`).
2. Review `git status` and `git diff`; make sure no place files, secrets, or local config are staged.
3. Commit with [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `chore:`, `refactor:`, `docs:` …).
