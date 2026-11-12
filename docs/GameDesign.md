# DisasterGod — Game Design

## Premise
DisasterGod is an **asymmetric survival** game, a live twist on classic disaster survival. Instead of a script rolling one passive disaster per round, **one player is the Disaster God**. They hover above a destructible island in a tactical sky camera and spend regenerating **Chaos Energy** to aim disasters, cut buildings in half and flush out campers. Everyone else is a **Survivor**, dodging a live opponent with fast movement and awareness of the map.

With no human God (solo play, or nobody picked), the **Storm Director** AI plays God using the same energy economy.

## Core loop (target: zero downtime)
| Phase | Length | What happens |
|---|---|---|
| Intermission | 12 s | Next map builds in view of the lobby; the **God Chance %** card counts up |
| Prep | first 10 s of the round | Survivors scatter and claim high ground; the God's energy charges and powers are locked |
| Escalation | 10 s – 65 s | The God fires disasters from the hotbar and knocks out supports so buildings collapse |
| Sudden Death | final 20 s | The sea (water/lava) rises to the map's flood line; God energy regen doubles |
| Round End | 8 s | Payout breakdown, podium, everyone back to the Sky Sanctuary |

The round ends early as soon as no survivors are left.

## Roles
### Disaster God
- Orbit camera: WASD to pan, Q/E to rotate, scroll to zoom, right-drag to tilt. A projected reticle follows the mouse; for directional powers it shows the direction.
- Chaos Energy: max 100, regen 7/s, doubled in Sudden Death.
- Hotbar (keys 1-5):

| Ability | Tier | Cost | Cooldown | Telegraph | Effect |
|---|---|---|---|---|---|
| ⚡ Lightning | Minor | 12 | 2.5 s | 1.5 s | Precision strike, heavy damage, small radius |
| 🌬️ Gust | Minor | 10 | 4 s | 1.5 s | Wide knockback along the camera direction; shatters glass and leaves |
| ☄️ Meteors | Major | 40 | 10 s | 2 s | 5 staggered impacts across a 24-stud zone |
| 🌪️ Tornado | Major | 55 | 16 s | 2 s | 8 s funnel that chases the nearest survivor, shreds structures and swirls debris |
| 💥 Fault Cleave | Major | 65 | 18 s | 2.5 s | 100-stud fault line through bedrock that shears every support on the line |

- Anti-camp radar: a survivor who stays within 6 studs for 8 s gets pinged. They're highlighted, a ripple shows their position, and the God is notified.
- Rewards: coins per elimination and per part destroyed.

### Survivors
- **Dash** (Q / button): a short burst with an FOV kick and trail, 2.5 s cooldown.
- **Ledge mantle**: jump in mid-air against a ledge to haul yourself up.
- **Gear** (bought in the Shop, keys 1-3): Speed Soda (sprint), Balloon Glider (low gravity), Shockwave Shield (brief invulnerability that pushes debris away).
- **Close-call rewards**: NEAR MISS +25 when you're just outside a blast; STRUCTURAL ESCAPE +50 when a building collapses with you inside and you live. Each comes with screen shake and a pop-up.

### Eliminated / waiting players
- Respawn straight into the **Sky Sanctuary** lobby.
- **Spectate** opens a free orbit camera over the arena. **Haunt**: click to drop harmless 👻 ghost pings (5 s cooldown).
- Run the neon obby for coins and check the leaderboard.

## God pity (the "one more round" hook)
Each player has a weight: base 1, +1 per round played as a non-God, +0.5 extra for surviving it. The God is drawn by weighted random, and their weight resets to 1. Everyone always sees their current **God Chance %**.

**Solo testing:** with one player, the sidebar shows a **Play God / Survivor** toggle. It works mid-round: swapping to God hands over from the Director; swapping to Survivor drops you into the arena.

## World
### Sky Sanctuary (lobby)
A floating grass island beside the arena at (0, 260, -340). It has a glass observation balcony facing the arena, rainbow paths, a winners podium with light beams, the gear shop stall (proximity prompt), a coin leaderboard, and a 12-pad neon obby (+15 coins, 20 s cooldown). Falling off returns you to spawn.

### Fracture Bay
Two beach land masses split by a water channel and joined by a **suspension bridge** between a rock plateau and a cliff.
- **Glass Resort**: 4 floors on exposed concrete pillars. Take out the pillars and the floors above pancake down.
- **Lighthouse**: stacked segments with a ladder to the balcony. It's the highest ground and a prime lightning target.
- Also: dock with crane, beach café, palms, crates.
- Flood line: Y 20.

### Magma Core Station
Four basalt quadrants over a lava sea.
- **Catwalks** at Y 18 on climbable truss supports link the quadrant pads to the central **radar dome hub**. Snap one support and the whole catwalk drops.
- **Cooling silos** and fuel barrels are volatile: they explode and chain-react.
- Also: crane, twin red lattice towers joined by a sky beam (highest ground), a control block.
- Standing in the lava channels burns. Flood line: Y 14.

### Destruction model
Every destructible part has health (from its material), a level, and a support flag, and belongs to a building. Damage breaks parts. When a level loses more than 30% of its supports, every level above is welded into slabs and released, and the remaining supports buckle out from under it. Debris despawns after ~14 s or when it sinks.

## Economy
- Coins come from surviving (+40, plus 10 per streak round), close calls, obby clears, participation (+10), and as God, eliminations and destruction.
- Coins buy gear. Profiles (coins, streaks, gear) persist through DataStore on live servers; Studio sessions stay in memory.

All numbers live in `src/shared/Config.luau`.
