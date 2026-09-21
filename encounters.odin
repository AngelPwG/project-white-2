package main

import rl "vendor:raylib"

THREAT_BUDGET_BASE :: 3
THREAT_BUDGET_CAP :: 11

// The director chooses authored situations. It never chooses individual bullet
// angles, counts, or speeds at runtime.
encounter_cost :: proc(kind: Encounter_Kind) -> i32 {
	switch kind {
	case .Streaming: return 1
	case .Ring_Cage: return 1
	case .Crossfire: return 2
	case .Spiral: return 2
	case .Micrododge: return 2
	case .Chaser_Pressure: return 3
	}
	return 1
}

encounter_min_time :: proc(kind: Encounter_Kind) -> f32 {
	switch kind {
	case .Streaming: return 4.5
	case .Ring_Cage: return 5.0
	case .Spiral: return 5.5
	case .Micrododge: return 5.0
	case .Chaser_Pressure: return 6.0
	case .Crossfire: return 5.0
	}
	return 5.0
}

encounter_formation_count :: proc(kind: Encounter_Kind) -> i32 {
	switch kind {
	case .Streaming: return 3
	case .Ring_Cage: return 2
	case .Spiral: return 1
	case .Micrododge: return 1
	case .Chaser_Pressure: return 3
	case .Crossfire: return 2
	}
	return 1
}

encounter_name :: proc(kind: Encounter_Kind) -> cstring {
	switch kind {
	case .Streaming: return "STREAMING"
	case .Ring_Cage: return "RING CAGE"
	case .Spiral: return "SPIRAL"
	case .Micrododge: return "MICRODODGE"
	case .Chaser_Pressure: return "CHASER PRESSURE"
	case .Crossfire: return "CROSSFIRE"
	}
	return "UNKNOWN"
}

boss_phase_name :: proc(phase: Boss_Phase_Kind) -> cstring {
	switch phase {
	case .Aimed_Bursts: return "AIMED BURSTS"
	case .Rotating_Rings: return "ROTATING RINGS"
	case .Spiral: return "SPIRAL"
	case .Finale: return "FINALE"
	}
	return "UNKNOWN"
}

build_wave_plan :: proc(game: ^Game) {
	game.encounter_plan = {}
	game.encounter_plan_count = 0
	game.wave_threat_spent = 0
	game.wave_threat_budget = min(THREAT_BUDGET_CAP, THREAT_BUDGET_BASE + game.wave / 2 + max(0, (game.wave - 6) / 3))

	// The first four waves teach the movement vocabulary in a fixed order.
	if game.wave == 1 {
		game.encounter_plan[0] = .Streaming
		game.encounter_plan[1] = .Streaming
		game.encounter_plan[2] = .Streaming
		game.encounter_plan_count = 3
		game.wave_threat_budget = 3
	} else if game.wave == 2 {
		game.encounter_plan[0] = .Ring_Cage
		game.encounter_plan[1] = .Streaming
		game.encounter_plan[2] = .Ring_Cage
		game.encounter_plan_count = 3
		game.wave_threat_budget = 3
	} else if game.wave == 3 {
		game.encounter_plan[0] = .Micrododge
		game.encounter_plan[1] = .Chaser_Pressure
		game.encounter_plan[2] = .Spiral
		game.encounter_plan_count = 3
		game.wave_threat_budget = 7
	} else if game.wave == 4 {
		game.encounter_plan[0] = .Crossfire
		game.encounter_plan[1] = .Chaser_Pressure
		game.encounter_plan[2] = .Ring_Cage
		game.encounter_plan[3] = .Micrododge
		game.encounter_plan_count = 4
		game.wave_threat_budget = 9
	} else {
		candidates := [6]Encounter_Kind{.Streaming, .Ring_Cage, .Crossfire, .Spiral, .Micrododge, .Chaser_Pressure}
		cursor := (game.wave * 3 + game.director_seed) % i32(len(candidates))
		for i in 0..<MAX_WAVE_ENCOUNTERS {
			candidate := candidates[(cursor + i32(i)) % i32(len(candidates))]
			cost := encounter_cost(candidate)
			if game.last_encounter_valid && candidate == game.last_encounter_kind {
				continue
			}
			if game.wave_threat_spent + cost > game.wave_threat_budget && game.encounter_plan_count > 0 {
				continue
			}
			game.encounter_plan[game.encounter_plan_count] = candidate
			game.encounter_plan_count += 1
			game.wave_threat_spent += cost
			if game.encounter_plan_count >= 3 && game.wave_threat_spent >= game.wave_threat_budget {
				break
			}
		}
		if game.encounter_plan_count == 0 {
			game.encounter_plan[0] = .Streaming
			game.encounter_plan_count = 1
			game.wave_threat_spent = encounter_cost(.Streaming)
		}
	}

	if game.wave <= 4 {
		for i in 0..<game.encounter_plan_count {
			game.wave_threat_spent += encounter_cost(game.encounter_plan[i])
		}
	}
	game.wave_enemy_target = 0
	for i in 0..<game.encounter_plan_count {
		game.wave_enemy_target += encounter_formation_count(game.encounter_plan[i])
	}
}

