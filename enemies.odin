package main

import "core:math"
import rl "vendor:raylib"

spawn_enemy :: proc(game: ^Game, kind: Enemy_Kind) -> bool {
	n := game.spawn_count
	return spawn_enemy_at_pattern(game, kind, enemy_spawn_position(n, kind), .None, 0)
}

spawn_enemy_at :: proc(game: ^Game, kind: Enemy_Kind, position: rl.Vector2, mutation: Enemy_Mutation_Kind) -> bool {
	return spawn_enemy_at_pattern(game, kind, position, mutation, 0)
}

spawn_enemy_at_pattern :: proc(game: ^Game, kind: Enemy_Kind, position: rl.Vector2, mutation: Enemy_Mutation_Kind, pattern_angle: f32) -> bool {
	for &enemy in game.enemies {
		if enemy.active { continue }

		n := game.spawn_count
		selected_mutation := mutation
		if selected_mutation == .None {
			selected_mutation = enemy_mutation_for(kind, game.enemy_mutation_level)
		}
		enemy = {
			active = true,
			kind = kind,
			pos = position,
			health = enemy_health_for_run(kind, game.wave, game.damage),
			shot_timer = BOSS_INTRO_DURATION if kind == .Boss else 0.8 + f32(n % 5) * 0.12,
			pattern_angle = pattern_angle,
			dash_timer = 1.0,
			explode_timer = 4.0,
			secondary_timer = 0.85,
			mutation = selected_mutation,
			encounter_id = -1 if kind == .Boss else game.encounter_index,
		}
		mark_enemy_discovered(game, kind)
		if kind == .Bomber {
			start_parry_warning(game)
		}
		if kind == .Boss {
			game.boss_phase = .Rotating_Rings
			game.boss_phase_index = 0
			game.boss_phase_timer = 0
		}
		game.spawn_count += 1
		game.wave_spawned += 1
		game.encounter_spawned += 1 if kind != .Boss else 0
		return true
	}
	return false
}

enemy_mutation_for :: proc(kind: Enemy_Kind, level: i32) -> Enemy_Mutation_Kind {
	if level <= 0 { return .None }
	switch kind {
	case .Turret:
		if level == 1 { return .Rotating_Ring }
		if level == 2 { return .Alternating_Ring }
		return .Spiral_Emitter
	case .Shooter:
		if level == 1 { return .Short_Burst }
		return .Aimed_Fan
	case .Chaser, .Dasher, .Bomber, .Volatile, .Boss:
		return .None
	}
	return .None
}

enemy_spawn_position :: proc(n: i32, kind: Enemy_Kind) -> rl.Vector2 {
	if kind == .Turret {
		return {120 + f32((n * 137) % (SCREEN_W - 240)), 90 + f32((n * 83) % (SCREEN_H - 180))}
	}
	if kind == .Shooter {
		return {100 + f32((n * 149) % (SCREEN_W - 200)), 100 + f32((n * 71) % (SCREEN_H - 200))}
	}
	if kind == .Boss {
		return {SCREEN_W / 2, BOSS_HOME_Y - 80}
	}
	if kind == .Bomber {
		return {120 + f32((n * 137) % (SCREEN_W - 240)), 100 + f32((n * 83) % (SCREEN_H - 200))}
	}

	side := n % 4
	along := f32(50 + (n * 137) % (SCREEN_W - 100))
	switch side {
	case 0: return {along, -20}
	case 1: return {SCREEN_W + 20, f32(50 + (n * 83) % (SCREEN_H - 100))}
	case 2: return {along, SCREEN_H + 20}
	case 3: return {-20, f32(50 + (n * 83) % (SCREEN_H - 100))}
	}
	return {}
}

