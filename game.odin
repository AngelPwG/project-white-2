package main

import rl "vendor:raylib"

SCREEN_W :: 1280
SCREEN_H :: 720
MAX_FRAME_TIME :: 0.033

DEFAULT_PLAYER_SIZE :: 24.0
DEFAULT_PLAYER_HITBOX :: 12.0
DEFAULT_PLAYER_SPEED :: 260.0
DEFAULT_SHOT_SPEED :: 620.0
ENEMY_SPEED :: 74.0

DEFAULT_FIRE_INTERVAL :: 0.30
MIN_FIRE_INTERVAL :: 0.12
MIN_ENEMY_FIRE_INTERVAL :: 0.10
RAPID_FIRE_STEP :: 0.045
DEFAULT_INVULNERABILITY_DURATION :: 1.15
DEFAULT_DASH_COOLDOWN :: 2.0
DASH_DURATION :: 0.16
DASH_SPEED :: 720.0
BOMBER_BLAST_RADIUS :: 105.0
BOMBER_GLOBAL_BLAST_RADIUS :: 2000.0
PARRY_WARNING_START :: 1.4
PARRY_WARNING_STEP :: 0.08
PARRY_WARNING_MIN :: 0.75
PARRY_SUCCESS_DURATION :: 0.30
PARRY_SUCCESS_ZONE_START :: 0.50
PARRY_COOLDOWN :: 2.0

ENEMY_CHASER_BASE_HP :: 8
ENEMY_SHOOTER_BASE_HP :: 10
ENEMY_TURRET_BASE_HP :: 14
ENEMY_DASHER_BASE_HP :: 8
ENEMY_VOLATILE_BASE_HP :: 6
ENEMY_BOSS_BASE_HP :: 150
ENEMY_HP_WAVE_STEP :: 0.5
BOSS_HP_WAVE_STEP :: 10
BOSS_HP_DAMAGE_STEP :: 35
BOSS_HOME_Y :: 290.0
BOSS_MOVE_RADIUS :: 240.0
BOSS_FINALE_RADIUS :: 135.0
BOSS_INTRO_DURATION :: 1.15
BOSS_ROTATING_RING_DURATION :: 7.0
BOSS_AIMED_BURST_DURATION :: 7.5
BOSS_SPIRAL_DURATION :: 8.0
BOSS_MIN_PHASE_DURATION :: 5.5
BOSS_PHASE_TIER_STEP :: 0.35
BOSS_MAX_BULLET_SPEED :: 240.0
Parry_Input :: enum { Q, E, R, F, Right_Mouse }
PARRY_KEYS :: [5]Parry_Input{.Q, .E, .R, .F, .Right_Mouse}
OPTIONS_COUNT :: 8

ENEMY_FAN_ANGLES :: [3]f32{-0.18, 0, 0.18}
SHOTGUN_ANGLES :: [3]f32{-0.14, 0, 0.14}
BURST_ANGLES :: [3]f32{-0.08, 0, 0.08}

ENCOUNTER_START_DELAY :: 0.65
MAX_WAVE_ENCOUNTERS :: 6

Bullet_Kind :: enum { Player, Enemy }
Enemy_Kind :: enum { Chaser, Shooter, Turret, Dasher, Bomber, Volatile, Boss }
Weapon_Kind :: enum { Pistol, Shotgun, Burst }
Run_Phase :: enum { Dialog, Title, Options, Encyclopedia, Playing, Upgrade, GameOver }
Upgrade_Kind :: enum { Heal, Damage, RapidFire, Shotgun, Burst, MaxHealth, Speed, Invulnerability, Dash }
Encounter_Kind :: enum { Streaming, Ring_Cage, Spiral, Micrododge, Chaser_Pressure, Crossfire }
Encounter_State :: enum { Between, Active, Complete }
Enemy_Mutation_Kind :: enum { None, Rotating_Ring, Alternating_Ring, Spiral_Emitter, Short_Burst, Aimed_Fan }
Boss_Phase_Kind :: enum { Rotating_Rings, Aimed_Bursts, Spiral, Finale }

Bullet :: struct {
	active: bool,
	pos: rl.Vector2,
	vel: rl.Vector2,
	radius: f32,
	kind: Bullet_Kind,
}

