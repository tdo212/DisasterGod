# DisasterGod — Game Design

## Premise
DisasterGod is an **asymmetric survival** game. Each round, one side wields the disasters and the other side tries to live through them:

- **The Disaster God** — either a chosen player or the game system — triggers environmental hazards (floods, meteors, lightning, collapsing floors, tornadoes…) across the map.
- **Survivors** — everyone else — read warnings, move, climb and hide to evade the hazards until the clock runs out.

Survivors win by being alive at the end of the round. The Disaster God wins by eliminating as many survivors as possible.

## Core loop
1. **Intermission** (short) — players gather, the Disaster God is picked, the map loads.
2. **Active round** (60–90 s) — hazards spawn; eliminated survivors respawn fast as spectators or rejoin next round.
3. **Round end** — podium, rewards, quick results, straight back into intermission.

Target: minimal lobby downtime. A player should spend most of each minute in action, not waiting.

## Pacing
- **Fast start** — the first hazard lands within seconds of the round starting; no slow build-up.
- **Dynamic hazard spawns** — spawn intervals and concurrent hazard counts escalate as the round goes on. Every hazard has a short telegraph (warning time) so deaths feel fair.
- **Resolution** — survivors are ranked for the podium; coins/rewards are paid out immediately, then the next round begins.

## Roles
| Role | Goal |
|---|---|
| DisasterGod | Trigger hazards to eliminate survivors |
| Survivor | Stay alive until the round timer hits zero |
| Spectator | Eliminated or joining mid-round; waits for next round |

## Tuning
All timings and numbers (round lengths, hazard warning/cooldowns, player stats, rewards) are defined in `src/shared/Config.luau`.
