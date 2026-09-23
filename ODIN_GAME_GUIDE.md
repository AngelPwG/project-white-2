# WHITEOUT: Odin and Game Architecture Guide

This guide explains the Odin language features used by WHITEOUT and how those features combine to make the game run. It assumes basic programming knowledge but not previous Odin experience.

## Running the project

```sh
nix develop -f shell.nix
odin run .
```

For a compiled executable:

```sh
odin build . -o:speed -out:whiteout
./whiteout
```

Every `.odin` file belongs to the same `main` package. Odin compiles the package as one program; the separate files are for organization, not separate libraries.

## Odin basics used here

### Packages and imports

Every file begins with `package main`. Raylib is imported with an alias:

```odin
import rl "vendor:raylib"
```

The alias lets the code write `rl.Vector2`, `rl.DrawText`, and `rl.IsKeyDown`.

### Constants and variables

Odin uses `::` for compile-time declarations:

```odin
SCREEN_W :: 1280
PLAYER_SPEED :: 260.0
```

Use `:=` for type inference and `:` for an explicit type:

```odin
dt := min(rl.GetFrameTime(), MAX_FRAME_TIME)
game: Game
choice: i32 = -1
```

The project commonly uses `i32` for counts, `f32` for positions and timers, and `bool` for state.

### Procedures

Odin calls functions *procedures*. A declaration includes the name, parameters, and optional return type:

```odin
enemies_in_wave :: proc(wave: i32) -> i32 {
    return 5 + (wave - 1) * 2
}
```

There is no implicit `this` object. State is passed explicitly, which makes each game system easy to locate.

### Structs and enums

Structs group data. `Bullet` stores everything needed by one projectile:

```odin
Bullet :: struct {
    active: bool
    pos: rl.Vector2
    vel: rl.Vector2
    radius: f32
    kind: Bullet_Kind
}
```

Enums represent named choices:

```odin
Weapon_Kind :: enum { Pistol, Shotgun, Burst }
Run_Phase :: enum { Title, Options, Playing, Paused, Upgrade, GameOver }
```

When the type is known, an enum value uses a leading dot: `game.weapon = .Pistol`.

### Pointers and mutation

Update procedures receive a pointer to the game:

```odin
update :: proc(game: ^Game, dt: f32) { ... }
```

`^Game` means “pointer to a `Game`.” `game^` dereferences it. The caller passes `&game` so the procedure changes the original value:

```odin
game: Game
reset_game(&game)
```

This avoids copying the complete game state and its entity arrays.

### Arrays and fixed pools

Entities use fixed arrays: `bullets: [512]Bullet` and `enemies: [128]Enemy`. Each slot has an `active` flag. Spawning finds an inactive slot; destroying an entity sets the flag to false. This avoids allocations during play.

Iteration by value reads a copy. Iteration with `&` edits the real array element:

```odin
for &bullet in game.bullets {
    bullet.active = false
}
```

The range `0..<count` includes zero and excludes `count`: `for i in 0..<count { ... }`.

## The real-time game loop

The entry point is in [main.odin](main.odin):

```odin
for !rl.WindowShouldClose() {
    dt := min(rl.GetFrameTime(), MAX_FRAME_TIME)
    update(&game, dt)
    draw(&game)
}
```

Each frame follows this sequence:

```text
read input -> update rules -> resolve collisions -> draw current state -> repeat
```

`dt` is elapsed time in seconds. Movement multiplies speed by `dt`, making speed independent of frame rate. The maximum frame time prevents a long pause from moving entities too far in one update.

The project keeps `update` and `draw` separate. Update procedures change state; render procedures only read state and issue Raylib drawing calls.

## Game phases and menus

`Game.phase` is a state machine:

| Phase | Input | Behavior |
| --- | --- | --- |
| `Dialog` | Enter or Space | Advance the two-line opening self-dialogue; music begins when it ends |
| `Title` | Enter, O, E | Start, open options, or view the encyclopedia |
| `Options` | F, G, P, K, arrows, B | Change settings or return |
| `Playing` | Movement, aim, fire | Run the simulation |
| `Paused` | P, Enter, T, mouse | Freeze combat, resume, or return to title |
| `Upgrade` | Mouse click | Choose a power-up card |
| `GameOver` | R, E | Restart or review the run and encyclopedia |

`update` checks the phase before gameplay. Therefore enemies and bullets pause while the upgrade overlay or pause menu is visible. `render.odin` uses the same phase to choose the title screen, options screen, arena, upgrade overlay, pause menu, or game-over overlay.

The encyclopedia records enemy types when they are spawned. The game-over report preserves the current run's power-up counts, names, and descriptions so the player can see how that build was assembled.