Enemy :: struct {
	active: bool,
	kind: Enemy_Kind,
	pos: rl.Vector2,
	health: i32,
	shot_timer: f32,
	pattern_angle: f32,
	dash_timer: f32,
	explode_timer: f32,
	secondary_timer: f32,
	mutation: Enemy_Mutation_Kind,
	encounter_id: i32,
}

Game :: struct {
	audio: ^Audio_State,
	player_pos: rl.Vector2,
	health: i32,
	score: i32,
	best_score: i32,
	game_over: bool,
	phase: Run_Phase,
	dialog_page: i32,
	show_fps: bool,
	music_index: i32,
	keyboard_aim: bool,
	parry_key_index: i32,
	options_cursor: i32,
	endless_mode: bool,
	invulnerability_timer: f32,
	invulnerability_duration: f32,
	dash_unlocked: bool,
	dash_timer: f32,
	dash_cooldown: f32,
	dash_direction: rl.Vector2,
	shot_timer: f32,
	player_size: f32,
	player_hitbox_size: f32,
	move_speed: f32,
	shot_speed: f32,
	weapon: Weapon_Kind,
	damage: i32,
	max_health: i32,
	fire_interval: f32,
	spawn_timer: f32,
	spawn_count: i32,
	wave: i32,
	wave_enemy_target: i32,
	wave_spawned: i32,
	boss_spawned: bool,
	encounter_plan: [MAX_WAVE_ENCOUNTERS]Encounter_Kind,
	encounter_plan_count: i32,
	encounter_index: i32,
	encounter_kind: Encounter_Kind,
	encounter_state: Encounter_State,
	encounter_timer: f32,
	encounter_pause_timer: f32,
	encounter_stage: i32,
	encounter_spawned: i32,
	encounter_min_duration: f32,
	wave_director_done: bool,
	wave_threat_budget: i32,
	wave_threat_spent: i32,
	last_encounter_kind: Encounter_Kind,
	last_encounter_valid: bool,
	wave_variation: i32,
	composition_tier: i32,
	director_seed: i32,
	enemy_mutation_level: i32,
	boss_phase: Boss_Phase_Kind,
	boss_phase_timer: f32,
	boss_phase_index: i32,
	upgrade_options: [2]Upgrade_Kind,
	powerup_counts: [9]i32,
	discovered_enemies: [7]bool,
	parry_active: bool,
	parry_timer: f32,
	parry_cooldown: f32,
	parry_skill_position: f32,
	parry_skill_speed: f32,
	parry_skill_zone_start: f32,
	parry_skill_zone_end: f32,
	explosion_pos: rl.Vector2,
	explosion_timer: f32,
	explosion_radius: f32,
	explosion_global: bool,
	bullets: [512]Bullet,
	enemies: [128]Enemy,
}

reset_game :: proc(game: ^Game) {
	game^ = {}
	game.phase = .Dialog
	game.dialog_page = 0
	game.show_fps = true
	game.keyboard_aim = false
	game.parry_key_index = 0
	game.options_cursor = 2
	game.player_pos = {SCREEN_W / 2, SCREEN_H / 2}
	game.health = 7
	game.max_health = 7
	game.weapon = .Pistol
	game.damage = 1
	game.fire_interval = DEFAULT_FIRE_INTERVAL
	game.player_size = DEFAULT_PLAYER_SIZE
	game.player_hitbox_size = DEFAULT_PLAYER_HITBOX
	game.move_speed = DEFAULT_PLAYER_SPEED
	game.shot_speed = DEFAULT_SHOT_SPEED
	game.invulnerability_duration = DEFAULT_INVULNERABILITY_DURATION
	game.dash_cooldown = DEFAULT_DASH_COOLDOWN
}

