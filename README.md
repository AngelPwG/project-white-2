# WHITEOUT

A tiny roguelike bullet-hell game written in Odin. Survive escalating waves, choose a power-up between waves, defeat the wave-five boss, and continue in endless mode.

The default presentation is a 1280×720 arena with an optional fullscreen mode and configurable visual overlays.

## Run it

With Nix installed, enter the included development environment and run the game:

```sh
nix develop -f shell.nix
odin run .
```

Alternatively, install [Odin](https://odin-lang.org/) with its bundled Raylib vendor package, then run:

```sh
odin run .
```

For a release build:

```sh
odin build . -o:speed -out:whiteout
./whiteout
```

## Controls

- `WASD` or arrow keys: move
- Mouse: aim (or enable `K` in Options for `IJKL` keyboard aiming)
- The gun fires automatically while playing
- Left mouse click: dash after selecting the dash upgrade (temporary invulnerability; enemy bullets pass through)
- Configured parry input: time the selected key or `Right Click` inside the skill-check zone during an endless-mode warning (change it with `Up`/`Down` in Options; default `Q`; 2-second cooldown)
- `R`: restart after death
- Click a power-up card to choose it between waves
- `Enter`: start from the title screen
- On launch, `Enter` or `Space` advances the character's opening self-dialogue before the title screen
- `O`: open options; `B`: return to the title screen
- `E`: open the enemy encyclopedia from the title or game-over screen
- `F`: toggle fullscreen, `G`: toggle the arena grid, `P`: toggle FPS, `K`: toggle keyboard aim
- Options `Up`/`Down`: select a setting; `Left`/`Right` or `Enter`: change it; this includes background music, music volume, and effects volume
- `Esc`: quit

## Current scope

- One arena with three weapons: pistol, shotgun, and burst rifle
- Waves begin with 5 enemies and add 2 enemies each wave
- Chaser, single-shot shooter, turret, dasher, bomber, and boss enemy behaviors
- A boss every fifth wave, followed by an endless mode
- Endless bombers are static, cannot be shot, and announce an incoming global blast; the configurable parry skill check is their only counter
- Volatile enemies chase the player, can be shot, and cause a smaller local explosion when destroyed
- Two power-up choices after every cleared wave
- Enemy encyclopedia discovery records and an end-of-run power-up report
- Persistent best score and discovered-enemy progress in `whiteout_save.dat`
- Background music selection for `music/bad_apple.mp3` and `music/reimus_theme.mp3`, with procedural fallback audio
- WAV sound effects loaded from `sound-effects/` for shooting, damage, and defeat
- Critical content notice: the protagonist's racism is presented as harmful, unreliable thinking; the geometric enemies are fictional entities
- Damage, healing, max-health, rapid-fire, speed, invulnerability, dash, and weapon unlock upgrades
- Two-hit enemies with distinct size and color accents
- One-second damage invulnerability with a blinking player indicator
- Increasing spawn pressure
- Health, score, collisions, game-over, and restart
- No runtime dependencies beyond Odin's Raylib package; the optional soundtrack files live in `music/`

The implementation deliberately uses fixed-size entity pools. That avoids allocator concerns during play and makes each entity type easy to inspect and extend. Gameplay is separated into small modules: `game.odin` owns run and wave state, `player.odin` owns movement and weapons, `enemies.odin` owns enemy kinds and wave composition, `bullets.odin` owns pools and reusable attack patterns, `collision.odin` owns rules, and `render.odin` owns presentation and the upgrade screen.

See [NEXT_STEPS.md](NEXT_STEPS.md) for an incremental roadmap.

For a beginner-oriented explanation of the Odin syntax, game loop, wave system, entity pools, and module responsibilities, read [ODIN_GAME_GUIDE.md](ODIN_GAME_GUIDE.md).