update_enemies :: proc(game: ^Game, dt: f32) {
	for &enemy in game.enemies {
		if !enemy.active { continue }

		direction := normalized(vec_sub(game.player_pos, enemy.pos))
		switch enemy.kind {
		case .Chaser:
			enemy.pos = vec_add(enemy.pos, vec_scale(direction, ENEMY_SPEED * dt))
		case .Shooter:
			// Shooters use the chaser movement, but at a gentler speed.
			enemy.pos = vec_add(enemy.pos, vec_scale(direction, ENEMY_SPEED * 0.78 * dt))
		case .Dasher:
			enemy.dash_timer -= dt
			side := rotate(direction, 1.5708)
			enemy.pos = vec_add(enemy.pos, vec_scale(vec_add(direction, vec_scale(side, f32(math.sin(enemy.pattern_angle)) * 0.45)), 135 * dt))
			enemy.pattern_angle += dt * 5
			if enemy.dash_timer <= 0 { enemy.dash_timer = 1.6 }
		case .Turret:
			// Turrets hold their position and create area denial.
		case .Bomber:
			enemy.explode_timer -= dt
			// Bombers are static parry targets. They never chase the player.
			if enemy.explode_timer <= 0 {
				enemy.active = false
				detonate_bomber_at(game, enemy.pos)
				continue
			}
		case .Volatile:
			enemy.pos = vec_add(enemy.pos, vec_scale(direction, 110 * dt))
			if length_squared(vec_sub(enemy.pos, game.player_pos)) <= 38 * 38 {
				enemy.active = false
				detonate_volatile_at(game, enemy.pos)
				continue
			}
		case .Boss:
			update_boss(game, &enemy, dt)
			continue
		}
		enemy.shot_timer -= dt
		if enemy.shot_timer > 0 { continue }
		if enemy.kind == .Bomber || enemy.kind == .Volatile { continue }

		switch enemy.kind {
		case .Chaser:
			fire_fan(game, enemy.pos, direction, 185, 5, .Enemy, ENEMY_FAN_ANGLES)
			enemy.shot_timer = 1.65
		case .Shooter:
			switch enemy.mutation {
		case .Short_Burst:
				fire_fan(game, enemy.pos, direction, 210, 4, .Enemy, BURST_ANGLES)
				enemy.shot_timer = 1.55
			case .Aimed_Fan:
				fire_fan(game, enemy.pos, direction, 215, 4, .Enemy, ENEMY_FAN_ANGLES)
				enemy.shot_timer = 1.50
			case .None, .Rotating_Ring, .Alternating_Ring, .Spiral_Emitter:
				spawn_bullet(game, enemy.pos, vec_scale(direction, 210), 4, .Enemy)
				enemy.shot_timer = 1.35
			}
		case .Turret:
			switch enemy.mutation {
			case .Rotating_Ring:
				fire_ring_offset(game, enemy.pos, 145, 5, .Enemy, 8, enemy.pattern_angle)
				enemy.pattern_angle += 0.30
				enemy.shot_timer = 0.82
			case .Alternating_Ring:
				offset: f32 = 0.20 if i32(enemy.pattern_angle * 10) % 2 == 0 else -0.20
				fire_ring_offset(game, enemy.pos, 125, 5, .Enemy, 10, offset)
				enemy.pattern_angle += 0.41
				enemy.shot_timer = 0.78
			case .Spiral_Emitter:
				fire_spiral(game, enemy.pos, enemy.pattern_angle, 120, 5, .Enemy)
				enemy.pattern_angle += 0.34
				enemy.shot_timer = 0.15
			case .None, .Short_Burst, .Aimed_Fan:
				fire_ring_offset(game, enemy.pos, 145, 5, .Enemy, 8, enemy.pattern_angle)
				enemy.pattern_angle += 0.18
				enemy.shot_timer = 0.92
			}
		case .Dasher:
			fire_fan(game, enemy.pos, direction, 220, 5, .Enemy, ENEMY_FAN_ANGLES)
			enemy.shot_timer = 1.2
		case .Bomber:
			// Bombers detonate instead of firing projectiles.
		case .Volatile:
			// Volatile enemies chase and explode instead of firing projectiles.
		case .Boss:
			fire_ring(game, enemy.pos, 125, 6, .Enemy, 12)
			enemy.shot_timer = 1.0
		}
	}
}

