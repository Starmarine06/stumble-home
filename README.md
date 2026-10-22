# 🍺 Stumble Home

**Four drunks. One broken car. Zero sense of direction.**

Stumble Home is a 4-player online co-op party game for 18+ players. The night is over, the car is wrecked, and all four of you are *very* drunk. Scrounge the junkyard for parts, fit them with shaky hands, then drive home before the cops catch up. Everyone has a job. Everyone is terrible at it. Nobody gets left behind. Probably.

> **Status:** playable vertical slice. One night (junkyard, then the drive home) works solo and with 2+ players over ENet; the EOS online path is wired but needs your Developer Portal client policy set up (see **EOS setup**).

---

## At a glance

| | |
|---|---|
| Genre | Co-op party / chaos game |
| Players | 4 (online, room code via EOS) |
| View | 3D third-person, low-poly cartoon |
| Engine | Godot 4.7 |
| Platform | Windows PC (v1) |
| Rating | 18+ (booze, swearing, slapstick) |
| Session | ~10-15 min per night |

---

## How a night works

**Part 1: the junkyard.** The car is dead. Four parts are scattered around the yard: **Battery, Fuel Pump, Spark Plugs, Spare Tyre**.

1. Grab a part (`E`). Drunk hands fumble it often, and every fumble raises the wanted level.
2. Carry it to the car and hand it over. Dropping it (`Q`) clangs and raises the wanted level.
3. The **Mechanic** fits delivered parts with a *steady hands* mini-game.
4. Water coolers sober you up a little, for a while.
5. All four fitted: the engine coughs to life and everyone piles in.

**Part 2: the drive home.** Follow a route of 90-degree turns through the city to the house with the light on.

- The **Driver** steers. The steering wanders, lags and hiccups, and sometimes they nod off for a second.
- Only the **Navigator** sees the route, and their arrows flicker between true and wrong.
- The engine overheats now and then. The **Mechanic** has to cool it with shaky hands.
- Cops show up. Only the **Lookout** sees them coming and has to steady up and signal in time.
- Miss a turn and you hit the buildings. Leave the road and the car takes damage.

**Win:** the car reaches home. **Lose:** the wanted level fills up (arrested) or the car dies.

---

## The four drunks

Everyone is very drunk. Each of you is drunk in a different way and has a different job. Pick one in the lobby; unclaimed roles are handed out automatically (with fewer than 4 players, some of you play two).

| Role | Drunk type | Junkyard perk | Drive job |
|---|---|---|---|
| **Driver** | The Sloppy | Strongest arms: carries parts at full speed and fumbles less | Steer the car home. Wandering steering, input lag, hiccups, nodding off |
| **Navigator** | The Blabber | Part compass pointing at the nearest missing part (it wobbles) | Reads the route. Arrows flicker, so shout what you see and trust the majority |
| **Mechanic** | The Shaky | The only one who can fit parts | Cools the overheating engine with a shaky mini-game |
| **Lookout** | The Paranoid | Part sense: parts glow within 25 m | Spots cops before they spot you and signals in time |

### How drunk is drunk?

Every player runs the same drunk model, scaled by their role:

- **Laggy input:** you move where you *meant* to go a moment ago.
- **Wandering steering:** your direction drifts on a noise curve; you sway even when standing still.
- **Random trips:** you fall over every few seconds and need a moment to get back up.
- **Fumbled grabs:** about 7 in 10 pickups fail (about 5 in 10 for the Driver).
- **Wobbly vision:** blur, double vision, screen sway and blackouts, all stronger the drunker you are.
- **Shaky mini-games:** the cursor jitters and lags, and the sweet spot shrinks.

Failures are meant to be funny and fair: the team can always cover for each other, and water coolers give you a short breather.

---

## Controls

| Key | Action |
|---|---|
| `WASD` / arrows | Move / steer |
| `E` | Grab, hand over, fit part, drink, steady-hands hit, signal |
| `Q` | Drop what you're carrying |

---

## Multiplayer

- 4 players, online, joined by a **room code**.
- Powered by **Epic Online Services (EOS)** through [EOSG](https://github.com/3ddelano/epic-online-services-godot) (MIT, Godot 4.2+):
  - **Lobbies** hold the room code (the lobby ID is `SH` + 5 characters) and the player list.
  - **P2P** (`EOSGMultiplayerPeer`) carries gameplay traffic, with Epic's relay as the fallback so nobody has to port-forward.
  - **Anonymous device-ID login:** no Epic account needed.
  - **Voice:** the lobby is created with an RTC room so voice chat can be enabled (falls back to no voice if the portal doesn't allow it).
- The host is the referee. Clients send requests (grab, deliver, fit, signal) and the host validates and broadcasts the result. Player movement is owned by each player's own machine.
- There is also a plain ENet backend (Host LAN / Join LAN in the menu) for local testing.
- Co-op only, no PvP.

---

## EOS setup

1. In the [Epic Developer Portal](https://dev.epicgames.com/portal/) create a product and a client.
2. Give the client a **client policy that allows Lobbies, P2P and Connect (device ID login)**. If lobby creation fails with `AccessDenied`, this is the setting to fix.
3. Put your IDs in a local `eos_credentials.cfg` at the project root (git-ignored, never commit it):

```ini
[eos]
product_name="Stumble Home"
product_id=""
sandbox_id=""
deployment_id=""
client_id=""
client_secret=""
```

---

## Building and running

Requires **Godot 4.7+** (4.2 is the plugin minimum).

1. Clone this repo.
2. Download the EOSG **2.3.1** Windows release from the [EOSG releases page](https://github.com/3ddelano/epic-online-services-godot/releases/tag/2.3.1) and copy its `addons/epic-online-services-godot/bin/` folder into this repo's `addons/epic-online-services-godot/`. The binaries include Epic's SDK, so they're git-ignored and not stored here.
3. Create `eos_credentials.cfg` (see **EOS setup**).
4. Open the project in Godot and run it. Use **Practice solo** to try everything alone, or **Host LAN / Join LAN** with two instances.

### Tests

```
godot --headless --path . -s res://tests/smoke_solo.gd    # full solo night
godot --headless --path . -s res://tests/mp_test.gd -- host     # run with ...
godot --headless --path . -s res://tests/mp_test.gd -- client   # ... in a second terminal
godot --headless --path . -s res://tests/eos_check.gd     # live EOS sign-in + room creation
```

---

## Roadmap

- [x] Lobby, role claiming, room codes (EOS) and LAN testing
- [x] Junkyard: parts, carrying, delivery, fitting, wanted level
- [x] Drive home: drunk steering, route, overheating, cops
- [x] Drunk model: lag, sway, trips, fumbles, vision effects, mini-games
- [ ] Verify EOS lobby + P2P end to end with real clients
- [ ] Voice chat through the EOS RTC room
- [ ] Real art, audio and animation (everything is blockout right now)
- [ ] More nights: new districts, traffic, dogs, muggers, mini-games like the kebab shop
- [ ] Balance pass with real playtesters
- [ ] Store page and release

---

## Contributing

Playtests, ideas and pull requests are welcome. Open an issue with your best drunk-story-inspired mechanic.

---

*Please drink responsibly in real life. In Stumble Home, we make no such promises.*