start_wave :: proc(game: ^Game) {
	build_wave_plan(game)
	game.encounter_index = -1
	game.encounter_kind = .Streaming
	game.encounter_state = .Between
	game.encounter_timer = 0
	game.encounter_pause_timer = ENCOUNTER_START_DELAY
	game.encounter_spawned = 0
	game.encounter_min_duration = 0
	game.wave_spawned = 0
	game.wave_director_done = false
	game.boss_spawned = !wave_has_boss(game.wave)
	game.wave_variation = (game.wave + game.director_seed) % 2
	game.enemy_mutation_level = min(3, max(0, (game.wave - 1) / 2))
}

update_encounter_director :: proc(game: ^Game, dt: f32) {
	if game.wave_director_done {
		if wave_has_boss(game.wave) && !game.boss_spawned {
			if spawn_enemy(game, .Boss) {
				game.boss_spawned = true
			}
		}
		return
	}

	if game.encounter_state == .Active {
		game.encounter_timer += dt
		if !encounter_has_active_enemies(game) && game.encounter_timer >= game.encounter_min_duration {
			game.encounter_state = .Between
			game.encounter_pause_timer = ENCOUNTER_PAUSE
		}
		return
	}

	if game.encounter_pause_timer > 0 {
		game.encounter_pause_timer -= dt
		return
	}

	if game.encounter_index + 1 < game.encounter_plan_count {
		begin_encounter(game)
		return
	}

	game.encounter_state = .Complete
	game.wave_director_done = true
	if wave_has_boss(game.wave) && !game.boss_spawned {
		if spawn_enemy(game, .Boss) {
			game.boss_spawned = true
		}
	}
}

begin_encounter :: proc(game: ^Game) {
	game.encounter_index += 1
	game.encounter_kind = game.encounter_plan[game.encounter_index]
	game.encounter_state = .Active
	game.encounter_timer = 0
	game.encounter_min_duration = encounter_min_time(game.encounter_kind)
	game.encounter_spawned = 0
	game.last_encounter_kind = game.encounter_kind
	game.last_encounter_valid = true
	spawn_encounter_formation(game, game.encounter_kind)
}

encounter_has_active_enemies :: proc(game: ^Game) -> bool {
	for enemy in game.enemies {
		if enemy.active && enemy.encounter_id == game.encounter_index {
			return true
		}
	}
	return false
}

