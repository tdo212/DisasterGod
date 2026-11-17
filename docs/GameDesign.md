# DisasterGod — Game Design

## Premise
DisasterGod is an **asymmetric survival** game, a live twist on classic disaster survival. Instead of a script rolling one passive disaster per round, **one player is the Disaster God**. They hover above a destructible island in a tactical sky camera and spend regenerating **Chaos Energy** to aim disasters, cut buildings in half and flush out campers. Everyone else is a **Survivor**, dodging a live opponent with fast movement and awareness of the map.

With no human God (solo play, or nobody picked), the **Storm Director** AI plays God using the same energy economy.

## Core loop (target: zero downtime)
| Phase | Length | What happens |
|---|---|---|
| Intermission | 30 s | A 10 s **lobby break** (shop, spin, explore), the 9 s map vote, then the winner builds in view of the lobby while the **God Chance %** card counts up |
| Prep | first 10 s of the round | Survivors scatter and claim high ground; the God's energy charges and powers are locked |
| Escalation | 10 s – 65 s | The God fires disasters from the hotbar and knocks out supports so buildings collapse |
| Sudden Death | final 20 s | **God Overdrive**: air raid siren, darker mood, sudden-death music, God energy regen doubles, the Rising Tide surges to its peak and telegraphs get shorter |
| Round End | 9 s | Payout breakdown, podium, everyone back to the Sky Lodge |

The round ends early as soon as no survivors are left.

**Final Rush** (`Config.Match.FinalRushShare` / `FinalRushLead`): once only a quarter of the round's survivors are left (at least 1, in rounds that started with 2 or more), the clock jumps so sudden death starts in 10 seconds, with a "FINAL RUSH!" banner. The last survivors get a tense finale and the eliminated wait seconds, not a minute, for the next round. The Waiting card counts down to the next round.

**Round start: GOD vs SURVIVORS** (RoleRevealController, every round, for everyone): a card slams in over the fly-by. Portraits flick through every player like a roulette and land on the God (purple side, horns), a big VS hits, then the survivors' faces pop in on the green side. Your own face gets a gold ring and a YOU chip. Banners and the tutorial wait until it lifts away. It replaces the old "SURVIVE!" banner.

**Balance** (`Config.Balance`): the God should catch some or most survivors, not always all of them, and abilities improve a survivor's odds.
- Any two casts are at least 0.6 s apart (cooldowns stay per ability), and no single disaster hit does more than 48 damage (Lightning 42 = three hits, Meteors 40). Rising fluid and the void still kill.
- The God's Chaos Energy regen falls as survivors are eliminated, down to 55% with one survivor left of many.
- With 2 or fewer survivors left (of 3+), they take 80% of disaster damage.
- Survivors heal 4 HP/s after 5 s without taking damage.

## Roles
### Disaster God
- Orbit camera: WASD to pan, Q/E to rotate, scroll to zoom, right-drag to tilt. A projected reticle follows the mouse; for directional powers it shows the direction.
- Chaos Energy: max 100, regen 8/s, doubled in Sudden Death (God Overdrive). The doubling stacks with the alive-share slowdown (regen falls toward 0.55x as survivors thin out), so with 1-3 of 7 survivors left the God earns energy only 1.1-1.4x as fast as at the start, not 2x. Grit (survivors take 0.8x damage at 2 or fewer), the 0.6 s cast gap and the 48 damage cap still apply.
- **Rising Tide** (`Config.Tide`, MatchService / MapService): 40 s into every round the map's sea starts rising from below the ground. It is toxic green floodwater on water maps (a glowing sheet rides its surface, with a low rumble), magma on lava maps, and walled arenas keep their own fluid. It reaches 2 studs over the streets by sudden death, then surges to a peak worked out per arena when the map is built: 35% of the way from the ground (the floor under the spawns) to the tallest destructible structure, but never above the median structure top (half of what stands stays dry), and 6 to 24 studs deep. Big building / floor collapses push it up 1.2 studs (at most every 2.5 s, never past the peak). 5 s before it floods the ground, survivors get a screen-edge warning in its colour ("⚠️ FLOOD RISING — GET TO HIGH GROUND!", "MAGMA RISING" on lava maps). Standing in it costs 30 HP/s with a hit flash and an upward splash every 0.8 s, so a jump, a dash, a glider or a shield can still save you. Flash Flood starts it right after prep, 5 studs deep before sudden death and 4 studs over the peak.
- **Snappier telegraphs** (`Config.Balance`): precision strikes (Lightning, Meteors, Chain Bolt, Meteor Barrage) warn for 0.75x as long, every other disaster 0.85x, and both another 0.8x in sudden death.
- **Area denial** (`Config.Lingering`, ComboService): every meteor impact leaves a burning crater for 6 s, a lightning strike leaves the ground (or the whole puddle under it) live for 4 s, and a Gust drags survivors in toward its centre during its warning before it blasts them out. Bots take all of it too.
- **Aim assist** (`Config.GodAim`, GodController): the God's reticle (or a tap on touch) snaps 60% of the way onto a survivor or bot within 9 studs and outlines them in gold. Hidden survivors are never snapped to.
- **Elemental Combo** (`Config.GodCombo.ElementalWindow`): the first time in a round a God casts two different disasters within 6 s, they get +15 Chaos Energy and an "ELEMENTAL COMBO!" popup.
- Hotbar (keys 1-5):

| Ability | Tier | Cost | Cooldown | Telegraph | Effect |
|---|---|---|---|---|---|
| ⚡ Lightning | Minor | 12 | 3 s | 1.5 s | Precision strike, heavy damage, small radius |
| 🌬️ Gust | Minor | 10 | 4 s | 1.5 s | Wide knockback along the camera direction; shatters glass, leaves and thin walls |
| ☄️ Meteors | Major | 40 | 10 s | 2 s | 6 staggered impacts across a 28-stud zone |
| 🌪️ Tornado | Major | 50 | 15 s | 2 s | 9 s, 20-stud funnel that chases the nearest survivor, tears through the ground floor and the floor above (170 structure/s), flings survivors and swirls debris |
| 💥 Fault Cleave | Major | 65 | 18 s | 2.5 s | 120-stud, 10-wide fault line through bedrock that shears every support on the line |

- **Balance pass (Nov 2026):** the Tornado was the weakest Major (90 structure/s at ground level only, so it rarely dropped a building) and is now a real building-shredder; Maelstrom Vortex matches it. The strongest picks were trimmed: Tectonic Spire 420 → 320 structure damage and 13 → 15 s, Meteor Barrage 11 → 13 s and 35 → 30 player damage, Chain Arc 9 → 10 s, Glitch 6 → 7 s, Lightning 2.5 → 3 s (it was spammable). Gust now breaks thin walls (45 → 70 structure).
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
- The God sees every survivor's name tag through walls, except survivors who are **Hidden**: standing still for 1 s under an intact roof (any structural part within 45 studs overhead, but not see-through glass canopies like the domes and the casino skylight), or standing in a jammed zone. A HIDDEN badge shows when you are. When the God breaks the roof above you, you lose cover.
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
- **Waiting card** (SpectateController): while a round runs without you, a card at the bottom says ELIMINATED or ROUND IN PROGRESS, when the next round starts, with SPECTATE and SHOP buttons. A player who joins mid-round drops into spectate on their own after 4 s.
- **Spectate** (`Config.Spectate`) follows one player at a time: ◀ / ▶ (A / D or the arrow keys on PC) cycle through the God and every living survivor, AI survivor bots included, and the view moves on by itself a moment after the one you watch goes down. One bar at the bottom shows who you're watching (THE GOD / SURVIVOR, 2 / 6), the next-round timer, FREE CAM and LODGE. **Free cam** flies the orbit camera over the arena for ghost bolts. **Ghost bolts** (`Config.Ghost`): click the arena to drop a small purple bolt after a 1.2 s telegraph. It zaps survivors in a 6-stud radius for 8 damage and pays the ghost 6 coins per survivor hit; it never credits a kill or breaks buildings. 8 s cooldown per ghost (shown on the spectate hint), and at most one ghost bolt every 1.2 s across the server so a crowd of ghosts can't swarm; when the arena is busy the click drops the old harmless 👻 ping instead. Being eliminated is no longer just waiting.
- Run the Neon Climb obby for coins and check the leaderboards and Hall of Legends.

