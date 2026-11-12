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
A floating grass island beside the arena at (0, 150, -232), low and close enough that the glass balcony overlooks the arena. It has low glass rails, telescopes aimed at the arena, rainbow paths, a winners podium with light beams (name tags appear only once there is a winner), the gear shop stall (proximity prompt), a top-8 coin leaderboard, and a 12-pad neon obby (+15 coins, 20 s cooldown) with a walkable neon ramp back down from the finish. Falling off returns you to spawn.

Six arenas rotate each round (`Config.World.MapRotation`). Each sets its own lighting preset, sudden-death fluid and knockback multiplier. Every arena is one connected, traversable area (no void between platforms): survivors can always run somewhere, and height is the reward for climbing.

| Arena | Look | Signature destruction | Sudden death |
|---|---|---|---|
| Fracture Bay | Sunny beach | Sand bars connect both shores across the channel; glass resort on exposed pillars pancakes down; suspension bridge; lighthouse; harbor office, beach huts, water tower and lifeguard tower | Water to Y 20 |
| Neo-Shibuya Skyline | Neon night | Four towers on a walkable street grid, each with a long ramp to its roof; glass skybridges link the rooftops; hologram billboards topple; kiosks, cars and vending machines for cover | Toxic smog to Y 16 |
| Magma Core Station | Volcanic | Four rock quadrants split by narrow lava channels, joined by land bridges and a central hub plaza; catwalks on truss supports drop into the lava; volatile silos and barrels chain-explode; smokestacks topple toward the hub; 3-storey refinery; vents burn | Lava to Y 14 |
| Sunscorched Mirage | Desert | Obelisks topple outward onto the wooden scaffold ring; stone aqueducts; stepped pyramid (sturdy high ground); quicksand pits slow and hurt | Sand to Y 12 |
| Outpost Zero | Arctic | Research containers drop when their stilts snap; one large ice shelf with pressure ridges and a ramped comms plateau; breakable edge floes; **2x knockback** on slippery ice | Freezing water to Y 9 |
| Starlight Boardwalk | Sunset carnival | Pier sections fall when pilings break; the Ferris wheel comes off its A-frame and rolls like a wrecking ball; climbable coaster trestles; circus tent | Tide to Y 12 |

**Studio testing:** set the workspace attribute `ForceMap` (for example `"OutpostZero"`) during Play to pin the next map.

### Audio
- **Music** (`Config.Audio.Music`): calm lobby track, tense round track, boss track in sudden death. `AudioController` crossfades between them.
- **Ambience** (`Config.Audio.Ambience` / `AmbienceLayer`): birds in the lobby, plus a per-map bed in the arena (waves, city, lava, wind, desert, carnival), picked from the replicated `MapKey` attribute.
- **Round cues:** countdown ticks with rising pitch in the last 5 s of intermission, tocks before casting opens, ticks in the last 5 s of the round, a round-start hit, a God stinger, a sudden-death alarm, and win/lose stingers.
- **UI** (`UI/Sound.luau`): every Components button, tab and window plays a click, tab or open sound; popups play coin, purchase or error sounds.
- **Disasters** (`AudioService`, server): positional, replicated sounds for telegraphs, lightning and thunder, meteors, tornado loops, gusts, quakes, collapses, glass breaks and explosions.

### Destruction model
Every destructible part has health (from its material), a level, and a support flag, and belongs to a building. Damage breaks parts. When a level loses more than 30% of its supports, every level above is welded into slabs and released, and the remaining supports buckle out from under it. A building with a `FallDirection` tips over in that direction instead of slumping (obelisks, billboards, smokestacks, water towers, the Ferris wheel). Parts tagged as hazards (`HazardDPS` / `HazardWalkSpeed`) hurt or slow anyone standing on them. Debris despawns after ~14 s or when it sinks.

## Economy
- Coins come from surviving (+40, plus 10 per streak round), close calls, obby clears, participation (+10), and as God, eliminations and destruction.
- Coins buy gear. Profiles (coins, streaks, gear, welcome-pack flag, recent receipt IDs) persist through DataStore on live servers; Studio sessions stay in memory.

## Monetization (Robux)
Created through Open Cloud for universe 10776039268. The IDs are in `Config.Monetization`.

**Developer products** (repeatable). `ProcessReceipt` is idempotent: purchase IDs are remembered per profile.

| Product | Price | Grant |
|---|---|---|
| Pouch / Bag / Chest / Vault of Coins | R$25 / 60 / 140 / 349 | +500 / 1,500 / 4,000 / 12,000 coins |
| Be the God Next Round | R$49 | Guaranteed God at the next role draw (God Chance shows 100%) |
| Survival Kit | R$35 | One of each gear item |
| Welcome Pack | R$15 (list R$40) | +1,000 coins + Survival Kit, one-time offer card on the HUD |
| Second Chance | R$19 | Offered for 10 s after elimination; revives you into the live round (+250 coins if the round already ended) |

**Game passes:**

| Pass | Price | Perk |
|---|---|---|
| 2x Coins | R$199 | Doubles all coins earned from play |
| VIP | R$249 | Gold VIP tag, rainbow dash trail, +15 coins every round |
| God Priority | R$299 | God Chance grows twice as fast |
| Quick Dash | R$99 | Dash cooldown halved |

**Where they're sold:** the Shop window has Gear (coins), Coins, Passes and Specials tabs. The sidebar has a Passes shortcut. The whole God Chance card is a tap target for Be the God Next Round, the Welcome Pack card, and the Second Chance button. In Studio, `ServerStorage.DevPurchase` (a BindableFunction) runs the real receipt path for testing. Note that a game's creator owns all its passes, so pass perks are always on for that account.

All numbers live in `src/shared/Config.luau`.