The protagonist is an unreliable narrator whose racist worldview is criticized rather than endorsed. The title provides the content framing, while the end-of-run reflection lets the character recognize that his conclusions were wrong. The encyclopedia stays focused on enemy mechanics and attack patterns.

## Player, weapons, and upgrades

`player.odin` reads movement keys, normalizes the direction, and applies movement. The weapon fires whenever its timer reaches zero; there is no mouse-button gate. Mouse aiming is the default, while the Options toggle switches to `IJKL` aiming.

```odin
move = normalized(move)
game.player_pos = vec_add(game.player_pos, vec_scale(move, PLAYER_SPEED * dt))
```

Normalization prevents diagonal movement from being faster than horizontal movement.

The weapon switch provides:

- `Pistol`: one fast bullet.
- `Shotgun`: a three-projectile fan with a longer cooldown.
- `Burst`: a faster three-projectile fan.

Weapon firing calls helpers from [bullets.odin](bullets.odin), keeping weapon choices separate from pool management.

Power-ups are values of `Upgrade_Kind`. `apply_upgrade` changes persistent run state: damage, fire interval, health, maximum health, movement speed, invulnerability duration, or weapon. Player stats such as `move_speed`, `shot_speed`, `player_size`, and `invulnerability_duration` live on `Game`, so upgrades can change them during a run without changing compile-time constants.

`player_size` remains the visible square size. `player_hitbox_size` is a smaller, conservative collision rectangle used by `collision.odin`, which gives the Micrododge encounter readable gaps without making the player visually tiny.

The `Dash` upgrade enables left mouse click. A short `dash_timer` moves the player quickly along the current movement direction (or aim direction when standing still) and temporarily extends invulnerability; `dash_cooldown` prevents continuous use. Collision handling checks this timer before testing enemy bullets, so bullets pass through without being consumed and continue traveling.

## Waves, encounters, bosses, and endless mode

The wave layer is now a small director rather than one growing enemy count:

```text
Run -> Wave -> Encounter -> Formation -> Enemy pattern -> Bullet
```

`encounters.odin` builds a fixed-size `encounter_plan` for each wave. `start_wave` resets the director, `update_encounter_director` starts one authored formation at a time, and `encounter_has_active_enemies` detects when that situation is clear. A short `ENCOUNTER_PAUSE` separates encounters before the next one starts. Once the plan is exhausted, the existing `Upgrade` phase is still used.

The first waves are deliberately pedagogical: Streaming appears first, Ring Cage follows, then Micrododge, Chaser Pressure, Spiral, and Crossfire are combined. Later waves use a run seed plus `wave_threat_budget` and `encounter_cost` to select from the same library without randomizing individual bullets. The budget grows from the early 3-cost plans to a capped late value of 11, and the existing encounter formations add complementary roles at higher Waves. The director avoids immediate repetition when it has room to choose another block.

Wave five starts a boss after its encounter plan. `Boss_Phase_Kind` is an explicit four-state machine: rotating rings from a central home position, aimed bursts while moving smoothly across the central lane, a central spiral, and a final combination with a small central orbit. The boss enters from above and has a short firing delay so the player can identify its position. Later boss waves tighten cadence modestly and gain health in proportion to player damage. After the boss wave, the existing endless mode continues without another boss and retains the bomber/parry mechanic.

To add an encounter, add an `Encounter_Kind`, then extend `encounter_cost`, `encounter_min_time`, `encounter_name`, the wave plan, and `spawn_encounter_formation` in `encounters.odin`. The formation should name the movement problem it creates. Add a reusable bullet constructor to `bullets.odin` only when an existing constructor is not enough; keep enemy behavior in `enemies.odin`.

## Enemy behavior

All enemies share the `Enemy` struct but branch on `Enemy_Kind`:

- `Chaser` moves toward the player and fires a fan.
- `Shooter` is a smaller black chaser that follows the player and fires one direct bullet at a time. It appears in authored Streaming and Crossfire formations; later mutation tiers change it to short bursts or aimed fans.
- `Turret` stays in place and fires a ring. Its `Enemy_Mutation_Kind` can turn that emitter into a rotating ring, alternating ring, or spiral emitter.
- `Dasher` advances with sideways oscillation and fires faster fans.
- `Bomber` is a static, invulnerable parry target. Its fuse triggers a global arena-wide blast, while a successful skill check removes it safely.
- `Volatile` chases the player and can be destroyed by shooting it; its death (or contact) triggers a smaller local area explosion.
- `Boss` uses the central arena as a predictable spatial anchor, has scaling health, and uses the four phases shown above.

To add an enemy, update the enum, initialize its health and position, add movement and firing cases, then add its size and color. Finally place it deliberately in an encounter formation. This is a data-plus-switch pattern: shared lifecycle, specialized behavior.