## God pity (the "one more round" hook)
Each player has a weight: base 1, +1 per round played as a non-God, +0.5 extra for surviving it. The God is drawn by weighted random, and their weight resets to 1. Everyone always sees their current **God Chance %**.

**New-player God priority** (`Config.Pity.NewPlayerRounds` / `NewPlayerMultiplier`): a player with fewer than 3 rounds played who has never been the God (`GodRounds` on the profile) has their weight multiplied by 6 (+500%), so new players reliably get a God round in their first two or three rounds.

**Solo testing:** with one player, the sidebar's **Play God** tile is a God / Survivor toggle (with other players it opens the Specials tab with the God pass and God Chance). It works mid-round: swapping to God hands over from the Director; swapping to Survivor drops you into the arena.

## Low-population servers (`Config.LowPop`, BotService)
Ad traffic often lands in a server alone. With 1-3 real players:
- **AI survivor bots**: each round spawns 4-6 bots (`7 - real players`, clamped) into the arena. They are classic blocky avatars with player-style names. They wander between safe goals (no walking off edges; `BotMaxDrop`, `BotEdgeShare`), dash and jump away from disasters that land near them, and yell when hit. Disasters hurt them through `BotService.HitSphere` / `HitBox` next to each survivor check, and the Director aims at them too. A bot the God takes out pays the usual elimination coins, counts toward kills, quests and the kill confirm, and posts a kill-feed line. It does not count toward the lifetime "Deadliest Gods" stat. The God sees bots' through-wall name tags like real survivors, and the role reveal and God intro include them. Bots are removed at round end, and mid-round once a fourth real player joins. A round ends early when the God wipes out every bot.
- **Free first round as the God**: a player who has never played a round, and hasn't picked a role with the solo toggle, is the God in their first round (banner "FREE ROUND: YOU ARE THE GOD!"). They play against the bots, so the first 30 seconds are smashing a scattering crowd.
- **2X coins**: round payouts get a "Low-pop bonus" line (`CoinMultiplier`, x2), and a pill under the round bar says so: "🔥 2X COINS ACTIVE · Low-Pop Bonus! Waiting for more challengers…".

## World
### Sky Lodge (lobby)
A big timber great hall floating beside the arena at (0, 150, -232), built to feel wide, warm and calm: 160 x 120 studs inside, a 34-stud beamed ceiling under a pitched roof, tall side windows, candle chandeliers, a red runner rug and potted plants. It is enclosed, so nobody falls out.
- **Architecture** (`World/LodgeProps.luau`): roof trusses (lower chords, 45° knee braces, iron brackets, bolts and straps), stone-and-wood wainscot (baseboard, framed raised panels, cap rail), pointed-arch side windows with mullions, transoms, keystones and stone sills, heraldic shields on the wall posts and four framed swallowtail banners high on the back wall.
- **Signs** (`shared/Signage.luau`): every zone has a stud-UI signboard: slate or timber backing, gold trim frame with corner studs, a neon underline, and a SurfaceGui in heavy Montserrat with a thick black outline, a light-to-accent gradient, a round icon badge and a subtitle. GEAR SHOP, PRIZE WHEEL and DAILY QUESTS stand on their stalls, GAME PASSES and GOD SKINS hang on chains from the tie beams, NEON CLIMB and the HALL OF LEGENDS arch sit low on the back wall, and the client puts an ARENA CAM header on the screen. The coin emoji has no glyph in the font, so prices on signs say COINS.
- **Showcase** (LodgeController): pass icons, gear props and God skin statues bob and turn slowly while the camera is in the lodge and near them; their "Orbit" parts circle faster. Skin displays have a soft particle aura (`Config.Lodge.Auras`, off in Low-FX), the hearth has rising embers, and the hearth and lantern lights flicker. Decorative lights share the `Config.Details.MaxLights` budget. Every lodge part except the obby finish and the spawn has CanTouch off; parts under `Config.Performance.ShadowMinVolume` cast no shadow.
- **Hall of Legends** (back wall, centre): under a marble-pillared arch whose lintel is the title board (kept low so the Arena Cam above stays in view), a gold/silver/bronze podium where the all-time top three for `Config.Leaderboards.Hall` (rounds survived) stand as statues of their real avatars (a clone of the live character when that player is in the server), with name and record above. Places the all-time list can't fill are taken by the best players in the server, and any place still open holds a gold, silver or bronze metal mannequin labelled "Your name here?", so the podium is never bare. Every board (and the podium) merges the saved all-time top with the players in the server right now, so a new player shows up on the next refresh without waiting for the ordered store; a board with nobody on it shows the template's empty state. It refreshes when a profile loads, after each round and every minute. There is no per-round winners podium in the lodge any more; the round summary still shows the round's top three.
- **Leaderboards:** four boards along the back wall, two either side of the Hall of Legends.
- **Centre:** spawn pad on the runner, the daily quest board (a roofed notice board with pinned quest notes) and the prize wheel (marquee bulbs) either side, the streak chest beside the spawn, and the four game pass plinths. Each pass shows a 3D icon over a tiered marble-and-gold octagonal plinth with a recessed neon ring, corner pillars and a holographic projector: a stack of embossed 2x coins, a jewelled velvet crown (VIP), a horned purple energy orb (God Priority) and a winged lightning boot (Quick Dash).
- **West:** the gear shop, a timber-and-brass stall with a striped awning, scalloped valance, shelves of bottles and cans, crates, a barrel and two flickering lanterns, with a Speed Soda can, a Balloon Glider and a hex-grid Shockwave Shield turning on the counter; and a fireside lounge (sofas, rug) round a stone hearth with quoins, an arched firebox, a slate hearth, andirons, crossed logs on an ember bed, a mantel on corbels with candles, and a shield and crossed swords on the chimney.
- **East: Neon Climb obby.** 11 evenly spaced pads (8 studs apart, 1.5 studs higher each, alternating 2 studs left/right) on glowing stems up the east wall to a loft in the front corner (+15 coins and a chime, 15 s personal cooldown: something to do while waiting for the next round), with a neon ramp back down. A glass divider separates the course from the ramp and the hall so it can't be skipped; falling lands you on the lodge floor next to the start.
- **Observation deck:** past the wide front opening, 112 x 34 studs with a glass-floor strip at the edge, a low glass rail with no neon on the front (so nothing glares across the view), invisible walls above the rails, and the telescopes and benches kept to the sides so the middle stays clear for looking down on the arena.

Thirteen arenas (`Config.World.MapRotation`). Each intermission opens a 9 s **map vote** (VoteService / VoteController) as a cinematic "CHOOSE A MAP" window: three tall cards, each a slowly pushing-in shot of the arena (`Config.World.MapThumbnails`, captured in Studio), the live vote count in a bubble, a NEW! tag on the newest arenas, the countdown and a close button. Voting is optional: close it to keep exploring and reopen it from the pill under the round bar. Every ballot is fresh: never the map just played, and none of the previous ballot's maps while enough others exist (with nine maps, always three new ones). Ties and empty votes pick at random; each vote is logged as a `MapVote` analytics event. Each sets its own lighting preset, flood fluid (Flash Flood twist) and knockback multiplier. Every arena is one connected, traversable area (no void between platforms): survivors can always run somewhere, and height is the reward for climbing.