update_boss :: proc(game: ^Game, enemy: ^Enemy, dt: f32) {
	enemy.pattern_angle += dt
	game.boss_phase_timer += dt
	if game.boss_phase_timer >= boss_phase_duration(game.boss_phase, game.wave) {
		advance_boss_phase(game, enemy)
	}
	target := boss_target_position(game.boss_phase, enemy.pattern_angle)
	// The boss enters from above, then settles into a predictable central lane.
	enemy.pos = vec_add(enemy.pos, vec_scale(vec_sub(target, enemy.pos), min(1.0, dt * 3.0)))

	direction := normalized(vec_sub(game.player_pos, enemy.pos))
	enemy.shot_timer -= dt
	enemy.secondary_timer -= dt
	switch game.boss_phase {
	case .Aimed_Bursts:
		if enemy.shot_timer <= 0 {
			fire_fan(game, enemy.pos, direction, 195, 5, .Enemy, BURST_ANGLES)
			enemy.shot_timer = 0.78 - f32(max(0, game.wave - 10)) * 0.01
		}
	case .Rotating_Rings:
		if enemy.shot_timer <= 0 {
			fire_ring_offset(game, enemy.pos, 130 + f32(max(0, game.wave - 10)) * 2, 5, .Enemy, 12, enemy.pattern_angle * 0.55)
			enemy.shot_timer = 0.95 - f32(max(0, game.wave - 10)) * 0.01
		}
	case .Spiral:
		if enemy.shot_timer <= 0 {
			fire_spiral(game, enemy.pos, enemy.pattern_angle * 1.8, 135, 5, .Enemy)
			enemy.shot_timer = 0.13 - f32(max(0, game.wave - 10)) * 0.002
		}
	case .Finale:
		if enemy.shot_timer <= 0 {
			fire_fan(game, enemy.pos, direction, 200, 5, .Enemy, ENEMY_FAN_ANGLES)
			enemy.shot_timer = 0.90
		}
		if enemy.secondary_timer <= 0 {
			fire_ring_offset(game, enemy.pos, 120, 5, .Enemy, 12, enemy.pattern_angle * 0.6)
			enemy.secondary_timer = 1.35 - f32(max(0, game.wave - 10)) * 0.02
		}
	}
}

boss_target_position :: proc(phase: Boss_Phase_Kind, angle: f32) -> rl.Vector2 {
	home := rl.Vector2{SCREEN_W / 2, BOSS_HOME_Y}
	switch phase {
	case .Rotating_Rings, .Spiral:
		return home
	case .Aimed_Bursts:
		return {home.x + f32(math.sin(angle * 0.55)) * BOSS_MOVE_RADIUS, home.y}
	case .Finale:
		return {
			home.x + f32(math.sin(angle * 0.7)) * BOSS_FINALE_RADIUS,
			home.y + f32(math.cos(angle * 0.45)) * 32,
		}
	}
	return home
}

enemy_size :: proc(kind: Enemy_Kind) -> f32 {
	switch kind {
	case .Chaser: return 28
	case .Shooter: return 18
	case .Turret: return 34
	case .Dasher: return 24
	case .Bomber: return 22
	case .Volatile: return 20
	case .Boss: return 64
	}
	return 28
}

enemy_health :: proc(kind: Enemy_Kind, wave: i32) -> i32 {
	return enemy_health_for_run(kind, wave, 1)
}

enemy_health_for_run :: proc(kind: Enemy_Kind, wave, player_damage: i32) -> i32 {
	wave_bonus := i32(f32(max(0, wave - 1)) * ENEMY_HP_WAVE_STEP)
	damage_bonus := max(0, player_damage - 1) * 3
	switch kind {
	case .Chaser: return ENEMY_CHASER_BASE_HP + wave_bonus + damage_bonus
	case .Shooter: return ENEMY_SHOOTER_BASE_HP + wave_bonus + damage_bonus
	case .Turret: return ENEMY_TURRET_BASE_HP + wave_bonus + damage_bonus
	case .Dasher: return ENEMY_DASHER_BASE_HP + wave_bonus + damage_bonus
	case .Bomber: return 1
	case .Volatile: return ENEMY_VOLATILE_BASE_HP + wave_bonus + damage_bonus
	case .Boss: return ENEMY_BOSS_BASE_HP + wave * BOSS_HP_WAVE_STEP + max(0, player_damage - 1) * BOSS_HP_DAMAGE_STEP
	}
	return ENEMY_CHASER_BASE_HP + wave_bonus + damage_bonus
}

