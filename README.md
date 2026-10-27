# Island Fishing Tycoon — starter kit

A complete, playable first version of your game, written in Luau for Roblox Studio.
No models needed to start: the whole world (sea, islands, castles, docks, aquariums, palm trees,
ships, pirates) is generated from Parts when the server starts. Replace them with real models later.

**What's in v1**

- Each player gets their own sandy island with a stone castle, a dock, and a glass aquarium
- Fishing at the dock (hold the prompt → wait for the bite → tap **REEL**)
- 7 fish rarities (Common → Mythic); rarer fish earn more coins per second in your aquarium
- 4 infinite upgrades: Rod (luck + bite speed), Aquarium (slots + income %), Castle (HP, cannons, size), Ship (tier, speed, HP, cannons)
- Day/night cycle; at night pirates wade ashore and attack your castle — fight with the cutlass, castle cannons auto-fire
- Ships from Raft → Dinghy → Sloop → Brigantine → Galleon, driven with WASD / thumbstick, broadside cannons (F or the FIRE button)
- Player raids: sail to someone's island, break their castle, steal 10% of their coins + a fish; victim gets a 5‑min shield
- **300 catchable species** across 12 rarity tiers (Common → Secret), each with its own income/sec; a catch card shows name, tier, income, and a NEW SPECIES badge; the Tank panel lists what you own and a discovery counter
- **Safe trading**: pick a player, both add fish, both confirm; any change resets confirms; server swaps atomically and checks tank space
- **Raids only happen at night** — daytime is for fishing, building and sailing
- **Real creature models**: every species gets a body plan (shark, ray, eel, octopus, turtle, crab, jellyfish, whale, seahorse, puffer, billfish, anglerfish, shellfish or generic fish) built from parts and animated swimming in the tank, with a name/income label when you walk up
- **Enterable castle**: open gate, courtyard, ramps up to the wall walk, cannons you fire yourself with E, a keep with a treasure chest inside; pirates path through the gate
- **Island crew**: hire Fishers (auto-catch on a timer, into your tank) and Guards (patrol the castle, fight pirates and raiders) with coins; upgrade their rods and weapons without limit
- Saving (DataStore), offline earnings, mobile-friendly HUD built in code

---

## 1. Put it in Studio

### Option A — paste scripts manually (10 minutes)

Create this tree in the Explorer. **Names and script types matter.**

```
ReplicatedStorage
└─ Shared                    (Folder)
   ├─ GameConfig             (ModuleScript)
   ├─ Remotes                (ModuleScript)
   ├─ Builders               (ModuleScript)
   ├─ StoreConfig            (ModuleScript)
   └─ FishDatabase           (ModuleScript)
ServerScriptService
├─ Main                      (Script)          ← Main.server.luau
└─ Services                  (Folder)
   ├─ DataService            (ModuleScript)
   ├─ IslandService          (ModuleScript)
   ├─ EconomyService         (ModuleScript)
   ├─ FishingService         (ModuleScript)
   ├─ DayNightService        (ModuleScript)
   ├─ CombatService          (ModuleScript)
   ├─ PirateService          (ModuleScript)
   ├─ ShipService            (ModuleScript)
   ├─ RaidService            (ModuleScript)
StarterPlayer
└─ StarterPlayerScripts
   ├─ ClientMain             (LocalScript)     ← ClientMain.client.luau
   ├─ UIController           (ModuleScript)
   ├─ FishingController      (ModuleScript)
   └─ ShipController         (ModuleScript)
```

For each file in `src/`, open the matching script in Studio, select-all, and paste the file contents.
Files ending in `.server.luau` are **Scripts**, `.client.luau` are **LocalScripts**, everything else is a **ModuleScript**.

### Option B — Rojo (recommended once you use Claude Code)

1. Install Rojo (`cargo install rojo` or the VS Code extension) and the Rojo plugin in Studio.
2. In this folder run `rojo serve`, then in Studio click Rojo → Connect.
3. Edit files on disk (or let Claude Code edit them) and they sync live into Studio.

### Studio settings you must change