| Arena | Look | Signature destruction | Flash Flood |
|---|---|---|---|
| Fracture Bay | Sunny beach | Sand bars connect both shores across the channel; glass resort on exposed pillars pancakes down; suspension bridge; lighthouse; 4-storey bay hotel on the sand bar, surf club, fish market, cliff-top villa, 4-storey harbor office, 3-storey cafe, beach huts, water tower and lifeguard tower | Water to Y 20 |
| Neo-Shibuya Skyline | Neon night | Four towers on a walkable street grid, each with a long ramp to its roof; glass skybridges link the rooftops; hologram billboards topple; four 4-storey destructible neon shophouses on the outer streets (the towers themselves are solid); kiosks, cars and vending machines for cover | Toxic smog to Y 16 |
| Magma Core Station | Volcanic | Four rock quadrants split by narrow lava channels, joined by land bridges and a central hub plaza; catwalks on truss supports drop into the lava; volatile silos and barrels chain-explode; smokestacks topple toward the hub; 3-storey refinery; 3-storey control block, 4-storey refinery, forge hall, pump station, 4-storey assay lab and ore depot; vents burn | Lava to Y 14 |
| Sunscorched Mirage | Desert | Obelisks topple outward onto the wooden scaffold ring; stone aqueducts; stepped pyramid (sturdy high ground); sandstone bazaar buildings (2-3 storeys) in the courtyard corners; quicksand pits slow and hurt | Sand to Y 12 |
| Outpost Zero | Arctic | Research containers drop when their stilts snap; one large ice shelf with pressure ridges and a ramped comms plateau; bunkhouse, hangar, 3-storey drill hall and cold store; breakable edge floes; **2x knockback** on slippery ice | Freezing water to Y 9 |
| Chrono-Spire Citadel | Steampunk foundry at golden sunset (~1,300 parts, radius 165) | Two cliff plateaus over a molten channel, crossed by iron bridges. A 5-storey Clocktower with spinning gear faces and clock hands; six brick works with sawtooth roofs, smokestacks that topple, and ladder shafts with windowed floors to hide in; catwalks and a sky-bridge between the roofs; **steam vents** launch you up to the catwalks; pressurised **boilers** chain-explode. **Set-piece:** a dirigible moored over the Central Works by four tethers. Snap two and it dives into the factory roof, smashing what it lands on | Molten brass to Y 20 |
| Verdant Bio-Dome | Solarpunk conservatory, bright sunbeams (~1,270 parts) | Four ancient trees, each with a low and a high white-steel glass lab on stilts (ladder shafts inside, a rope ramp between them); rope bridges between trees (cut them to strand the far side); a tiered greenhouse; a waterfall cliff with climbable ledges; hedges and pools. **Set-piece:** a 24-bay steel-and-glass dome. The God aims straight through the glass, impacts underneath crack the panels above, and breaking a bay's ribs drops its whole sheet of glass | Toxic spores to Y 18 |
| Ironclad Armada | Stormy fleet: rain, lightning, black cliffs (~1,100 parts) | An aircraft carrier with four hangar halls under the flight deck (hatch ladders), a command island and radar lattice, parked jets and container stacks, flanked by two destroyers. Wooden gangplanks join the ships; the sea is deadly. **Set-piece:** break a destroyer section's bulkheads and it **lists** 16° toward the water (a second hit sinks it); yellow cranes topple across onto the carrier | Hurricane swell to Y 21 |
| Starlight Boardwalk | Sunset carnival | Pier sections fall when pilings break; the Ferris wheel comes off its A-frame and rolls like a wrecking ball (the pier sections under its feet stand on unbreakable concrete footings so it always rolls instead of sinking); climbable coaster trestles; circus tent; four 2-3 storey pavilions on their own piles, so they stay up when the pier around them breaks | Tide to Y 12 |
| Abyssal Aqua-Dome | Open-top deep-sea trench at night: sheer walls glowing with cyan coral, jellyfish overhead (~1,200 parts) | No dome: a steel deck grid of wide walkways around five shallow glowing pools (bridges cross the big two); three 4-5 storey research towers in a row joined by roof skybridges, a control hub, a pump station and a lab; a yellow drilling rig on climbable lattice legs over the east pool, a crane gantry over the south pool, two docked submarines. Trench walls east and west (impassable); the north and south ends drop into the abyss, marked by buoys | The trench floods to Y 14 |
| Casino Royale | Open-air neon strip on a rainy night, walled in by the resort (~1,300 parts) | A **walled arena**: cream-and-gold resort facades with lit windows, two CASINO gatehouses with marquees and red carpets, waterfalls and pyramid-roofed corner pavilions. Four 4-5 storey hotel skyscrapers (purple and magenta, neon pilasters, gold trim, red awnings) with stairwell ladders to every floor; rooftop pools with loungers, a helipad and a cabana; glass skybridges between the roofs; a golden coin fountain, limousines and palms on the plaza and boulevards | Liquid gold floods the boulevard to Y 14 (get up the towers) |
| Oasis Bazaar | Sun-drenched sandstone city between towering red-rock cliffs (~1,400 parts) | A **walled arena** of canyon cliffs. Eight 3-4 storey sandstone apartment blocks (window holes, stairwells, balconies, outside ladders, striped rooftop awnings) with plank bridges between neighbouring roofs; a palace minaret by the river (three-storey base, a shaft with a ladder up to the balcony, lantern room and dome) that topples into the river; a shallow turquoise river between palm-lined banks with three plank bridges to a terrace of houses; market stalls and lanterns on the streets | A flash flood fills the canyon to Y 15 |
| Clockwork Spire | Open-sky steampunk foundry yard at golden hour (~1,300 parts) | A **walled arena** of brick-and-iron blast walls with giant brass gears turning on them, steam mains and glowing furnace arches. Two brick clocktowers (4 and 5 storeys, lit clock faces, a belfry and spire on the roof) and four multi-floor factories, joined by iron skybridges; four free-standing smokestacks that topple; steam-vent launch pads; glowing furnace pans, brass rail tracks and minecarts on the cobbles | Molten brass floods the yard to Y 14 |