## Bullets and collision rules

`bullets.odin` owns the bullet pool and reusable pattern procedures:

- `fire_fan` rotates a direction by several angles.
- `fire_ring` distributes bullets evenly around a circle, while `fire_ring_offset` lets the emitter rotate a later ring without adding per-bullet state.
- `fire_spiral` emits one bullet at a persistent angle.

`collision.odin` is the single place that decides what a hit means:

1. An enemy bullet hitting the player consumes the bullet and calls `damage_player`.
2. A player bullet reduces enemy health by `game.damage`.
3. An enemy is removed and score increases when health reaches zero.
4. Contact with an enemy damages the player and removes that enemy.
5. A bomber uses `detonate_bomber_at` for a global blast; a volatile uses `detonate_volatile_at` for its smaller death blast.

The boss is the exception to the contact rule: it damages the player but remains active, so the player must keep dodging it until it is defeated.

The player receives one second of invulnerability after damage. The timer is checked by the collision rule and represented visually by blinking in `draw_player`.

The Bomber parry separates total warning time from the effective success window. `PARRY_WARNING_START`, `PARRY_WARNING_STEP`, and `PARRY_WARNING_MIN` control how early the warning becomes; `PARRY_SUCCESS_DURATION` controls the actual timing challenge and is kept at 0.30 seconds by default. The normalized skill bar therefore becomes wider as the warning shortens instead of becoming a sub-frame reflex test.

## Rendering and Raylib

`render.odin` contains presentation only. Raylib draws the arena using primitives: a dark background, grid, stars, border, circles, lines, rectangles, triangles, text, and overlays. No external art assets are required.

Raylib uses `Vector2` for positions and velocities. [math.odin](math.odin) keeps vector operations readable through helpers such as `vec_add`, `vec_sub`, `vec_scale`, `normalized`, and `rotate`.

When adding a visual effect, put the drawing in `render.odin` and store only the minimum required state in `Game` or an entity.

## Audio

`audio.odin` loads the selectable tracks in `music/` through Raylib's `Music` streaming API and loads `plshoot.wav`, `damage.wav`, and `pldead.wav` from `sound-effects/`. Music is held during the opening dialog and starts when the dialog transitions to the title screen. The Options screen uses its highlighted selector and Left/Right to switch tracks or adjust music/effects volume immediately. If a file is invalid, generated audio remains as a fallback. `main.odin` owns initialization and cleanup, while gameplay modules only call small event procedures such as `play_shoot_sound`.

## How to extend the game safely

### Add a power-up

1. Add a value to `Upgrade_Kind`.
2. Add its label in `upgrade_name`.
3. Add its behavior in `apply_upgrade`.
4. Include it in `prepare_upgrade`.

### Add a weapon

1. Add a `Weapon_Kind` value.
2. Add its firing branch in `player.odin`.
3. Add its label in `weapon_name`.
4. Add a power-up that selects it.

### Add an enemy

1. Add an `Enemy_Kind` value.
2. Return its health and size from `enemies.odin`.
3. Add movement and firing behavior.
4. Add its render shape and color.
5. Include it in an intentional `spawn_encounter_formation` case (and keep `wave_enemy_kind` only if a legacy fallback needs it).

After each small change, run:

```sh
odin check .
odin build . -out:/tmp/whiteout-check
```

`odin check` catches syntax and type errors without producing an executable. The build command verifies that the complete program links successfully.

## Module map

| File | Responsibility |
| --- | --- |
| `main.odin` | Window setup and main loop |
| `game.odin` | Shared state, phases, rewards, and run-wide settings |
| `encounters.odin` | Authored encounter library, wave plans, formations, transitions, and threat budget |
| `player.odin` | Movement and weapon firing |
| `enemies.odin` | Enemy spawning and AI |
| `bullets.odin` | Bullet pool and firing patterns |
| `collision.odin` | Damage, hits, defeat, and score |
| `render.odin` | Menus, HUD, arena, entities, effects |
| `math.odin` | Vector and rectangle helpers |
| `save.odin` | Best score and encyclopedia persistence |
| `audio.odin` | Procedural music, sound effects, and audio lifecycle |

The separation is intentionally direct: start with the module named in the table, then follow calls into `game.odin` or the shared math and bullet helpers.

## Persistent progress

`save.odin` stores a small versioned text file named `whiteout_save.dat` beside the executable. It contains the best score and seven discovery flags (including the bomber and volatile). The loader treats a missing, old, or malformed file as empty progress. A new best score is written when a run ends, and discovering a new enemy writes immediately so the encyclopedia is not lost if the game closes later.