spawn_encounter_formation :: proc(game: ^Game, kind: Encounter_Kind) {
	switch kind {
	case .Streaming:
		x := f32(145) if game.wave_variation == 0 else f32(SCREEN_W - 145)
		spawn_enemy_at(game, .Shooter, {x, 160}, .None)
		spawn_enemy_at(game, .Shooter, {x, 360}, .None)
		spawn_enemy_at(game, .Shooter, {x, 560}, .None)
		if game.wave >= 6 {
			spawn_enemy_at(game, .Chaser, {SCREEN_W / 2, SCREEN_H + 20}, .None)
		}
		if game.wave >= 11 {
			spawn_enemy_at_pattern(game, .Turret, {SCREEN_W / 2, 120}, .Rotating_Ring, 0.16)
		}
	case .Ring_Cage:
		spawn_enemy_at_pattern(game, .Turret, {270, 180}, .None, 0.0)
		spawn_enemy_at_pattern(game, .Turret, {1010, 540}, .None, 0.32)
		if game.wave >= 6 {
			spawn_enemy_at(game, .Shooter, {SCREEN_W / 2, 105}, .None)
		}
		if game.wave >= 11 {
			spawn_enemy_at(game, .Chaser, {SCREEN_W / 2, SCREEN_H + 20}, .None)
		}
	case .Spiral:
		spawn_enemy_at_pattern(game, .Turret, {SCREEN_W / 2, 150}, .Spiral_Emitter, 0.0)
		if game.wave >= 6 {
			spawn_enemy_at(game, .Volatile, {SCREEN_W / 2, SCREEN_H - 110}, .None)
		}
		if game.wave >= 11 {
			spawn_enemy_at(game, .Shooter, {110, 150}, .None)
		}
	case .Micrododge:
		spawn_enemy_at_pattern(game, .Turret, {SCREEN_W / 2, 130}, .Alternating_Ring, 0.18)
		if game.wave >= 10 {
			spawn_enemy_at(game, .Shooter, {SCREEN_W - 110, 150}, .None)
		}
	case .Chaser_Pressure:
		spawn_enemy_at_pattern(game, .Turret, {SCREEN_W / 2, 150}, .Rotating_Ring, 0.0)
		spawn_enemy_at(game, .Chaser, {180, SCREEN_H + 20}, .None)
		spawn_enemy_at(game, .Chaser, {SCREEN_W - 180, SCREEN_H + 20}, .None)
		if game.wave >= 4 {
			spawn_enemy_at(game, .Dasher, {SCREEN_W / 2, -20}, .None)
		}
		if game.wave >= 10 {
			spawn_enemy_at(game, .Shooter, {SCREEN_W / 2, 105}, .None)
		}
		if game.endless_mode {
			// Endless mode keeps the existing bomber/parry mechanic alive inside
			// a designed pressure encounter rather than as random global spam.
			spawn_enemy_at(game, .Bomber, {SCREEN_W / 2, SCREEN_H / 2}, .None)
		}
	case .Crossfire:
		spawn_enemy_at(game, .Shooter, {110, 155}, .None)
		spawn_enemy_at(game, .Shooter, {SCREEN_W - 110, SCREEN_H - 155}, .None)
		if game.wave >= 6 {
			spawn_enemy_at(game, .Chaser, {SCREEN_W / 2, SCREEN_H + 20}, .None)
			spawn_enemy_at(game, .Volatile, {SCREEN_W / 2, SCREEN_H - 110}, .None)
		}
		if game.wave >= 11 {
			spawn_enemy_at_pattern(game, .Turret, {SCREEN_W / 2, 120}, .Rotating_Ring, 0.36)
		}
	}
}

boss_phase_duration :: proc(phase: Boss_Phase_Kind, wave: i32) -> f32 {
	base: f32
	switch phase {
	case .Rotating_Rings: base = BOSS_ROTATING_RING_DURATION
	case .Aimed_Bursts: base = BOSS_AIMED_BURST_DURATION
	case .Spiral: base = BOSS_SPIRAL_DURATION
	case .Finale: return 9999.0
	}
	return max(5.5, base - f32(max(0, wave - 10)) * 0.05)
}

advance_boss_phase :: proc(game: ^Game, enemy: ^Enemy) {
	if game.boss_phase == .Finale {
		return
	}
	game.boss_phase_index += 1
	game.boss_phase = Boss_Phase_Kind(game.boss_phase_index)
	game.boss_phase_timer = 0
	enemy.shot_timer = 0.45
	enemy.secondary_timer = 0.85
	clear_enemy_bullets(game)
}