Every arena also gets up to eight enterable **interiors** dropped onto genuinely empty ground after it builds (`Config.Hideouts`, styled to the map's lighting): sheds, two-storey houses with a stairwell ladder and windows, low concrete bunkers and lookout towers, each with crates inside to crouch behind. They are ordinary destructible buildings, and doorways and windows let the God see in, so they buy time but are never safe rooms.

**Lived-in interiors** (`World/Details.luau`): every multi-storey building (towers, works, labs, houses, hideouts) is furnished floor by floor against the walls from its map's theme: beds, sofas with rugs, dining sets, kitchens with fridges, bookshelves, desks with glowing monitors, TVs, plants and floor lamps at Fracture Bay; arcade cabinets, vending machines and desks in Neo-Shibuya; workbenches, stoves, shelves and barrels in Chrono-Spire; bunks, lockers, stoves and lab benches at Outpost Zero and on the Armada; lab benches with glowing flasks in the Bio-Dome. Furniture is cover, it breaks, and it falls with its floor (2 pieces per floor, 50 per map, no shadows). Facades get a coloured door awning and mat, flower planters under the upper windows, and a small colour shift per building so neighbours don't look identical.

**Everything is destructible.** The Neo-Shibuya towers are real buildings now (floors, windows, a stairwell, neon floor bands and signs that fall with their floors), the Bio-Dome's ancient trees can be felled (a tough trunk; drop it and the canopy comes down), and the Boardwalk's lamps and boats break. Only ground, cliffs, ramps and ship hulls stay solid. Anything that sits on a building (rooftop AC units, water towers, billboards, antennas, the Neo-Shibuya pavilions and skybridges, all the rooftop dressing) rests on it (`Builder.restsOn`) and falls when it collapses instead of floating.

**Reference dressing** (`World/Details.luau`, after every builder): each arena gets the small details of its reference art on its real roofs and on clear ground, all destructible. Neo-Shibuya: truss gantries with glowing holo billboards, AC units with spinning fans, water tanks, dishes, glowing helipads, neon street lamps and barriers. Chrono-Spire: brick chimneys, spinning wall gears, copper downpipes, lamps, crates and dock cranes. Verdant Bio-Dome: solar panels on the ground and lab roofs, dishes, mossy rocks with palms. Ironclad Armada: parked jets, stacked shipping containers, timber scaffold towers, radar dishes and deck lights. Sunscorched Mirage: carved broken columns, oasis pools with palms, sandstone rubble. Outpost Zero: snow caps and icicles on every roof, barrels, barriers, crates, pipe runs and a timber dock. Starlight Boardwalk: the WONDER PIER sign, arcade cabinets, striped food stalls, lamps strung with coloured bulbs. Fracture Bay: the FRACTURE BAY sign, harbour cranes, docks with crates and boats, palms and beach umbrellas. Magma Core: the MAGMA CORE STATION sign, hazard barriers, volatile barrels, crates, cranes and pipe runs. Abyssal Aqua-Dome: dishes and AC units on the station roofs, barrels, crates, cyan work lamps; research consoles in the labs. Casino Royale: gold floor lamps, slot machines and lounges in the suites. Oasis Bazaar: the OASIS BAZAAR sign, striped market tents (dates, spices, rugs, silk), barrels, crates, lanterns strung between posts. Clockwork Spire: gaslamps, chimneys, wall gears, ruined columns, copper pipes; bookcases in every room. PointLights from dressing are capped per map (`Config.Details.MaxLights`).

**Cars** (`Config.PropModels`): the hand-made car in `Workspace.Models` is moved to ServerStorage at runtime, stripped of its scripts, seat, forces, sounds and emitters, and scattered (anchored, every part destructible) onto clear ground: Neo-Shibuya streets, Fracture Bay, Outpost Zero, and the decks of Magma Core, the Armada and the Boardwalk.

**Skies and ambience.** The skyboxes hand-picked in `Workspace.Skyboxes` (moved to ServerStorage at runtime) are applied per lighting preset (`Config.Skyboxes.ByPreset`): CartoonSky for Fracture Bay and the lodge, NightSky for Neo-Shibuya, Sky for the Mirage and the Bio-Dome, Snow for Outpost Zero, Skybox_Sunset for the Boardwalk and Chrono-Spire, NightSky2 for the Armada. Magma Core keeps the burning sky from `Config.Skies`; NorthernLightsNight is spare. Client-only ambient emitters (`Config.Weather.Ambient`, MapFxController) add chimney smoke and smokestack ash on the tallest roofs, steam vents and sparks in the city, sea spray, low mist, dust devils and fireflies, a handful of low-rate emitters per map and none in Low-FX mode.

The three newest arenas are about 40% wider than the originals and lean on hiding: every highrise can have a ladder shaft (`Stairwell`) and half-height window walls (`Windows`), so upper floors are reachable and survivors can duck below the sills. `Builder.launchPad`, `Builder.spin`, `Builder.tilt` and `Builder.canopy` mark steam vents, spinning parts, listing ship sections and see-through glass roofs. Casts are allowed up to 55 studs past a map's own radius.

**Studio testing:** set the workspace attribute `ForceMap` (for example `"OutpostZero"`) during Play to pin the next map (this also skips the vote). Set `ForceTouchUI = true` before Play to preview the touch layout with a mouse.

### Audio
- **Music** (`Config.Audio.Music`): playlists. The lobby has three tracks, the round has two, and sudden death has one boss track. Each track plays through, then the next one starts; a list of one loops, and a track that fails to load is skipped. `AudioController` crossfades between lists.
- **Ambience** (`Config.Audio.Ambience` / `AmbienceLayer`): birds in the lobby, plus a per-map bed and layer in the arena, picked from the replicated `MapKey` attribute: waves and seagulls (Fracture Bay), city night, lava, desert wind, howling wind and surf, carnival crowd and surf, refinery hiss and metal groans (Chrono-Spire), jungle birds and a waterfall (Bio-Dome), thunder, rain and heavy surf (Armada).
- **Weather** (`Config.Weather`, MapFxController): client particles that follow the camera while it is down in the arena. Rain on the Armada (with lightning flashes and thunder every 7-15 s) and a lighter rain in Neo-Shibuya, snow on Outpost Zero, pollen in the Bio-Dome, embers on Chrono-Spire and Magma Core, drifting dust on Sunscorched Mirage.
- **Round cues:** countdown ticks with rising pitch in the last 5 s of intermission, tocks before casting opens, ticks in the last 5 s of the round, a round-start hit, a God stinger, a sudden-death alarm, and win/lose stingers.
- **UI** (`UI/Sound.luau`): every Components button, tab and window plays a click, tab or open sound; popups play coin, purchase or error sounds.
- **Disasters** (`AudioService`, server): positional, replicated sounds for telegraphs, lightning and thunder, meteors, tornado loops, gusts, quakes, collapses and explosions.
- **Smash** (`Config.Audio.Disaster.Smash`): a satisfying smash plays on every collapse and on any single hit that breaks 4+ parts (0.35 s cooldown).
- **UI sounds** (`Config.Audio.Ui`): every button clicks (`Click`); pointing at a button plays a soft hover sound (mouse only, throttled by `HoverCooldown`); centre-screen popups pop (`Pop`); claiming a quest or the daily reward plays an achievement sting (`Achievement`); the last three seconds before a round and before the disasters start play one "3, 2, 1" countdown clip (`Countdown`) instead of separate ticks.
- **Thunder variants** (`Config.Audio.Variants`): lightning plays one of three thunder clips at random (the original plus two extra claps).
- **Breaking materials** (`Config.Audio.Break`): every broken part plays a random crack, clang or shatter for its material family: splintering wood, metal clangs, crumbling stone and brick, glass shatters, ice cracks, foliage, plastic and sand (about 35 sounds from the Creator Store).
- **Mix** (`Config.Audio.Mix`): world sounds are scaled down and clamped, the disaster group runs through a compressor, at most 14 world sounds play at once and the break sounds are throttled per material, so a collapse is loud and layered but never deafening. The sound-effects toggle in Settings mutes this group too.

### Lighting and glow
`EnvironmentService` owns the only post effects. The place file's own Bloom, SunRays and DepthOfField are disabled at start and its Atmosphere removed; stacked on ours they doubled the glow. Bloom is softer (threshold 2.4, size 18, Neon-night intensity 0.22, down from 0.7), exposure is -0.15, and bridge rails are metal rather than neon. Between rounds the lodge uses its own warm `Lodge` preset, so avatars and statues keep their colour; the board spotlights on the dancers are turned down from 10 to 1.6 and the lodge's candle, podium and display lights are softer. Presets per map: Day, Night, Desert, Arctic, Sunset, Volcanic, Foundry (golden haze), Conservatory (bright and green), Tempest (overcast storm), Abyss, Casino, Canyon and Nebula.

**Visibility first.** Every preset keeps its mood but the atmosphere stays light (Density 0.22-0.28, Haze 0.5-1.2) so survivors and the God can see across the whole arena. The night maps (Neo-Shibuya, the Armada storm, the Aqua-Dome, the Casino, Clockwork Spire) stay night but carry strong moonlit ambient light (Brightness 2.8-3, bright cool Ambient / OutdoorAmbient) so nothing goes black. The Storm, Twilight and Sudden Death moods only dim by 15-22% and add a little haze.

### Island layout, walled arenas and the interior seal (`Config.Seal`, MapService)
Three of the newest arenas are **walled** (Casino Royale, Oasis Bazaar, Clockwork Spire: `MapInfo.Walled`): tall indestructible perimeter walls or cliffs with an invisible cap (`Builder.boundary`) above them, solid ground everywhere inside, and, on a Flash Flood round, the flood fluid (liquid gold, a flash flood, molten brass) rising from under the ground in sudden death. They have no edge drop and get no buoys; the seal finds no holes on them. The Aqua-Dome trench is half-walled: trench walls on two sides, abyss drops at the open ends. Every other arena is an island or raised platform: the outer rim is a drop into the sea, lava or void, so Gust and Tornado knockback still reward edge plays and edge collapses stay exciting. Inside the island there are no hidden pits. After a map builds, MapService samples an 8-stud grid: a hole counts as interior when solid ground lies further out in the same direction, or on both sides of it (a channel). Each interior hole gets a safe shallow floor (`Shallows`) that looks nothing like the lethal edge: on water maps a bright sand floor just above the outer sea under a clear turquoise water layer (Transparency 0.45, no damage); on lava maps a dark basalt crust with a glowing seam, just above the hazard line (safe to walk). The outer sea that kills is dark opaque navy on water maps and glowing magma on lava maps, and red warning buoys (dark posts with orange lights on lava) float just past the island rim where the drop begins. A ladder goes up any edge too high to jump out of. That covers Fracture Bay's channel, the sea between the Armada's ships, Magma Core's lava channels, Chrono-Spire's molten channel and the water under the Starlight pier; the outer 16 studs of each island stay a drop. The kill plane sits below everything. On a Flash Flood round the rising fluid still kills in the shallows. The Aqua-Dome moon pool and the Oasis river are built shallow (about 1.5-2 studs of water over a solid bed).

**Walk widths.** Every bridge, catwalk and staircase is at least 12 studs wide (`Config.World.MinWalkWidth`), so a phone player can dash across.

### Performance
Structure never fires Touched events (`Builder.structural` turns CanTouch off; launch pads turn it back on), structure smaller than 24 studs³ and all furniture and dressing cast no shadows (`Config.Performance.ShadowMinVolume`), dressing lights are capped per map, and the Arena Cam and ambient emitters only run where they can be seen.

### Destruction model
Every destructible part has health (from its material), a level, and a support flag, and belongs to a building. Damage breaks parts. When a level loses more than 30% of its supports, every level above is welded into slabs and released, and the remaining supports buckle out from under it. A building with a `FallDirection` tips over in that direction instead of slumping (obelisks, billboards, smokestacks, water towers, the Ferris wheel, cranes, the dirigible); `FallSpeed` overrides the push and `CrashDamage` / `CrashRadius` make the falling hull smash what it lands on. A building marked with `Builder.tilt` lists around a pivot axis on its first support failure (ship sections) and collapses on the next. Parts marked `Canopy` (the dome glass) are transparent to the God's aim and to ground raycasts. Parts tagged as hazards (`HazardDPS` / `HazardWalkSpeed`) hurt or slow anyone standing on them. Debris stays solid for ~9-12 s, then stops colliding with players, shrinks and fades (so rubble can't trap anyone and late-round frame rate holds), or is removed when it sinks. A damaged building that is still standing groans as a warning.

