# Build log: night 2, hazards, kebab shop, audio, voice

Branch: `factory/integration` (not merged into `main` yet).
Date: 2026-10-23. 11 tasks, 10 feature commits, 39 files changed (+2517 / -394).

## What was added

| Task | What it does | Main files |
|---|---|---|
| baseline | Confirmed the headless tests pass after the feature merge, before any new work | none |
| tuning | All balance numbers (trip interval, fumble rate, cop and overheat timers) moved into one `Tuning` class so night definitions can override them | `scripts/data/tuning.gd`, `tests/tuning_test.gd` |
| audio-core | `Audio` autoload with Master/SFX/Music/Voice buses and an event registry hooked to Game signals | `scripts/autoload/audio.gd`, `tests/audio_test.gd` |
| voice-core | Voice chat over the EOS lobby RTC room: speaking flags, mute, push to talk, HUD indicator | `scripts/autoload/voice.gd`, `scripts/autoload/net.gd`, `tests/voice_test.gd` |
| hazards-core | Street hazards (traffic, dogs, muggers) planned deterministically from the drive seed, with telegraphs | `scripts/world/hazards.gd`, `tests/hazards_test.gd` |
| kebab-core | Kebab-shop mini-game logic and its UI panel | `scripts/minigames/kebab.gd`, `scripts/ui/kebab_panel.gd`, `tests/kebab_test.gd` |
| nights-data | Night definitions including night 2: title, flavour line, drive legs, hazards, kebab flag, tuning overrides | `scripts/data/nights.gd`, `tests/nights_test.gd` |
| hazards-wire | Hazards built on every peer from the shared seed; the host referees hits | `scripts/world/drive.gd`, `scripts/autoload/game.gd` |
| kebab-wire | A kebab shop beside the route; stopping the car in its zone opens the mini-game | `scripts/world/drive.gd`, `scripts/world/world.gd`, `scripts/autoload/game.gd` |
| nights-wire | Campaign flow: pick a night, advance to the next, retry from the result screen | `scripts/autoload/game.gd`, `scripts/main.gd`, `scripts/world/*` |
| final-integration | Audio events for hazards and kebab, voice hooks, multiplayer test coverage, docs | `scripts/autoload/audio.gd`, `scripts/ui/hud.gd`, `tests/mp_test.gd`, `AGENTS.md` |

Independent modules (audio, voice, hazards, kebab, nights data) were built in parallel in separate git worktrees. The wiring tasks ran after them in dependency order. Each task needed a passing test gate and a passing review gate before it was merged.

## Verified

Run on a clean checkout of this branch with the headless Godot console build:

- `tests/smoke_solo.gd`: OK, 0 failures
- `tests/tuning_test.gd`: 0 failures
- `tests/audio_test.gd`, `hazards_test.gd`, `kebab_test.gd`, `nights_test.gd`, `voice_test.gd`: pass

## Not verified

- `tests/mp_test.gd` (host + client) was extended but not re-run after the final merge.
- EOS lobby creation still returns `AccessDenied` until the Developer Portal client policy is fixed (see `AGENTS.md`). Voice and any online path stay untested against real EOS.
- Nothing was run in a real window. Hazard visuals, kebab panel layout and audio feel are unchecked, and all art is still blockout.
- Balance numbers are unchanged and still untuned.

## Left out on purpose

An uncommitted "catch window" change to `scripts/player/drunk.gd` was found in the working tree. It made `smoke_solo` fail (13 failures) and was discarded.
