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
| Round End | 8 s | Payout breakdown, podium, everyone back to the Sky Lodge |

The round ends early as soon as no survivors are left.

## Roles
### Disaster God
- Orbit camera: WASD to pan, Q/E to rotate, scroll to zoom, right-drag to tilt. A projected reticle follows the mouse; for directional powers it shows the direction.
- Chaos Energy: max 100, regen 8/s, doubled in Sudden Death.
- Hotbar (keys 1-5):

| Ability | Tier | Cost | Cooldown | Telegraph | Effect |
|---|---|---|---|---|---|
| ⚡ Lightning | Minor | 12 | 2.5 s | 1.5 s | Precision strike, heavy damage, small radius |
| 🌬️ Gust | Minor | 10 | 4 s | 1.5 s | Wide knockback along the camera direction; shatters glass and leaves |
| ☄️ Meteors | Major | 40 | 10 s | 2 s | 6 staggered impacts across a 28-stud zone |
| 🌪️ Tornado | Major | 55 | 16 s | 2 s | 8 s funnel that chases the nearest survivor, shreds structures and swirls debris |
| 💥 Fault Cleave | Major | 65 | 18 s | 2.5 s | 120-stud, 10-wide fault line through bedrock that shears every support on the line |

- Ability areas and structure damage are tuned for the bigger, more numerous buildings (about +15-25% over launch), while player damage is unchanged so survivors aren't hit harder. Destructible parts per map rose from 182-589 to 330-789 (Fracture Bay 393 to 623); in testing a Meteor plus a Lightning knocked a quarter of the parts off the 4-storey Bay Hotel.
- Anti-camp radar (outdoors only): a survivor who stays within 6 studs for 8 s in the open gets pinged. They're highlighted, a ripple shows their position, and the God is notified. Survivors hiding indoors or inside a jammed zone are exempt.
- 📡 **Seismic Ping** (every kit, slot 6 / key 6; a separate round radar button offset from the five disasters on phones): 15 energy, 14 s cooldown. After a 0.5 s ring, every survivor within 70 studs who isn't in a jammed zone glows through walls for 2 s, and they get a "PINGED" warning.
- Rewards: coins per elimination and per part destroyed.

### Survivors
- **Dash** (Q / button): a short burst with an FOV kick and trail, 2.5 s cooldown.
- **Ledge mantle**: jump in mid-air against a ledge to haul yourself up.
- **Gear** (bought in the Shop, keys 1-3): Speed Soda (sprint), Balloon Glider (low gravity), Shockwave Shield (brief invulnerability that pushes debris away).
- **Close-call rewards**: NEAR MISS +25 when you're just outside a blast; STRUCTURAL ESCAPE +50 when a building collapses with you inside and you live. Each comes with screen shake and a pop-up.

### Hide and seek (`Config.Stealth`, StealthService / StealthController)
- The God sees every survivor's name tag through walls, except survivors who are **Hidden**: standing still for 1 s under an intact roof (any structural part within 45 studs overhead), or standing in a jammed zone. A HIDDEN badge shows when you are. When the God breaks the roof above you, you lose cover.
- **Noise:** jumping, dashing, using gear, flipping a breaker, riding a launch pad, or standing within 10 studs of a window that shatters sends a ripple only the God sees, and resets your hiding.

### Map props (`World/Props.luau`, PropService)
Every arena has, on scanned free ground away from spawns and hazards:
- **2 circuit breakers:** hold for 1.2 s to jam the God's radar for 12 s within 30 studs (everyone inside is hidden and immune to the Seismic Ping and anti-camp radar). 35 s recharge; flipping one is loud.
- **3 launch pads:** two on the ground and one on the roof of the map's tallest new building (it falls with that roof). Each flings you about 25 studs up and toward the middle of the map.
- **1 vault:** a reinforced bunker whose parts have 450 health, enough to take one Meteor or Lightning hit before caving in on the second. Its roof also makes it a hiding spot.