**Performance (`Config.Debris`).** Floors, supports and collapsing slabs stay server-simulated so collisions are fair. Small non-load-bearing pieces (up to 60 cubic studs, plus all glass, neon, fabric and leaves) are removed on the server when they break and sent, batched once per frame, to every client, which simulates them locally as rubble that never touches characters (`DebrisController`): up to 220 pieces for 7 s on desktop, 80 pieces for 4.5 s on phones. Server debris that has rested for 2 s is anchored with touch and query off so the solver stops working on rubble piles (the tornado wakes pieces it picks up). On touch devices, particle emitters run at half rate and 60% lifetime, trails at half length, fire at 70% size, and debris casts no shadows.

## Game feel
**Nintendo-style pass (`Config.Feel`, FeelController / SaveService.AllowHit).** What makes Nintendo games feel good is forgiving input, readable feedback and pacing beats. This pass adds:
- **Coyote time (0.12 s):** jump just after walking off a ledge and it still counts.
- **Jump buffering (0.15 s):** press jump just before landing and it fires on touchdown (great on the obby and rooftops).
- **Mercy invulnerability (0.4 s):** after a disaster hit, overlapping blasts (a meteor shower, a gust into a bolt) can't chain-kill you; your character flickers so you can read it. Tick damage (lava, fire, tornado) still lands.
- **Landing weight:** a hard landing (falling faster than 55 studs/s) gives a small camera thump.
- **3-2-1-GO!** pops into the moment disasters unlock, with tick and go sounds. It stays silent visually while a first-time role card is open so the tutorial isn't covered.

- **Camera shake and impact punch:** every disaster shakes nearby cameras; building collapses shake in proportion to their size, and heavy hits add a short field-of-view punch.
- **Ragdolls:** knockback of `Config.Ragdoll.MinKnockback` or more (gusts, tornadoes, fault lines, explosions) sends a survivor tumbling for 1.6 s before they stand back up. Dead characters stay in one piece as ragdolls.
- **Audio cues:** each disaster has its own telegraph sound (`Config.Audio.AbilityCue`), and an air raid siren loops through Sudden Death.
- **Hunter's Pulse:** in the last 20 s, if exactly one survivor is left and a human is God, that survivor is highlighted every 4 s so the round ends in a chase.

## Chaos Twists, the Emergency Flare and God combos
- **Chaos Twist** (`Config.Mutators`, MutatorService): right after the map vote, 20% of rounds roll one of seven free mutators (equal odds). A banner announces it once the vote winner flashes, and a badge under the round bar shows it all round. Everything resets at round end.

| Twist | Effect |
|---|---|
| Bouncy Rubble | Broken debris gets 0.85 restitution and bounces chaotically |
| Gold Rush | Coins fall across the arena every 4 s (6 each) and round payouts are x1.5 |
| Brittle Timber | Wood and glass take 2x structure damage; metal and stone are normal |
| Twilight Storm | Darker sky and fog; telegraphs, pings and outlines stay bright neon |
| Hyperdrive | Survivor dash and God Chaos Energy recharge 25% faster |
| Air Drops | 2-3 glowing supply crates land mid-round: speed boost, a one-hit shield, or 40 coins |
| Flash Flood | The Rising Tide comes in early (right after prep), climbs higher before sudden death and peaks 4 studs above its usual peak. Announced at the start, so survivors keep some high ground in mind and the God decides whether to level it |

- **Emergency Flare** (`Config.Beacon`): with 30 s left a flare lights on the highest exposed rooftop. Survivors who stay within 9 studs of it for 4 s earn +150 coins (once each). The God can see it too, so hiding forever isn't the only play.
- **God combos** (`Config.GodCombo`): destructive hits from different disasters chained within 5 s pay +6 Chaos Energy and +8 coins per extra link (up to x5); a whole building or floor collapsing pays +10 energy and +12 coins.
- **Stress cues** (`Config.Stress`): when a damaged building is within 15% of collapsing, it groans loudly, dust sifts out and nearby cameras tremble, a split-second warning to dash out.