start_run :: proc(game: ^Game) {
	audio := game.audio
	show_fps := game.show_fps
	music_index := game.music_index
	keyboard_aim := game.keyboard_aim
	parry_key_index := game.parry_key_index
	best_score := game.best_score
	discovered_enemies := game.discovered_enemies
	game^ = {}
	game.audio = audio
	game.show_fps = show_fps
	game.music_index = music_index
	game.keyboard_aim = keyboard_aim
	game.parry_key_index = parry_key_index
	game.best_score = best_score
	game.discovered_enemies = discovered_enemies
	game.phase = .Playing
	game.director_seed = i32(rl.GetRandomValue(0, 1000))
	select_music(game.audio, game.music_index)
	game.player_pos = {SCREEN_W / 2, SCREEN_H / 2}
	game.health = 7
	game.max_health = 7
	game.weapon = .Pistol
	game.damage = 1
	game.fire_interval = DEFAULT_FIRE_INTERVAL
	game.player_size = DEFAULT_PLAYER_SIZE
	game.player_hitbox_size = DEFAULT_PLAYER_HITBOX
	game.move_speed = DEFAULT_PLAYER_SPEED
	game.shot_speed = DEFAULT_SHOT_SPEED
	game.invulnerability_duration = DEFAULT_INVULNERABILITY_DURATION
	game.dash_cooldown = DEFAULT_DASH_COOLDOWN
	game.phase = .Playing
	game.wave = 1
	start_wave(game)
}

update :: proc(game: ^Game, dt: f32) {
	update_audio(game.audio)
	if game.phase == .Dialog {
		if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
			game.dialog_page += 1
			if game.dialog_page >= 2 {
				start_music(game.audio)
				game.phase = .Title
			}
		}
		return
	}
	if game.phase == .Title {
		if rl.IsKeyPressed(.ENTER) { start_run(game) }
		if rl.IsKeyPressed(.O) { game.phase = .Options }
		if rl.IsKeyPressed(.E) { game.phase = .Encyclopedia }
		return
	}
	if game.phase == .Options {
		update_options(game)
		return
	}
	if game.phase == .GameOver {
		if rl.IsKeyPressed(.R) {
			start_run(game)
		}
		if rl.IsKeyPressed(.E) { game.phase = .Encyclopedia }
		if rl.IsKeyPressed(.B) { game.phase = .Title }
		return
	}
	if game.phase == .Encyclopedia {
		if rl.IsKeyPressed(.B) { game.phase = .Title }
		return
	}
	if game.phase == .Upgrade {
		update_upgrade_selection(game)
		return
	}

	game.invulnerability_timer = max(0, game.invulnerability_timer - dt)
	game.explosion_timer = max(0, game.explosion_timer - dt)
	game.parry_cooldown = max(0, game.parry_cooldown - dt)
	update_parry(game, dt)
	update_player(game, dt)
	update_encounter_director(game, dt)
	update_enemies(game, dt)
	update_bullets(game, dt)
	handle_collisions(game)
	check_wave_complete(game)
	if rl.IsKeyPressed(.B) { game.phase = .Title }
}

update_options :: proc(game: ^Game) {
	if rl.IsKeyPressed(.B) {
		save_progress(game)
		game.phase = .Title
	}
	if rl.IsKeyPressed(.UP) {
		game.options_cursor -= 1
		if game.options_cursor < 0 { game.options_cursor = OPTIONS_COUNT - 1 }
	}
	if rl.IsKeyPressed(.DOWN) {
		game.options_cursor += 1
		if game.options_cursor >= OPTIONS_COUNT { game.options_cursor = 0 }
	}
	if rl.IsKeyPressed(.LEFT) { adjust_option(game, -1) }
	if rl.IsKeyPressed(.RIGHT) || rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) { adjust_option(game, 1) }
	// Keep the original shortcuts available for fast access.
	if rl.IsKeyPressed(.P) { game.show_fps = !game.show_fps }
	if rl.IsKeyPressed(.K) { game.keyboard_aim = !game.keyboard_aim }
}

adjust_option :: proc(game: ^Game, direction: i32) {
	switch game.options_cursor {
	case 2: game.show_fps = !game.show_fps
	case 3: game.keyboard_aim = !game.keyboard_aim
	case 4: change_parry_key(game, direction)
	case 5: change_music(game, direction)
	case 6: change_music_volume(game.audio, direction)
	case 7: change_effects_volume(game.audio, direction)
	}
}

change_parry_key :: proc(game: ^Game, direction: i32) {
	game.parry_key_index += direction
	if game.parry_key_index < 0 {
		game.parry_key_index = len(PARRY_KEYS) - 1
	}
	if game.parry_key_index >= len(PARRY_KEYS) {
		game.parry_key_index = 0
	}
}