- **Game Settings → Security → Enable Studio Access to API Services = ON** (saving won't work otherwise)
- **Game Settings → Avatar**: leave default; pirates are their own rig
- Delete the default Baseplate and any SpawnLocation in Workspace (the script builds its own)
- **Lighting → Technology = Future** (select Lighting in Explorer, Properties → Technology). Scripts can't set this; it makes a big difference to water, shadows and the castle torches
- The world builder calls `Terrain:Clear()` on start so the islands come out clean. If you sculpt your own terrain later, remove that line from `Builders.BuildWorld`

Press **Play**. You'll spawn on your island. Walk to the end of the dock and hold the prompt.

To test multiplayer/raiding: **Test → Clients and Servers → 2 players → Start**.

---

## 2. How the game is wired

```
Client (per player)                          Server
───────────────────                          ──────
ClientMain ─ starts controllers              Main ─ starts services, loads profile on join
UIController ─ HUD, shop, tank, stats        DataService ─ DataStore load/save/autosave
FishingController ─ REEL button, popups      IslandService ─ builds world, assigns islands
ShipController ─ drives your ship            EconomyService ─ income/sec, upgrades, Stats remote
                                             FishingService ─ cast → bite → reel → roll fish
         RemoteEvents in                     DayNightService ─ clock, NightStarted event
         ReplicatedStorage/Remotes           CombatService ─ castle HP, cannons, cutlass, cannonballs
                                             PirateService ─ night waves, bounty, coin loss
                                             ShipService ─ spawn ship, network ownership, broadsides
                                             RaidService ─ "Raiding" state, loot on castle break
```

Everything tunable is in **`GameConfig`** (and the species list in **`FishDatabase`**): fish table, upgrade costs/growth, stat formulas, pirate scaling,
day/night lengths, raid steal %. Changing a number there changes the game.

**Infinite scaling:** cost = `base × growth^level`; stats are formulas of level with no cap.
Rod luck shifts the rarity curve, so a high rod eventually pulls Mythics regularly — add more fish
tiers to `Config.Fish` when you want a longer late game.

---

## 3. Making it look good (your art pass)

The generated parts are deliberately simple so you can replace them one model at a time.
Each builder returns a Model with **named parts the scripts rely on** — keep these names:

| Thing | Must contain | Used by |
|---|---|---|
| Island model | `Root` (PrimaryPart), `FishingSpot`, `ShipSpawn`, `Spawn` (SpawnLocation), `Aquarium` with `Glass`, `Water`, `FishDisplay` | Island, Fishing, Ship services |
| Castle model | `CastleRoot` (PrimaryPart), `Cannons` folder with parts named `Cannon`, attributes `HP`, `MaxHP`, `Level` | Combat, Pirate, Raid |
| Ship model | `Hull` (PrimaryPart) with `Drive`, `Steer`, `Upright` constraints, `DriverSeat`, `Cannons` folder (`Side` attribute ±1) | Ship service + controller |
| Pirate | `HumanoidRootPart` + Humanoid, attribute `IsPirate` | Combat, Pirate |

Art direction baked in: saturated sand (`248,222,150`), turquoise water, pale stone with red tower roofs,
white sails with a red stripe, Fredoka One font, bloom + light color correction. Swap colours in the `C` table at the top of `Builders`.

Quick wins once it runs:
- Use the **Terrain editor** to sculpt real islands around the generated ones, then delete the sand cylinders
- Replace `BuildPalm` with a free Toolbox palm, `BuildPirate` with a dressed R15 rig
- Add a water splash ParticleEmitter on cast, a bob animation on the fish display
- Add sound: casting, bite "!", coin, cannon boom, pirate yells (Toolbox audio)

---

## 4. Monetization (the Store)

All Robux offers live in **`ReplicatedStorage/Shared/StoreConfig`**. Every item has `id = 0` until you create it:

1. Creator Dashboard → your experience → **Monetization → Passes** (permanent) and **Developer Products** (consumable)
2. Create each one with the name and Robux price from `StoreConfig`, copy its ID, paste it over the `0`
3. Items still at `0` are hidden automatically, so you can launch with just a few

Also add `MonetizationService` (ModuleScript) under `ServerScriptService/Services` and `StoreConfig` under `ReplicatedStorage/Shared`.

**What's wired in**

| Offer | Type | R$ | Effect |
|---|---|---|---|
| VIP Tycoon | pass | 149 | 2× passive income forever |
| Auto-Fisher | pass | 99 | casts & reels for you near any dock |
| Mega Aquarium | pass | 79 | +50% tank slots |
| Lucky Rod | pass | 129 | +15 luck (way more Legendary/Mythic) |
| Admiral's Fleet | pass | 199 | +2 ship & castle cannons, 1.5× speed, black sails |
| Fortress Walls | pass | 99 | 2× castle HP, pirate/raid losses halved |
| Pouch / Chest / Hoard of Coins | product | 29 / 79 / 199 | 20 / 75 / 240 minutes of your *current* income (floors 500/2000/7000) |
| 2× / 3× Income (1h) | product | 49 / 99 | timed boost, stacks with VIP |
| Raid Shield (24h) | product | 59 | no player raids |
| Calm Seas (3 nights) | product | 39 | pirates skip you |
| Instant Upgrade | product | 69 | +1 level on any upgrade (button in the Shop rows) |
| Starter Pack | product | 99 | 2× income 24h + shield 24h + 3h of coins + 1 free level; only in the first 24h |

**Why it's built this way (the psychology, used honestly)**

- *Low first step.* 29–59 R$ consumables turn the first purchase into an impulse. Players who buy once buy again.
- *Anchoring.* Three coin tiers; the middle is highlighted and labelled "+40% more", the top is "BEST VALUE". Both claims are true per Robux, and most people pick the middle.
- *Outcome language.* Cards say what the player gets ("Legendary fish, way more often"), never the mechanic.
- *Scaling value.* Coin packs are priced in minutes of income, so a 29 R$ pack is still worth it at upgrade level 50.
- *Contextual offers.* A Shield card appears right after you get raided, Calm Seas after pirates win, Mega Aquarium when your tank fills, a Chest of Coins when you've been short twice in a row. One offer per 3 minutes, each shown once per session, always dismissable.
- *Real scarcity.* The Starter Pack countdown is a true 24h-from-first-join window. There are no fake "was 500 R$" prices or looping timers — those get reported, and Roblox's audience is young.
- *Passes pay for themselves visibly.* VIP doubles the big green "+X /s" number the moment it's bought.

**Lines not crossed:** no loot boxes or paid random rewards (Roblox treats them as gambling), no spending prompts during combat, no pop-ups that can't be closed.

## 5. Known limits of v1 (good next tasks)

- Pirates walk straight at the castle; no pathfinding (use `PathfindingService` for nicer movement)
- Ship HP exists but nothing repairs it except respawning the ship
- No anti-exploit on remotes beyond basic checks; add rate limits before you have a real audience
- DataStore uses `SetAsync`; swap for ProfileService/ProfileStore before launch for session locking
- Only 8 islands — set `Config.World.IslandCount` and the max players in Game Settings to match

Have fun, and send me the first screenshot.