## Progression
- **Mastery titles** (`Config.Mastery`, ProgressionService): profile counters unlock tiered titles: Runner I-V (rounds survived), Ghost Walker I-III (rounds survived without a single noise ripple), Daredevil I-III (taunts), Demolisher I-III (parts destroyed), and a God track per kit (Architect, Storm Herald, Magma Lord, Glitch King, World Ender I-V). The best one floats over your head in its colour, and new tiers pop a TITLE UNLOCKED toast.
- **Daily login reward** (`Config.Daily`, DailyRewardController / ProgressionService): play on consecutive days to build a 7-day streak. Once a day, and calmly: never on the first moments after joining. It waits until a round has ended since you joined, then opens at the start of a lobby break (with at least `Config.Daily.OpenMinBreak` seconds before the vote), never mid-round, over the map vote or another window; if the vote or a round starts while it is up, it steps aside and comes back at the next lobby break. A compact Daily Reward window shows the seven days; today's tile glows gold with CLAIM, and tomorrow's is highlighted "COME BACK TOMORROW". Rewards: day 1 150 coins + a free spin; day 2 the **Solar Flare** dash trail (300 coins + a spin if you already own it); day 3 250 coins; day 4 300 coins + a spin; day 5 400 coins; day 6 500 coins + 2 spins; day 7 750 coins + the exclusive **Sunforged** God skin (1,500 coins if owned). The lodge chest claims the same reward. Each claim logs an `AnalyticsService` custom event `DailyRewardClaimed` (day, streak).
- **First round completed**: a one-time +100 coins line on a player's first full round.
- **Friend squad boost**: while a Roblox friend is in the same server, round rewards get +20% (a "Friend boost" line) and a subtle "👥 +20% Friend Boost" pill sits by the coin balance.
- **First win of the day**: the first survived round and the first God win each day pay double.
- **Play of the Match**: the round summary hands out superlative badges: Demolitionist (most parts broken), Closest Call (most near misses), Phantom (longest stealth streak) and Menace (most Daredevil taunts).
- **Your highlight**: the Round Over card also shows a personal pill: "Closest Call: 3 near misses", "Most Buildings Wrecked: 120 parts", "Survivor Streak x4", "Escaped 2 collapsing buildings", and so on.
- **Next unlock**: under the total, a progress bar toward the cheapest coin item you don't own yet (a God kit or cosmetic): "30% to Storm Deity (450 / 1,500 coins)", or "You can buy it now" when you can.

## Showdowns, taunts and the kill feed
- **Last Stand** (`Config.Showdown`, ShowdownService): when a round that had 2+ survivors is down to one with at least 15 s left, everyone gets a LAST STAND banner and feed line, a heartbeat loops and the music switches to the boss track. The God sees a 40-stud zone around the survivor (offset up to 22 studs, refreshed every 5 s), and the survivor's dash recharges twice as fast and near misses pay double.
- **Daredevil taunts** (`Config.Emotes`, EmoteService / EmoteController): a 😜 button just left of DASH (T on keyboard) opens Wave, Whistle, Scream and Dance (8 s cooldown, a bubble over your head, and noise). Emoting while HIDDEN is a Daredevil taunt: the God sees your silhouette for 1.5 s and gets a callout, and every coin you earn for 10 s is multiplied by 1.5. The button turns 😈 while you're hidden.
- **Event feed** (`Config.Feed`, FeedController): the top-right corner, right under the currency bar (on phones it steps left of the God Chance card while that card is up), each line with a sticker icon. Near misses, escapes, kill credits and combos go here instead of the middle of the screen.
- **Kill feed**: eliminations name what got you. "Flattened by Bay Hotel" if a building collapsed on you in the last 4 s, otherwise the last hit within 6 s ("was crushed by Meteors", "was electrocuted", "was swallowed by the rising lava", "fell into the void"...). Clutch callouts: "escaped Meteors by 2 studs!" for near misses within 3 studs, and "escaped the collapsing Fish Market!" (once per player per building in 5 s, so a multi-floor collapse announces, and pays, once).
- **God kill confirm** (KillConfirmController): when the God's disaster eliminates a survivor, the God gets a hitmarker X snapping onto the victim's spot on screen (white, then red), a heavy hitmarker crack with a low coin ka-ching under it (pitched up on streaks), a kill chip "☠ ELIMINATED NAME" with DOUBLE / TRIPLE / MULTI KILL for kills within 4 s, and a purple flash at the screen edges.
- **Final kill:** the round's last elimination is posted as FINAL KILL, and every camera glides in on it with a desaturated grade and narrowed FOV for 2.4 s before everyone returns to the lodge.

## God kits
The God's five-slot hotbar comes from the equipped kit (`Config.Kits`), with a God Pack signature swapped in (see below; `shared/Loadout.luau` builds the list for both the client hotbar and the server check). Kits are bought with coins in the Shop's God Kits tab and can be swapped any time.

| Kit | Price | Abilities |
|---|---|---|
| The Architect | free | Lightning, Gust, Meteors, Tornado, Fault Cleave |
| Storm Deity | 1,500 | Lightning, Chain Bolt, Gust, Tornado, Meteors |
| Magma Titan | 2,500 | Eruption, Meteors, Fault Cleave, Lightning, Gust |
| Cyber Glitch | 4,000 | Glitch, Chain Bolt, Lightning, Tornado, Fault Cleave |
| Cataclysm | 3,500 | Meteor Barrage, Tectonic Spire, Chain Arc, Singularity, Gust |

Chain Bolt hops between the nearest survivors, Eruption leaves a burning lava pool, and Glitch flings survivors straight up. The server refuses any ability that is not in the caster's loadout. The AI Director uses every ability except the pack signatures.

**Big-map disasters (Cataclysm kit).** Built to flush survivors out of multi-storey interiors:

| Ability | Cost | Cooldown | Effect |
|---|---|---|---|
| 🕳️ Singularity | 50 | 15 s | Drags survivors and loose debris toward a point for 2.5 s (below ragdoll strength, so you can sprint or dash out), then detonates outward |
| 🗻 Tectonic Spire | 45 | 13 s | Five rock pillars burst up from the bedrock, smashing through every floor above and launching anyone on top |
| 🔗 Chain Arc | 35 | 9 s | A bolt that jumps up to 4 times between survivors, through walls, or crawls along nearby metal when no one is close |
| 🎯 Meteor Barrage | 40 | 11 s | Seven impacts rolling along an 80-stud line in the direction your camera faces (the reticle shows the line) |

**God Packs (`Config.GodPacks`).** Each premium God skin also swaps one ability for a signature version and brings a matching finisher. A signature costs and cools down exactly like the ability it replaces, so packs change the playstyle and the counterplay read, never the power. If the kit lacks the replaced ability, the signature takes the kit's last slot. The pack's finisher plays for eliminated survivors who are still on the starter Poof.