### Disaster combos (`Config.Combos`, ComboService)
- **Conduction:** Lightning and Chain Bolt arc into intact metal structure within 1.6x the strike radius (up to 8 parts) and shock survivors within 7 studs of a charged part (25 damage). A strike at the rising water line shocks swimmers within 45 studs (30 damage), and a strike into a puddle shocks everyone standing in it.
- **Firenado:** a Tornado that touches fire (an Eruption pool or a burning patch) turns into a firenado and drops 6-stud burning patches every 0.5 s for its remaining life.
- **Puddles:** a toppled water tower or pipe gantry floods a 16-stud puddle for 14 s. Puddles put out fires and lava pools, conduct lightning, and make knockback 1.6x stronger.

### Eliminated / waiting players
- Respawn straight into the **Sky Lodge** lobby (watch from the observation deck).
- **Spectate** opens a free orbit camera over the arena. **Haunt**: click to drop harmless 👻 ghost pings (5 s cooldown).
- Run the Neon Climb obby for coins and check the leaderboards and Hall of Legends.

## God pity (the "one more round" hook)
Each player has a weight: base 1, +1 per round played as a non-God, +0.5 extra for surviving it. The God is drawn by weighted random, and their weight resets to 1. Everyone always sees their current **God Chance %**.

**Solo testing:** with one player, the sidebar shows a **Play God / Survivor** toggle. It works mid-round: swapping to God hands over from the Director; swapping to Survivor drops you into the arena.

## World
### Sky Lodge (lobby)
A big timber great hall floating beside the arena at (0, 150, -232), built to feel wide, warm and calm: 160 x 120 studs inside, a 34-stud beamed ceiling under a pitched roof, tall side windows, candle chandeliers, a red runner rug and potted plants. It is enclosed, so nobody falls out.
- **Hall of Legends** (back wall, centre): a gold/silver/bronze podium where the all-time top three for `Config.Leaderboards.Hall` (rounds survived) stand as statues of their real avatars, with name and record above. Empty spots read "Your name here?". It refreshes with the leaderboards. There is no per-round winners podium in the lodge any more; the round summary still shows the round's top three.
- **Leaderboards:** four boards along the back wall, two either side of the Hall of Legends.
- **Centre:** spawn pad on the runner, daily quest board and prize wheel either side, the four game pass pedestals, and three map vote pads by the deck doorway.
- **West:** the gear shop stall and a fireside lounge (hearth, sofas, rug).
- **East: Neon Climb obby.** 11 evenly spaced pads (8 studs apart, 1.5 studs higher each, alternating 2 studs left/right) on glowing stems up the east wall to a loft in the front corner (+15 coins, 20 s cooldown), with a neon ramp back down. A glass divider separates the course from the ramp and the hall so it can't be skipped; falling lands you on the lodge floor next to the start.
- **Observation deck:** past the wide front opening, 112 x 34 studs with a glass-floor strip at the edge, a low glass rail with no neon on the front (so nothing glares across the view), invisible walls above the rails, and the telescopes and benches kept to the sides so the middle stays clear for looking down on the arena.

Six arenas (`Config.World.MapRotation`). Each intermission opens with a **map vote**: three candidates appear on the lobby pads, a player's vote is the last pad they stood on, and the winner is built for the rest of the countdown (ties and empty votes pick at random; each vote is logged as a `MapVote` analytics event). Each sets its own lighting preset, sudden-death fluid and knockback multiplier. Every arena is one connected, traversable area (no void between platforms): survivors can always run somewhere, and height is the reward for climbing.

