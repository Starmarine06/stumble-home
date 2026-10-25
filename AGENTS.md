# Stumble Home: project notes

Everything needed to pick this project up cold. Keep this file current.

## What it is
4-player online co-op 3D party game, 18+, Windows PC. The crew is very drunk, the car is wrecked. Phase 1: find 4 parts in a junkyard and fit them. Phase 2: drive home before the cops catch up. Owner sells games; judge ideas by downloads and player retention, and say which one an idea moves. Player-facing text (store page, patch notes, replies) is casual and playful, matching the 18+ vibe.

- Repo: https://github.com/Starmarine06/stumble-home (public). Local: `X:\Godot Games\stumble-home`
- Collaborator: `eldhoGI2` invited with write access (pending until accepted at the repo's invitations page).
- Engine: Godot 4.7.2 (`X:\Godot_v4.7.2-stable_win64.exe\`, use the `_console.exe` for headless runs).
- Multiplayer: Epic Online Services via EOSG 2.3.1 (https://github.com/3ddelano/epic-online-services-godot).

## Decisions made with the owner
- Full co-op (no PvP, no traitor). Online via room code. Public repo. Windows only for v1.
- 3D first-person (switched from third-person, 2026-10-23), low-poly cartoon, silly tone. Pattern taken from `origin/feature`: body yaw, head pitch clamped to 89 degrees, mouse sens 0.003, head bob, Esc frees the mouse.
- Campaign structure: multi-night campaign (night 1 = base game, night 2 = harder with hazards and kebab stop).
- Fail state: shared wanted level fills (cops arrest the group) or the car dies.
- Roles are also the drunk types, and everyone is *very* drunk with a hard time doing anything:
  - Driver (The Sloppy): wandering/laggy steering, hiccups, nods off. Strong carrier.
  - Navigator (The Blabber): only one who sees the route; arrows flicker between true and wrong. Junkyard part compass. Kebab shop order reader.
  - Mechanic (The Shaky): only one who can fit parts; cools the overheating engine.
  - Lookout (The Paranoid): sees parts glow within 25 m; sees cops coming and must signal.
- **Planned loop (decided 2026-10-25, not built yet):** the junkyard scavenge is replaced by an economy. The crew earns a shared money pool, buys the car parts, fits them, then all 4 drive home in one car through the city.
  - The crew splits into two pairs, free choice of who goes where (roles do not decide it):
    - Casino pair: gamble the pool. One plays a casino game, the other plays something else at the same time.
    - Delivery pair: sketchy deliveries by scooter to people on the street or at houses. One drives, the other holds the parcel and must not drop it (reuses the `Player._hold` spring and `strain`).
  - Parts are priced very high, so deliveries alone or gambling alone cannot pay for them: both halves must contribute. Delivery is the steady income (capped by time and parcel condition); gambling is high variance with a slightly negative expected value.
  - Wallet is shared and host-authoritative in `Game` (`request_*` / `s_*` / `c_*`).
  - City: very big, around the casino, which is placed at a random lot from the run seed (never the outer ring). It is also the route home, replacing night 1's junkyard drive. Size is tuned so an average delivery takes 2 to 3 minutes. Hybrid build: seeded code-built layout (road graph, blocks, chunk streaming) with hand-made landmark scenes (casino, key shops) dropped onto reserved lots. `Drive` keeps the old route as a fallback.
  - Later: police checkpoints and random events. Houses are mostly facades with a few enterable ones.
  - Order: shared wallet and parts shop, port the casino into the networked game, city foundation, scooter and delivery, then houses, shops, events.
- Design rule I committed to: hard but readable. Every failure should be funny and fixable by teammates, otherwise frustrated players quit.
- Name: Stumble Home. Note: "Stumble Guys" is a well-known game, so check the name before a store page.

## Architecture (all in code, no hand-built scenes except `scenes/main.tscn`)
- `scripts/autoload/net.gd` (`Net`): EOS init, anonymous login, lobby create/join, ENet backend for local tests. Room code = lobby ID `SH` + 5 chars (custom lobby ID, join-by-ID on, invite-only). Tries an RTC (voice) room first, falls back without.
- `scripts/autoload/game.gd` (`Game`): shared state plus all gameplay RPCs. Host (peer 1) is the referee: clients call `request_*`, host validates in `s_*` and broadcasts via `c_*`. Helpers `_bcast` and `_to_host` also work offline (solo), which is how practice mode and tests run.
- `scripts/autoload/audio.gd` (`Audio`): audio hub, buses in code (SFX, Music, Voice), event registry, pooled one-shots, and hooks onto Game signals (crash, cops, hazards, kebab).
- `scripts/autoload/voice.gd` (`Voice`): child node under Net; handles EOS RTC room voice chat, push-to-talk/mute, speaking signals; safe no-op on ENet/solo.
- `scripts/main.gd`: menu, lobby, result screens (UI built in code). Test flags: `-- --auto=solo|host|join --night=N`.
- `scripts/world/world.gd` (`World`): junkyard scenery, parts, car, player spawner (spawns only after every peer reports ready), camera, HUD.
- `scripts/world/drive.gd` (`Drive`): route from seed, Driver's peer simulates the car and streams state, others follow.
- `scripts/world/hazards.gd` (`Hazards`): seeded road hazard planning (traffic, dogs, muggers), telegraphs, and collision checks.
- `scripts/minigames/kebab.gd` (`Kebab`) + `scripts/ui/kebab_panel.gd`: pure-logic kebab order generation, misclicks based on drunkenness, scoring, and UI chopping board panel.
- `scripts/player/player.gd` + `drunk.gd`: first-person on-foot player (local one owns the Camera3D under its Head; remote ones show a body; pitch is not replicated) (owner simulates, MultiplayerSynchronizer replicates) and the drunk model (lag, sway, trips).
- `scripts/ui/`: `hud.gd`, `shaky_bar.gd` (steady-hands mini-game), `drunk_fx.gd` (blur/double vision/blackout shader), `kebab_panel.gd` (kebab minigame UI).
- `scripts/data/roles.gd`: role definitions and tuning (drunk level per role).
- `scripts/data/tuning.gd` (`Tuning`): centralized static balance parameters, defaults(), apply(), and reset().
- `scripts/data/nights.gd` (`Nights`): campaign night definitions (legs, hazards, kebab shop on/off, part radius, Tuning overrides).

Parts are physical: hold left mouse to lift, release over the glowing slot to fit (quality = distance, angle, speed). Held part is a spring on a mass (`Player._hold`), arms tire (`strain`), non-Mechanics also tire and pass out (`Game._tire`). Loose fits fall off. The Mechanic alone sees the HUD compass. Checklist, compass, crosshair are drawn controls in `scripts/ui/part_*.gd`.

## Tuning and Nights Usage
- `Tuning.defaults()` returns default dictionary of 42 balance parameters.

## Car, fx, props and the stumble rule
- `scripts/world/car_model.gd` (`CarModel`): `build()` makes the low-poly car (EngineBay, HeadlightL/R, Exhaust markers, "Body" collider); `set_repair(car, t)` goes rust to paint.
- `scripts/world/car_fx.gd` (`CarFx`): child of the car; smoke, sparks, exhaust puff, shake. World drives `set_repair`, `spark_burst` on each fitted part and `engine_start` when all are in.
- `scripts/world/yard_props.gd` (`YardProps`): `build(yard_seed, keep_clear)` scatters fence and junk, avoiding the car, parts and coolers.
- Stumble rule: tripping risk builds while moving fast. A warning shows for about 1.2 s (camera rolls, HUD says "WHOA... easy there"); slow down in that window to avoid the fall. `Player.stumble_warn` mirrors `Drunk.is_warning()`.
- `Tuning.apply(overrides)` applies dictionary of tuning changes; `Tuning.reset()` restores defaults.
- `Nights.get_night(i)` retrieves configuration for night index `i` (night 1 = 0, night 2 = 1).
- `Nights.apply_tuning(i)` applies tuning overrides for that night across all connected peers.

Gotchas learned:
- A MultiplayerSynchronizer must be created in `_enter_tree` (not `_ready`) or the spawner can't register it.
- Test scripts run with `-s` compile before autoloads exist: don't reference global classes that touch `Game`/`Net` (like `Drive`) in a test's type annotations; use untyped vars.
- Large heredocs in the shell tool can break on quotes; write big files with the file-write tool.

Two games live in this repo and are not yet joined (found 2026-10-25):
- Online co-op game: `scenes/main.tscn` -> `main.gd` -> `World`, with `Game`/`Net` and `scripts/player/player.gd`. Only the tests load it; the project main scene does not.
- Offline casino game: `splash_screen` -> `home_screen` -> `scenes/feature_main.tscn`, with `scripts/player.gd` (no class_name, owns `player_money` and the wallet panel), `scripts/minigames/` (darts, cup pong, slots, roulette) and `pub_casino.tscn` (placed at 0,0,-32). Scenes are generated by `scripts/build_world.gd`. No networking.
- The casino, its minigames and the money must be ported into the networked game. `.factory/worktrees/` holds stale copies of the project; ignore it when searching.

## City, economy and deliveries (built 2026-10-25)
The planned loop above now exists in the networked game (`World`, `Game`), not the offline casino game.
- Money: shared pool `Game.money`, host is the bank. `PartsShop` prices (parts total $4000), parts terminal at the car. Casino rounds are stake then payout (`s_stake`, `s_payout`, per-game max multiplier), so a payout needs a real stake. Corner shops: `ShopItems`, `s_buy_item`.
- City: `CityLayout` (pure logic: 16x16 blocks, seeded, random casino block, home 9-14 blocks away, landmark lots, route), `CityBuilder` (streams blocks around viewers, 2 per frame), car park is the world origin. `Drive.setup` takes a route from the city; without one it still makes its own (tests use that).
- Casino: `Casino` wraps `pub_casino.tscn` with 4 tables as `Interactable`s; `Player` has compatibility members (`head`, `camera`, `player_money`, ...) because the minigames expect the offline player. Roulette spin and darts are local-only, others just do their own thing. The offline game (`scripts/player.gd`, `feature_main.tscn`) is untouched.
- Deliveries: `Deliveries` (board, pay, tips), host-owned job/seats in `Game`, `Scooter` (driver simulates, others follow), pillion parcel balance in `Player._balance_parcel` (A/D), `DeliverySite` (scooter, board, parcel, beacon), job events (leak, hurry, reroute).
- Houses: one in four is hollow with a doorway (`CityBuilder._open_house`); the rest are solid boxes. Checkpoints: `Hazards` kind `checkpoint` (slow right down or wanted +25).
- Traffic: `CityTraffic` (child of `CityBuilder`, `city.traffic`): up to 24 cars near viewers, drive on the right, follow at a safe gap, stop on red/amber, turn at junctions (left turns wait for a gap), brake for people and scooters. Each peer simulates its own cars; signals run on wall-clock time so they agree. A moving car that touches the local player calls `Player.knock`. Signals cycle NS green, amber, all red, EW green, amber, all red. Trees, poles, lamps and parked cars have colliders (`CityBuilder.collider`). Off during the drive home.
- New tests: `traffic_test`, `casino_test`, `city_layout_test`, `city_builder_test`, `deliveries_test`, `delivery_test`, `shops_test`. Test scripts must not type-annotate `Player`, `Casino`, `Scooter` etc. (they touch `Game`).
- Not done / unverified: balance numbers (pay, prices, gambling edge) are first guesses; scooter feel and the city at real frame rate are only spot-checked by screenshots; `yard_props.gd` is now unused (kept, ask before deleting); role text in `roles.gd` still talks about scavenging; `Nights` titles are placeholders; EOS items above are unchanged.

## Credentials (never commit)
- `eos_credentials.cfg` at the project root holds product/sandbox/deployment/client IDs and the client secret. It is git-ignored. The values were given in chat; if this repo is ever shared with the chat history, rotate the client secret in the Developer Portal.
- Plugin binaries (`addons/epic-online-services-godot/bin/`) are git-ignored because they include Epic's SDK. A fresh clone needs the EOSG 2.3.1 Windows release's `bin/` folder copied in (see README).

## Status (as of 2026-10-23)
Done and tested headless:
- `tests/smoke_solo.gd`: full solo campaign (night 1 win, advance to night 2, hazard events, kebab shop, night 2 retry and lobby reset), all checks pass.
- `tests/mp_test.gd` (host + client, two processes, ENet): full multiplayer flow including spawner replication, position sync, car streaming, hazard hit replication, kebab open replication, win.
- `tests/tuning_test.gd`: balance parameter defaults, runtime overrides, and reset checks pass.
- `tests/nights_test.gd`: night definitions, route lengths, hazard counts, and tuning overrides pass.
- `tests/hazards_test.gd`: deterministic hazard layout, telegraphs, and collision checks pass.
- `tests/kebab_test.gd`: kebab order generation, misclick probability, and scoring pass.
- `tests/audio_test.gd`: audio buses, hazard/kebab/game event hook counts, HUD voice indicator pass.
- `tests/voice_test.gd`: voice chat controls, push-to-talk state transitions, offline no-op pass.
- `tests/eos_check.gd`: EOS SDK init and anonymous login work with the saved credentials.

Open:
1. **EOS lobby creation returns `AccessDenied`.** Fix in the Epic Developer Portal: Product Settings, Clients, edit the client's policy to allow Lobbies, P2P and Connect (a Peer2Peer or GameClient preset may do it). Then run `tests/eos_check.gd`. EOS P2P with real clients is still unverified (two processes on one PC share a device ID, so test from two machines or two accounts).
2. Voice chat EOS RTC room unverified on real EOS until developer portal policy is updated.
3. Never run with a real window: shader blur, camera feel and HUD layout are unchecked. All art is blockout boxes.

## Run and test
```
godot --headless --path . -s res://tests/smoke_solo.gd
godot --headless --path . -s res://tests/mp_test.gd -- host     # plus the same with -- client in a second shell
godot --headless --path . -s res://tests/tuning_test.gd
godot --headless --path . -s res://tests/nights_test.gd
godot --headless --path . -s res://tests/hazards_test.gd
godot --headless --path . -s res://tests/kebab_test.gd
godot --headless --path . -s res://tests/audio_test.gd
godot --headless --path . -s res://tests/voice_test.gd
godot --headless --path . -s res://tests/eos_check.gd
```
Play: open the project in Godot, run, choose Practice solo (all four roles) or Host/Join LAN with two instances.

## Working rules for this project
- Critique an idea before agreeing: name its biggest flaw first, then offer a better alternative.
- After any fix, run it or its tests before saying done.
- Ask before deleting files, pushing, or spending money. Edit files, run tests, install packages freely.
- No AI/tool attribution in commits, PRs, docs, metadata or code comments.