| Pack | Replaces | Signature | Synergy | Finisher |
|---|---|---|---|---|
| Storm Eye / Stone Fist | none | Classic Meteors and Fault Cleave | balanced | (the survivor's own) |
| 🔥 Magma Claw (R$149) | Fault Cleave | **Pyroclast Surge:** a lava wave rolls 100 studs along the line, burning wood for double damage and leaving fire | the God's fires burn twice as long | Lava Burst |
| 🤖 Cyber Gauntlet (R$149) | Lightning | **System Override:** an EMP that jams survivors' dash and scrambles their screen for 3 s; metal takes 1.5x | | Voxel Dissolve |
| 🌟 Celestial Mask (R$199) | Meteors | **Astral Collapse:** a golden singularity that throws everyone skyward and leaves the rubble floating | huge vertical launches | Sky Beam (the body is launched up a pillar of light) |
| 🌩️ Storm Sovereign (7,500 coins) | Tornado | **Maelstrom Vortex:** a vortex that follows your reticle instead of chasing survivors, puts out fires and hurls its rubble outward | | Storm Bolt |

## Daily quests
Three quests a day (UTC), the same for everyone: two drawn from `Config.Quests.Pool` (survive 2 or 3 rounds, use Dash 12 times, smash 25 or 200 parts as God, vote in 3 map votes, near misses, escapes, gear, the obby, the wheel...) plus "survive a round on the map of the day" (which gives the map vote a purpose). Progress is saved on the profile. Dashes are counted on the server from movement speed. Claiming pays coins; claiming all three grants a wheel spin and extends a daily streak. Open them from the Quests tile or the lobby quest board,; the Quests tile shows a badge with progress ("1/3") or "!" when one is ready to claim. When two of the day's quests share a stat (Survive 2 and Survive 3), progress counts up to the bigger goal and each turns ready at its own. The Quests and wheel windows draw above the map vote (and the shop above the vote too), so opening them during intermission always works.

## Presentation and settings
- **Round intro**: a 2.5 s swooping fly-by of the arena while the God's sky avatar fades in overhead. **Outro**: the camera sweeps up to the Hall of Legends.
- **Danger edges**: a telegraph that lands outside your view pulses a red glow on that edge of the screen.
- **Arena Cam**: a holographic screen mounted high on the lodge's back wall above the Hall of Legends and the boards, tilted down like a TV over a bar, broadcasts the match live, separate from the God view. The arena is mirrored into a ViewportFrame (its SurfaceGui lives in PlayerGui, adorned to the screen: a ViewportFrame on a part's own SurfaceGui renders nothing), collapses and debris stay in sync, and disasters, survivors (little figures with beacons; yours is gold) and the God's sky rig update 15 times a second. A director camera cuts every 6 s between an overview orbit, the latest disaster and a survivor close-up, always from above so walls never block it. Between rounds it shows a "next round soon" card. It only renders while you are in the lodge near the screen, and it copies the arena lazily (only once someone can see it, 150 parts a frame) so the round start never hitches.
- **UI juice**: spring-bounce buttons, a coin counter that rolls up, click / whoosh sounds.
- **Clear screen at round start**: the shop, quests and wheel windows close by themselves when a round you are in begins (a spin in progress finishes first), so nothing covers the arena when the disasters start. The event feed draws under the HUD, so the Round Over window always covers it. While the spectate view is open, the God Chance and Welcome Pack cards step aside. The tutorial's God hint sits above the taller ability hotbar. God kits are listed cheapest first.
- **One thing at a time** (HUDController stage queue): banners, first-time tutorial cards and centre popups wait their turn instead of stacking. While a banner or card is up, short popups go to the feed.
- **Action buttons**: on PC, DASH and the taunt button sit side by side in the bottom-right corner with white key chips (Q, T); the God hotbar and gear slots use the same chips. On phones DASH sits above and left of the jump button, never on it.
- **Lodge sidebar**: a 2×3 grid of tiles (Shop, Spin, Quests, Passes, Spectate, Play God) with even gaps; the Quests tile carries a done/total badge ("!" when a reward is ready).
- **Shop window**: solid panel over a dimmed screen (`Theme.Layout.ModalDim`); tabs, hero and card grid share one edge inset, and every card follows title, icon, description, buy.
- **Quick settings** (blue gear button beside the coin bar on PC, under it on phones; SettingsController): Low-FX mode (no client rubble or weather), camera shake (full / low / off), and music and sound-effect toggles, saved on the profile.

## Community and favourites
- **Community board** (lodge, by the deck doorway): a JOIN THE COMMUNITY sign over a glowing plinth tagged FREE REWARD. Its prompt opens Roblox's join prompt for the group that owns the game (`Config.Community.GroupId`, 0 = the owning group); the server then checks membership itself and pays once per player: 500 coins and the Storm Deity God kit (1,000 coins instead if the kit is already owned). After that the prompt reads "Claimed ✓". `CommunityService` / `CommunityController`.
- **Favourite prompt**: once per player, a few seconds into the lobby break after their 2nd to 5th round (fixed per player), Roblox's favourite prompt for the game opens. It is never rewarded: Roblox's rules forbid paying players for favourites or likes, and likes can't be prompted at all.

## Prize wheel
A purple SPIN WHEEL header with the red X over a gold-rimmed wheel ringed with blinking bulbs: alternating purple and gold slices (the last one lavender, so no two neighbours match), a gold pointer at 12 o'clock and a star hub. Every slice shows its icon, the prize in words ("1,500 COINS", "BE THE GOD", "SURVIVAL KIT") and its odds. The bottom row is **SPIN 1** [R$ price] · **SPIN [n]** (your banked spins; it pops when the count changes) · **SPIN 10** [R$ price], with the free-spin countdown underneath. Where paid random items are restricted the two price buttons give way to "Earn Free Spins via Quests & Daily Login!". While the wheel turns, a ratchet whirl (`Config.Audio.Ui.SpinWhirl`) slows with it under the per-slice ticks, and a hit plays when it lands.
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

Each board's first-place pedestal holds a clone of the `dancinggirl` model (`Config.Leaderboards.Dancer`, placed in Workspace by hand and moved to ServerStorage at runtime as the clone source) dancing its own emote. The template board's own avatar rig is kept invisible because its script keeps rebuilding it.

## Onboarding (the first 60 seconds)
Show, don't tell. The old three-bullet role cards are off (`Config.Onboarding.RoleCards`).

**First-round cinematic** (`Config.Presentation`, PolishController): once per player, ever, in their very first round. The fly-by continues into a short letterboxed sequence for the role they got, during the prep phase. The rest of the HUD hides while it plays, banners wait, and seeing either one saves both `Tut_IntroSurvivor` and `Tut_IntroGod` on the profile. From then on, the round-start GOD vs SURVIVORS card covers both roles.
- **Survivor** (about 7 s): the God's hand in the sky ("THIS IS THE GOD: <name> controls every disaster, and is hunting you"), then a harmless client-only demo right in front of them: a pulsing red zone and a meteor slamming into it ("RED ZONE = INCOMING DISASTER"), then back to their own character ("YOU ARE A SURVIVOR").
- **God** (about 5 s): the survivors, highlighted green ("THESE ARE THE SURVIVORS: real players hiding from you"), then the arena from above while a demo strike lands ("YOU ARE THE GOD: you control the disasters").

**Guided tutorial** (`Config.Tutorial`, TutorialController): only what the first minute needs, starting right after the cinematic: dash (arrow + pulsing ring on the DASH button), follow the arrows and hide (an animated chevron beam on the ground to the nearest hideout doorway), and, as God, pick a disaster and cast (arrow on hotbar slot 1), then two more steps that each point at a disaster you haven't used yet ("Press 3 for Meteors: rains meteors over a wide area", tips in `Config.Tutorial.GodTips`), the second one mentioning combo coins. While a step points at a slot, a wobbling callout over it shouts "[3] TRY METEORS!" ("TRY METEORS!" on touch). Any God who casts the same disaster 3 times in a row gets a "Mix it up!" nudge pointing at an untried one (once a round, not saved). Each step shows once, can be skipped for good, pauses while the cinematic, a banner or any window is up, and counts as shown after 40 s. The shop and the wheel are left to discover. Textures come from `tools/icons/gen_tutorial.py`. The Welcome Pack offer is hidden until the player has finished one round.

## Analytics (`Config.Analytics`, AnalyticsService)
Built on Roblox AnalyticsService, so everything shows on the Creator Dashboard:
- **Onboarding funnel**: Joined Lobby, Dismissed Role Card / Moved, Entered First Match, Used Dash or Ability, Completed First Round, Opened Shop or Spin Wheel.
- **MatchFlow funnel** (one session per player per round): Map Vote Cast, Role Assigned (God / Survivor), First Action (ability, dash or gear), Survived 60s or First Elimination, Sudden Death Reached, Round Completed (map in the custom fields).
- **Monetization funnel** (one session per shop or wheel visit): Shop or Spin Opened, Item Previewed (tab), Robux Prompt Shown, Purchase Completed, tagged with the item, product or pass, and the player's coin-balance bucket.
- **Custom events**: AbilityUsed (ability, kit, map and tier), SurvivorEliminated (cause, map, God or Director; value = seconds into the round), MutatorRolled, RoundEnded (survivors left), PurchaseCompleted (Robux), TutorialStep, plus VoteService's MapVote.
- **Economy events**: coins spent (sinks) and coins bought with Robux (IAP source).
Clients report UI-only steps on the rate-limited `Analytics` remote (whitelist in `Config.Analytics.ClientEvents`).