| Arena | Look | Signature destruction | Sudden death |
|---|---|---|---|
| Fracture Bay | Sunny beach | Sand bars connect both shores across the channel; glass resort on exposed pillars pancakes down; suspension bridge; lighthouse; 4-storey bay hotel on the sand bar, surf club, fish market, cliff-top villa, 4-storey harbor office, 3-storey cafe, beach huts, water tower and lifeguard tower | Water to Y 20 |
| Neo-Shibuya Skyline | Neon night | Four towers on a walkable street grid, each with a long ramp to its roof; glass skybridges link the rooftops; hologram billboards topple; four 4-storey destructible neon shophouses on the outer streets (the towers themselves are solid); kiosks, cars and vending machines for cover | Toxic smog to Y 16 |
| Magma Core Station | Volcanic | Four rock quadrants split by narrow lava channels, joined by land bridges and a central hub plaza; catwalks on truss supports drop into the lava; volatile silos and barrels chain-explode; smokestacks topple toward the hub; 3-storey refinery; 3-storey control block, 4-storey refinery, forge hall, pump station, 4-storey assay lab and ore depot; vents burn | Lava to Y 14 |
| Sunscorched Mirage | Desert | Obelisks topple outward onto the wooden scaffold ring; stone aqueducts; stepped pyramid (sturdy high ground); sandstone bazaar buildings (2-3 storeys) in the courtyard corners; quicksand pits slow and hurt | Sand to Y 12 |
| Outpost Zero | Arctic | Research containers drop when their stilts snap; one large ice shelf with pressure ridges and a ramped comms plateau; bunkhouse, hangar, 3-storey drill hall and cold store; breakable edge floes; **2x knockback** on slippery ice | Freezing water to Y 9 |
| Starlight Boardwalk | Sunset carnival | Pier sections fall when pilings break; the Ferris wheel comes off its A-frame and rolls like a wrecking ball (the pier sections under its feet stand on unbreakable concrete footings so it always rolls instead of sinking); climbable coaster trestles; circus tent; four 2-3 storey pavilions on their own piles, so they stay up when the pier around them breaks | Tide to Y 12 |

**Studio testing:** set the workspace attribute `ForceMap` (for example `"OutpostZero"`) during Play to pin the next map (this also skips the vote). Set `ForceTouchUI = true` before Play to preview the touch layout with a mouse.

### Audio
- **Music** (`Config.Audio.Music`): calm lobby track, tense round track, boss track in sudden death. `AudioController` crossfades between them.
- **Ambience** (`Config.Audio.Ambience` / `AmbienceLayer`): birds in the lobby, plus a per-map bed in the arena (waves, city, lava, wind, desert, carnival), picked from the replicated `MapKey` attribute.
- **Round cues:** countdown ticks with rising pitch in the last 5 s of intermission, tocks before casting opens, ticks in the last 5 s of the round, a round-start hit, a God stinger, a sudden-death alarm, and win/lose stingers.
- **UI** (`UI/Sound.luau`): every Components button, tab and window plays a click, tab or open sound; popups play coin, purchase or error sounds.
- **Disasters** (`AudioService`, server): positional, replicated sounds for telegraphs, lightning and thunder, meteors, tornado loops, gusts, quakes, collapses, glass breaks and explosions.