current_parry_input :: proc(game: ^Game) -> Parry_Input {
	keys := PARRY_KEYS
	return keys[game.parry_key_index]
}

parry_key_name :: proc(game: ^Game) -> cstring {
	switch current_parry_input(game) {
	case .Q: return "Q"
	case .E: return "E"
	case .R: return "R"
	case .F: return "F"
	case .Right_Mouse: return "RIGHT CLICK"
	}
	return "?"
}

parry_input_pressed :: proc(game: ^Game) -> bool {
	switch current_parry_input(game) {
	case .Q: return rl.IsKeyPressed(.Q)
	case .E: return rl.IsKeyPressed(.E)
	case .R: return rl.IsKeyPressed(.R)
	case .F: return rl.IsKeyPressed(.F)
	case .Right_Mouse: return rl.IsMouseButtonPressed(.RIGHT)
	}
	return false
}

update_parry :: proc(game: ^Game, dt: f32) {
	if !game.endless_mode || !game.parry_active {
		return
	}
	game.parry_timer -= dt
	game.parry_skill_position += game.parry_skill_speed * dt
	if parry_input_pressed(game) && game.parry_cooldown <= 0 {
		game.parry_active = false
		game.parry_cooldown = PARRY_COOLDOWN
		if game.parry_skill_position >= game.parry_skill_zone_start && game.parry_skill_position <= game.parry_skill_zone_end {
			for &enemy in game.enemies {
				if enemy.active && enemy.kind == .Bomber {
					enemy.active = false
					game.score += 2
				}
			}
			play_hit_sound(game.audio)
		} else {
			for &enemy in game.enemies {
				if enemy.active && enemy.kind == .Bomber {
					position := enemy.pos
					enemy.active = false
					detonate_bomber_at(game, position)
					break
				}
			}
		}
		return
	}
	if game.parry_timer > 0 {
		return
	}
	game.parry_active = false
	for &enemy in game.enemies {
		if enemy.active && enemy.kind == .Bomber {
			position := enemy.pos
			enemy.active = false
			detonate_bomber_at(game, position)
			break
		}
	}
}

start_parry_warning :: proc(game: ^Game) {
	if !game.endless_mode || game.parry_active || game.parry_cooldown > 0 {
		return
	}
	game.parry_active = true
	game.parry_timer = max(PARRY_WARNING_MIN, PARRY_WARNING_START - f32(max(0, game.wave - 6)) * PARRY_WARNING_STEP)
	game.parry_skill_position = 0
	game.parry_skill_speed = 1.0 / game.parry_timer
	game.parry_skill_zone_start = PARRY_SUCCESS_ZONE_START
	game.parry_skill_zone_end = min(0.92, PARRY_SUCCESS_ZONE_START + PARRY_SUCCESS_DURATION / game.parry_timer)
}

change_music :: proc(game: ^Game, direction: i32) {
	if game.audio == nil || game.audio.music_track_count <= 0 {
		game.music_index = 0
		return
	}
	game.music_index += direction
	if game.music_index < 0 {
		game.music_index = game.audio.music_track_count - 1
	}
	if game.music_index >= game.audio.music_track_count {
		game.music_index = 0
	}
	select_music(game.audio, game.music_index)
}

damage_player :: proc(game: ^Game) {
	if game.invulnerability_timer > 0 {
		return
	}

	game.health -= 1
	game.invulnerability_timer = game.invulnerability_duration
	play_hit_sound(game.audio)
	if game.health <= 0 {
		game.game_over = true
		game.phase = .GameOver
		play_death_sound(game.audio)
		save_progress(game)
	}
}

enemies_in_wave :: proc(wave: i32) -> i32 {
	return 5 + (wave - 1) * 2
}

wave_has_boss :: proc(wave: i32) -> bool {
	return wave >= 5 && wave % 5 == 0
}

check_wave_complete :: proc(game: ^Game) {
	if !game.wave_director_done || !game.boss_spawned { return }
	for enemy in game.enemies {
		if enemy.active { return }
	}
	prepare_upgrade(game)
}