## Mobile
The UI is authored against a smaller canvas on touch devices so everything is larger, the menu sits top-left and the currency bar top-right to keep the thumbstick clear (the Friend Boost pill and streak sit to its left there), and the dash button sits beside the jump button at the same size. As God, drag pans the camera, pinch zooms, a two-finger twist rotates, the reticle stays at screen centre with a CAST button, and tapping the arena casts at the tap.

Every control hint matches the device: role cards, the God and spectate hints, the key chips on DASH, taunt and hotbar buttons (PC only), gear hotbar keys (hidden on touch) and the shop's gear text. Server banners write `{tap}` / `{Tap}` / `{TAP}` and the client swaps in tap or click (`Components.inputText`).

## Economy
- Coins come from surviving (+60, plus 10 per streak round), close calls, obby clears, participation (+10), and as God, eliminations and destruction.
- Coins buy gear and God kits. Profiles (coins, streaks, gear, welcome-pack flag, recent receipt IDs) persist through DataStore on live servers; Studio sessions stay in memory.

## Cosmetics (`Config.Cosmetics`, CosmeticService / CosmeticController)
Each category has a free starter, a coin item and Robux items. Bought or equipped in the Shop's Style tab; owned and equipped items persist in the profile.

| Category | Free | Coins | Robux |
|---|---|---|---|
| God Skin / God Pack: a giant avatar hovering 70 studs over the God's reticle for everyone (the God sees their own at 80% transparency); premium ones are God Packs with a signature ability | 👁️ Storm Eye | ✊ Stone Fist (3,000), 🌩️ Storm Sovereign (7,500) | 🔥 Magma Claw, 🤖 Cyber Gauntlet, 🌟 Celestial Mask |
| Disaster FX: recolours the God's bolts, telegraphs, meteors, tornado and lava | ⚡ Classic | ✨ Golden Wrath (2,500) | 🟣 Neon Void, 👾 Pixel Chaos (voxel meteors) |
| Finisher: plays where you're eliminated | 💨 Poof | 👻 Ghost Rise (2,000) | 🎉 Confetti Pop, 🌀 Cartoon Boing (boing + the body floats off) |

Small statues of all six God skins stand on showcase plinths either side of the lodge spawn, each with a name tag and price; their prompt opens the Style tab. Skins are part-built models in `src/shared/GodSkins.luau`: hands are armoured gauntlets (layered back and palm plates, a bezelled energy core, knuckle guards, segment plates on jointed fingers, a two-segment thumb, a cuffed vambrace with a glowing band, talons on the claws) with crystal shards orbiting the wrist; the Storm Eye has a layered iris and a segmented gyroscope ring, the Celestial Mask has brow, cheek, nose and chin plates, ear fins and a seven-spike crown, and the Storm Sovereign has zig-zag bolts and a crown of storm shards. Parts named "Orbit" circle the skin, in the sky and in the lodge.

**The God's sky rig.** Every round has one, including AI rounds (the Director uses the Storm Eye): the God's client sends its ground aim on the `GodAim` UnreliableRemoteEvent at most 10 times a second and only after it moved 1.5 studs; the server relays it to everyone on `GodAimRelay` (the AI's hand drifts between random spots, never over a survivor, and swoops to each target it casts at). Clients glide the rig 84 studs above the aim, bank it toward its travel, bob it and spin its orbiting parts every frame, and on every cast it slams down and flashes (`ClientEffect "GodCast"`). It is drawn 1.7x size with an always-on-top rim and glow fill in its colour (it reads through the Bio-Dome glass and the Armada's storm), a glow light and, not on phones or in Low-FX, a sparkle aura. Every part is anchored, non-colliding, non-queryable and shadowless. The God sees it faint, and not at all when their camera is close to it.

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
| 1 Wheel Spin / 10 Wheel Spins | R$34 / 149 | +1 / +10 prize wheel spins (not offered where paid random items are restricted, see below) |
| 🪂 Emergency Glider | R$9 | One charge. Fires automatically when you're about to fall into the void or sink in the rising fluid: launches you up toward the middle of the map on a 4 s slow glide |
| 🛡️ Aegis Bubble | R$15 | One charge. Fires automatically on a disaster hit that would kill you: you keep 30 HP inside a 2.5 s force field |
| God Skins: Magma Claw / Cyber Gauntlet / Celestial Mask | R$149 / 149 / 199 | Permanent cosmetic (see Cosmetics) |
| Disaster FX: Neon Void / Pixel Chaos | R$99 / 129 | Permanent cosmetic |
| Finishers: Confetti Pop / Cartoon Boing | R$99 / 99 | Permanent cosmetic |

**Paid random items and PolicyService.** Robux wheel spins are paid random items. On join, MonetizationService asks `PolicyService:GetPolicyInfoForPlayerAsync` and sets the player's `PaidRandomRestricted` attribute (restricted until it answers, and if it fails). Where `ArePaidRandomItemsRestricted` is true, the wheel hides its Robux buy buttons and shows "Earn Free Spins via Quests & Daily Login!", and `Store.promptProduct` refuses spin products. Free spins from quests, the daily reward and the wheel itself still work.

The nine cat-and-mouse products are live (created through Open Cloud). A product added later can start with `Id = 0`: its shop button reads SOON and `ProcessReceipt` ignores it until the real id is set; `DevPurchase` grants it in Studio regardless.

**Panic saves instead of mid-danger prompts:** a purchase prompt that opens while you're falling arrives too late and feels predatory, so saves are bought ahead (Specials tab) and fire on their own. After a death a save would have prevented (void or fluid for the Glider, a disaster hit for the Aegis), a one-tap "this would have saved you" card appears for 8 s if you have none. Owned charges show above the gear bar during rounds.

**Game passes:**

| Pass | Price | Perk |
|---|---|---|
| 2x Coins | R$199 | Doubles all coins earned from play |
| VIP | R$249 | Gold VIP tag, rainbow dash trail, +15 coins every round |
| God Priority | R$299 | God Chance grows twice as fast |
| Quick Dash | R$99 | Dash cooldown halved |

**Where they're sold:** the Shop window has Gear (coins), God Kits (coins), Style (cosmetics), Coins, Passes and Specials tabs; each page scrolls sideways when the cards don't fit. Each tab leads with a featured banner (Gear: Survival Kit; Coins: Vault of Coins; Specials: Be the God with your live God Chance; Style: the Celestial Mask) or a title strip (God Kits: your equipped loadout, and each kit card shows its five disasters; Passes). The currency bar (top right, just above the event feed; on phones it sits in the Roblox top-bar row with the round bar) has a green "+" that opens the Coins tab.

**Stud UI look** (Figma "Survive The God" stud UI, built with the `ui-figma-roblox` skill): square-cut blocks with mitred black outlines, a darker depth edge under every block, a light inner rim, tiled studs, a translucent slate window body with a cyan studded header and a separate red X, and green buy buttons with diagonal sheen stripes. Colour codes the category: blue for survivor gear, purple and gold for God and premium items, pink for style, gold for coins, orange for specials, green for buying. Built by `Components.block` / `depth` / `rim` / `sheen` (tokens in `Theme.Block`); the shop layout lives in `Theme.Shop` with `Theme.ShopTouch` overrides for phones. The menu has a Passes shortcut, and each pass has a glowing pedestal in the middle of the lodge that previews it in 3D and prompts the purchase. The prize wheel window sells the spin packs. The whole God Chance card is a tap target for Be the God Next Round, the Welcome Pack card, and the Second Chance button. In Studio, `ServerStorage.DevPurchase` (a BindableFunction) runs the real receipt path for testing. Note that a game's creator owns all its passes, so pass perks are always on for that account.

All numbers live in `src/shared/Config.luau`.