### Destruction model
Every destructible part has health (from its material), a level, and a support flag, and belongs to a building. Damage breaks parts. When a level loses more than 30% of its supports, every level above is welded into slabs and released, and the remaining supports buckle out from under it. A building with a `FallDirection` tips over in that direction instead of slumping (obelisks, billboards, smokestacks, water towers, the Ferris wheel). Parts tagged as hazards (`HazardDPS` / `HazardWalkSpeed`) hurt or slow anyone standing on them. Debris stays solid for ~9-12 s, then stops colliding with players, shrinks and fades (so rubble can't trap anyone and late-round frame rate holds), or is removed when it sinks. A damaged building that is still standing groans as a warning.

**Performance (`Config.Debris`).** Floors, supports and collapsing slabs stay server-simulated so collisions are fair. Small non-load-bearing pieces (up to 60 cubic studs, plus all glass, neon, fabric and leaves) are removed on the server when they break and sent, batched once per frame, to every client, which simulates them locally as rubble that never touches characters (`DebrisController`): up to 220 pieces for 7 s on desktop, 80 pieces for 4.5 s on phones. Server debris that has rested for 2 s is anchored with touch and query off so the solver stops working on rubble piles (the tornado wakes pieces it picks up). On touch devices, particle emitters run at half rate and 60% lifetime, trails at half length, fire at 70% size, and debris casts no shadows.

## Game feel
- **Camera shake and impact punch:** every disaster shakes nearby cameras; building collapses shake in proportion to their size, and heavy hits add a short field-of-view punch.
- **Ragdolls:** knockback of `Config.Ragdoll.MinKnockback` or more (gusts, tornadoes, fault lines, explosions) sends a survivor tumbling for 1.6 s before they stand back up. Dead characters stay in one piece as ragdolls.
- **Audio cues:** each disaster has its own telegraph sound (`Config.Audio.AbilityCue`), and an air raid siren loops through Sudden Death.
- **Hunter's Pulse:** in the last 20 s, if exactly one survivor is left and a human is God, that survivor is highlighted every 4 s so the round ends in a chase.

## Showdowns, taunts and the kill feed
- **Last Stand** (`Config.Showdown`, ShowdownService): when a round that had 2+ survivors is down to one with at least 15 s left, everyone gets a LAST STAND banner and feed line, a heartbeat loops and the music switches to the boss track. The God sees a 40-stud zone around the survivor (offset up to 22 studs, refreshed every 5 s), and the survivor's dash recharges twice as fast and near misses pay double.
- **Daredevil taunts** (`Config.Emotes`, EmoteService / EmoteController): a 😜 button above DASH (T on keyboard) opens Wave, Whistle, Scream and Dance (8 s cooldown, a bubble over your head, and noise). Emoting while HIDDEN is a Daredevil taunt: the God sees your silhouette for 1.5 s and gets a callout, and every coin you earn for 10 s is multiplied by 1.5. The button turns 😈 while you're hidden.
- **Kill feed** (`Config.Feed`, FeedController): eliminations name what got you. "Flattened by Bay Hotel" if a building collapsed on you in the last 4 s, otherwise the last hit within 6 s ("was crushed by Meteors", "was electrocuted", "was swallowed by the rising lava", "fell into the void"...). Clutch callouts: "escaped Meteors by 2 studs!" for near misses within 3 studs, and "escaped the collapsing Fish Market!".
- **Final kill:** the round's last elimination is posted as FINAL KILL, and every camera glides in on it with a desaturated grade and narrowed FOV for 2.4 s before everyone returns to the lodge.

## God kits
The God's five-slot hotbar comes from the equipped kit (`Config.Kits`). Kits are bought with coins in the Shop's God Kits tab and can be swapped any time.

| Kit | Price | Abilities |
|---|---|---|
| The Architect | free | Lightning, Gust, Meteors, Tornado, Fault Cleave |
| Storm Deity | 1,500 | Lightning, Chain Bolt, Gust, Tornado, Meteors |
| Magma Titan | 2,500 | Eruption, Meteors, Fault Cleave, Lightning, Gust |
| Cyber Glitch | 4,000 | Glitch, Chain Bolt, Lightning, Tornado, Fault Cleave |

Chain Bolt hops between the nearest survivors, Eruption leaves a burning lava pool, and Glitch flings survivors straight up. The server refuses any ability that is not in the caster's kit. The AI Director uses all eight.

## Daily quests
Three quests a day, the same for everyone: two drawn from `Config.Quests.Pool` plus "survive a round on the map of the day" (which gives the map vote a purpose). Claiming pays coins; claiming all three grants a wheel spin and extends a daily streak. Open them from the Quests tile or the lobby quest board.

## Prize wheel
Players bank spins: one to start, a free one every 10 minutes (5 for VIP, banking stops at 3), one for finishing the daily quests, and Robux packs of 1 or 10. The server rolls the weighted reward and the wheel shows the real odds on every segment.

| Reward | Odds |
|---|---|
| God next round | 8% |
| 1,500 coins | 12% |
| 400 coins | 25% |
| Survival Kit | 20% |
| 150 coins | 35% |

## Leaderboards
The lobby boards are built from the `TimePlayedLeaderboard` model in Workspace (RenanMSV's board). That model keeps its own script and stays the Time Played board. `LeaderboardService` clones it for Top Survivors (rounds survived), Deadliest Gods (eliminations) and Longest Streaks, removes the script from each clone and fills them itself from ordered data stores on live servers. In Studio they show the players in the server instead. The model must stay in Workspace; without it the extra boards are skipped with a warning.

## Onboarding
The first time a player is the God, and the first time they are a survivor, a three-bullet role card appears once the round-start banner clears (with touch wording on phones). The Welcome Pack offer is hidden until the player has finished one round.

## Mobile
The UI is authored against a smaller canvas on touch devices so everything is larger, the menu sits top-left and the wallet top-right to keep the thumbstick clear, and the dash button sits beside the jump button at the same size. As God, drag pans the camera, pinch zooms, a two-finger twist rotates, the reticle stays at screen centre with a CAST button, and tapping the arena casts at the tap.

Every control hint matches the device: role cards, the God and spectate hints, the dash button (`DASH` vs `DASH [Q]`), gear hotbar keys (hidden on touch) and the shop's gear text. Server banners write `{tap}` / `{Tap}` / `{TAP}` and the client swaps in tap or click (`Components.inputText`).

## Economy
- Coins come from surviving (+40, plus 10 per streak round), close calls, obby clears, participation (+10), and as God, eliminations and destruction.
- Coins buy gear and God kits. Profiles (coins, streaks, gear, welcome-pack flag, recent receipt IDs) persist through DataStore on live servers; Studio sessions stay in memory.

## Cosmetics (`Config.Cosmetics`, CosmeticService / CosmeticController)
Each category has a free starter, a coin item and Robux items. Bought or equipped in the Shop's Style tab; owned and equipped items persist in the profile.

| Category | Free | Coins | Robux |
|---|---|---|---|
| God Skin: a giant avatar hovering 70 studs over the God's reticle for everyone (the God sees their own at 80% transparency) | 👁️ Storm Eye | ✊ Stone Fist (3,000) | 🔥 Magma Claw, 🤖 Cyber Gauntlet, 🌟 Celestial Mask |
| Disaster FX: recolours the God's bolts, telegraphs, meteors, tornado and lava | ⚡ Classic | ✨ Golden Wrath (2,500) | 🟣 Neon Void, 👾 Pixel Chaos (voxel meteors) |
| Finisher: plays where you're eliminated | 💨 Poof | 👻 Ghost Rise (2,000) | 🎉 Confetti Pop, 🌀 Cartoon Boing (boing + the body floats off) |

Small statues of all five God skins stand on pedestals either side of the lodge spawn; their prompt opens the Style tab. Skins are part-built models in `src/shared/GodSkins.luau`. The God's client sends its reticle about 6 times a second (`GodAim`).

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
| 1 Wheel Spin / 10 Wheel Spins | R$34 / 149 | +1 / +10 prize wheel spins |
| 🪂 Emergency Glider | R$9 | One charge. Fires automatically when you're about to fall into the void or sink in the rising fluid: launches you up toward the middle of the map on a 4 s slow glide |
| 🛡️ Aegis Bubble | R$15 | One charge. Fires automatically on a disaster hit that would kill you: you keep 30 HP inside a 2.5 s force field |
| God Skins: Magma Claw / Cyber Gauntlet / Celestial Mask | R$149 / 149 / 199 | Permanent cosmetic (see Cosmetics) |
| Disaster FX: Neon Void / Pixel Chaos | R$99 / 129 | Permanent cosmetic |
| Finishers: Confetti Pop / Cartoon Boing | R$99 / 99 | Permanent cosmetic |

The products added in the cat-and-mouse update still have **placeholder ids (0)** in `Config.Monetization.Products`: their shop buttons read SOON and `ProcessReceipt` never matches them until the real ids are pasted in. `DevPurchase` grants them in Studio regardless.

**Panic saves instead of mid-danger prompts:** a purchase prompt that opens while you're falling arrives too late and feels predatory, so saves are bought ahead (Specials tab) and fire on their own. After a death a save would have prevented (void or fluid for the Glider, a disaster hit for the Aegis), a one-tap "this would have saved you" card appears for 8 s if you have none. Owned charges show above the gear bar during rounds.

**Game passes:**

| Pass | Price | Perk |
|---|---|---|
| 2x Coins | R$199 | Doubles all coins earned from play |
| VIP | R$249 | Gold VIP tag, rainbow dash trail, +15 coins every round |
| God Priority | R$299 | God Chance grows twice as fast |
| Quick Dash | R$99 | Dash cooldown halved |

**Where they're sold:** the Shop window has Gear (coins), God Kits (coins), Style (cosmetics), Coins, Passes and Specials tabs; each page scrolls sideways when the cards don't fit. The menu has a Passes shortcut, and each pass has a glowing pedestal in the middle of the lodge that previews it in 3D and prompts the purchase. The prize wheel window sells the spin packs. The whole God Chance card is a tap target for Be the God Next Round, the Welcome Pack card, and the Second Chance button. In Studio, `ServerStorage.DevPurchase` (a BindableFunction) runs the real receipt path for testing. Note that a game's creator owns all its passes, so pass perks are always on for that account.

All numbers live in `src/shared/Config.luau`.
