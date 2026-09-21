package main

import "core:math"
import rl "vendor:raylib"

spawn_enemy :: proc(game: ^Game, kind: Enemy_Kind) -> bool {
	for &enemy in game.enemies {
		if enemy.active { continue }

		n := game.spawn_count
		enemy = {
			active = true,
			kind = kind,
			pos = enemy_spawn_position(n, kind),
			health = enemy_health(kind, game.wave),
			shot_timer = 0.8 + f32(n % 5) * 0.12,
			dash_timer = 1.0,
			explode_timer = 4.0,
		}
		mark_enemy_discovered(game, kind)
		if kind == .Bomber {
			start_parry_warning(game)
		}
		game.spawn_count += 1
		return true
	}
	return false
}

enemy_spawn_position :: proc(n: i32, kind: Enemy_Kind) -> rl.Vector2 {
	if kind == .Turret {
		return {120 + f32((n * 137) % (SCREEN_W - 240)), 90 + f32((n * 83) % (SCREEN_H - 180))}
	}
	if kind == .Shooter {
		return {100 + f32((n * 149) % (SCREEN_W - 200)), 100 + f32((n * 71) % (SCREEN_H - 200))}
	}
	if kind == .Boss {
		return {SCREEN_W / 2, 80}
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
			enemy.pattern_angle += dt
			enemy.pos.x = SCREEN_W / 2 + f32(math.sin(enemy.pattern_angle * 0.7)) * 260
		}
		enemy.shot_timer -= dt
		if enemy.shot_timer > 0 { continue }
		if enemy.kind == .Bomber || enemy.kind == .Volatile { continue }

		switch enemy.kind {
		case .Chaser:
			fire_fan(game, enemy.pos, direction, 185, 5, .Enemy, ENEMY_FAN_ANGLES)
			enemy.shot_timer = 1.65
		case .Shooter:
			// One direct projectile, never a fan or ring.
			spawn_bullet(game, enemy.pos, vec_scale(direction, 210), 4, .Enemy)
			enemy.shot_timer = 1.35
		case .Turret:
			fire_ring(game, enemy.pos, 155, 5, .Enemy, 8)
			enemy.pattern_angle += 0.42
			enemy.shot_timer = 0.22
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
	switch kind {
	case .Chaser: return 2 + wave / 6
	case .Shooter: return 1 + wave / 8
	case .Turret: return 2 + wave / 4
	case .Dasher: return 2 + wave / 5
	case .Bomber: return 1
	case .Volatile: return 1
	case .Boss: return 20 + wave * 4
	}
	return 2 + wave / 6
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
