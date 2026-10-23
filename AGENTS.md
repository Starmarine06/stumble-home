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
- `Tuning.defaults()` returns default dictionary of 38 balance parameters.
- `Tuning.apply(overrides)` applies dictionary of tuning changes; `Tuning.reset()` restores defaults.
- `Nights.get_night(i)` retrieves configuration for night index `i` (night 1 = 0, night 2 = 1).
- `Nights.apply_tuning(i)` applies tuning overrides for that night across all connected peers.

Gotchas learned:
- A MultiplayerSynchronizer must be created in `_enter_tree` (not `_ready`) or the spawner can't register it.
- Test scripts run with `-s` compile before autoloads exist: don't reference global classes that touch `Game`/`Net` (like `Drive`) in a test's type annotations; use untyped vars.
- Large heredocs in the shell tool can break on quotes; write big files with the file-write tool.

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