prepare_upgrade :: proc(game: ^Game) {
	game.phase = .Upgrade
	switch game.wave % 4 {
	case 0:
		game.upgrade_options = {Upgrade_Kind(.Damage), .Speed}
	case 1:
		game.upgrade_options = {Upgrade_Kind(.Shotgun), .RapidFire}
	case 2:
		game.upgrade_options = {Upgrade_Kind(.Heal), .Invulnerability}
	case 3:
		game.upgrade_options = {Upgrade_Kind(.Dash), .MaxHealth}
	}
}

update_upgrade_selection :: proc(game: ^Game) {
	choice: i32 = -1
	if rl.IsMouseButtonPressed(.LEFT) {
		mouse := rl.GetMousePosition()
		left_card := rl.Rectangle{f32((SCREEN_W / 2) - 285), 205, 270, 220}
		right_card := rl.Rectangle{f32((SCREEN_W / 2) + 15), 205, 270, 220}
		if rl.CheckCollisionPointRec(mouse, left_card) { choice = 0 }
		if rl.CheckCollisionPointRec(mouse, right_card) { choice = 1 }
	}
	if choice < 0 { return }

	apply_upgrade(game, game.upgrade_options[choice])
	game.wave += 1
	game.endless_mode = game.endless_mode || wave_has_boss(game.wave - 1)
	start_wave(game)
	game.phase = .Playing
}

apply_upgrade :: proc(game: ^Game, upgrade: Upgrade_Kind) {
	record_upgrade(game, upgrade)
	switch upgrade {
	case .Heal:
		game.health = min(game.max_health, game.health + 2)
	case .Damage:
		game.damage += 1
	case .RapidFire:
		game.fire_interval = max(MIN_FIRE_INTERVAL, game.fire_interval - RAPID_FIRE_STEP)
	case .Shotgun:
		game.weapon = .Shotgun
	case .Burst:
		game.weapon = .Burst
	case .MaxHealth:
		game.max_health += 1
		game.health += 1
	case .Speed:
		game.move_speed += 28
	case .Invulnerability:
		game.invulnerability_duration += 0.25
	case .Dash:
		game.dash_unlocked = true
		game.dash_cooldown = DEFAULT_DASH_COOLDOWN
	}
}

record_upgrade :: proc(game: ^Game, upgrade: Upgrade_Kind) {
	switch upgrade {
	case .Heal: game.powerup_counts[0] += 1
	case .Damage: game.powerup_counts[1] += 1
	case .RapidFire: game.powerup_counts[2] += 1
	case .Shotgun: game.powerup_counts[3] += 1
	case .Burst: game.powerup_counts[4] += 1
	case .MaxHealth: game.powerup_counts[5] += 1
	case .Speed: game.powerup_counts[6] += 1
	case .Invulnerability: game.powerup_counts[7] += 1
	case .Dash: game.powerup_counts[8] += 1
	}
}

upgrade_name :: proc(upgrade: Upgrade_Kind) -> cstring {
	switch upgrade {
	case .Heal: return "FIELD MEDIC"
	case .Damage: return "HEAVY ROUNDS"
	case .RapidFire: return "QUICK HANDS"
	case .Shotgun: return "SHOTGUN"
	case .Burst: return "BURST RIFLE"
	case .MaxHealth: return "ARMOR"
	case .Speed: return "SERVO BOOST"
	case .Invulnerability: return "PHASE ARMOR"
	case .Dash: return "KINETIC DASH"
	}
	return "UNKNOWN"
}

upgrade_description :: proc(upgrade: Upgrade_Kind) -> cstring {
	switch upgrade {
	case .Heal: return "Restore two health points."
	case .Damage: return "Deal one extra damage per hit."
	case .RapidFire: return "Reduce your weapon cooldown."
	case .Shotgun: return "Equip a three-pellet fan."
	case .Burst: return "Equip a fast three-pellet fan."
	case .MaxHealth: return "Increase maximum health and heal one."
	case .Speed: return "Move 28 pixels per second faster."
	case .Invulnerability: return "Gain 0.25 seconds of invulnerability."
	case .Dash: return "Left-click to dash; enemy bullets pass through you."
	}
	return "Unknown upgrade."
}

weapon_name :: proc(weapon: Weapon_Kind) -> cstring {
	switch weapon {
	case .Pistol: return "PISTOL"
	case .Shotgun: return "SHOTGUN"
	case .Burst: return "BURST RIFLE"
	}
	return "UNKNOWN"
}