wave_enemy_kind :: proc(wave, index: i32) -> Enemy_Kind {
	// Small shooters appear from wave one while chasers remain in every wave.
	if wave >= 6 && index % 7 == 0 { return .Bomber }
	if wave >= 3 && index % 6 == 3 { return .Volatile }
	if index % 3 == 1 { return .Shooter }
	if wave >= 3 && index % 5 == 4 { return .Dasher }
	if wave >= 2 && index % 3 == 2 { return .Turret }
	return .Chaser
}

mark_enemy_discovered :: proc(game: ^Game, kind: Enemy_Kind) {
	new_discovery := false
	switch kind {
	case .Chaser:
		new_discovery = !game.discovered_enemies[0]
		game.discovered_enemies[0] = true
	case .Shooter:
		new_discovery = !game.discovered_enemies[1]
		game.discovered_enemies[1] = true
	case .Turret:
		new_discovery = !game.discovered_enemies[2]
		game.discovered_enemies[2] = true
	case .Dasher:
		new_discovery = !game.discovered_enemies[3]
		game.discovered_enemies[3] = true
	case .Bomber:
		new_discovery = !game.discovered_enemies[4]
		game.discovered_enemies[4] = true
	case .Volatile:
		new_discovery = !game.discovered_enemies[5]
		game.discovered_enemies[5] = true
	case .Boss:
		new_discovery = !game.discovered_enemies[6]
		game.discovered_enemies[6] = true
	}
	if new_discovery {
		save_progress(game)
	}
}

enemy_discovered :: proc(game: ^Game, kind: Enemy_Kind) -> bool {
	switch kind {
	case .Chaser: return game.discovered_enemies[0]
	case .Shooter: return game.discovered_enemies[1]
	case .Turret: return game.discovered_enemies[2]
	case .Dasher: return game.discovered_enemies[3]
	case .Bomber: return game.discovered_enemies[4]
	case .Volatile: return game.discovered_enemies[5]
	case .Boss: return game.discovered_enemies[6]
	}
	return false
}

enemy_name :: proc(kind: Enemy_Kind) -> cstring {
	switch kind {
	case .Chaser: return "CHASER"
	case .Shooter: return "SHOOTER"
	case .Turret: return "TURRET"
	case .Dasher: return "DASHER"
	case .Bomber: return "BOMBER"
	case .Volatile: return "VOLATILE"
	case .Boss: return "BOSS"
	}
	return "UNKNOWN"
}

enemy_description :: proc(kind: Enemy_Kind) -> cstring {
	switch kind {
	case .Chaser: return "A black geometric pursuer that follows the player and fires a three-shot fan."
	case .Shooter: return "A smaller pursuer that follows the player and fires one direct bullet at a time."
	case .Turret: return "A stationary unit that fires repeated rings of bullets."
	case .Dasher: return "A fast orange unit with sideways movement and aggressive fan shots."
	case .Bomber: return "A static threat that cannot be damaged and must be neutralized with the parry skill check."
	case .Volatile: return "A pursuer that can be destroyed by shooting it, triggering a local area explosion."
	case .Boss: return "A large unit with high health, horizontal movement, and ring attacks."
	}
	return "No record available."
}

mutation_name :: proc(mutation: Enemy_Mutation_Kind) -> cstring {
	switch mutation {
	case .None: return "BASE"
	case .Rotating_Ring: return "ROTATING RING"
	case .Alternating_Ring: return "ALTERNATING RING"
	case .Spiral_Emitter: return "SPIRAL EMITTER"
	case .Short_Burst: return "SHORT BURST"
	case .Aimed_Fan: return "AIMED FAN"
	}
	return "BASE"
}

// A fuse/contact detonation is global: it reaches the whole arena.
detonate_bomber_at :: proc(game: ^Game, position: rl.Vector2) {
	game.explosion_pos = position
	game.explosion_radius = BOMBER_GLOBAL_BLAST_RADIUS
	game.explosion_timer = .35
	game.explosion_global = true
	damage_player(game)
	play_death_sound(game.audio)
}

detonate_volatile_at :: proc(game: ^Game, position: rl.Vector2) {
	game.explosion_pos = position
	game.explosion_radius = BOMBER_BLAST_RADIUS
	game.explosion_timer = .35
	game.explosion_global = false
	if length_squared(vec_sub(position, game.player_pos)) <= BOMBER_BLAST_RADIUS * BOMBER_BLAST_RADIUS {
		damage_player(game)
	}
	play_death_sound(game.audio)
}
