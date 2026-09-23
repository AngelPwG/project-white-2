package main

import rl "vendor:raylib"

THREAT_BUDGET_BASE :: 3
THREAT_BUDGET_CAP :: 11

composition_tier_for_wave :: proc(wave: i32) -> i32 {
	// Bring pattern mutations forward without flattening the late game:
	// Wave 1 teaches, Waves 2-3 add one layer, Waves 4-5 add a second,
	// Waves 6-14 build the combined language, and Wave 15+ is fully layered.
	if wave <= 1 { return 0 }
	if wave <= 3 { return 1 }
	if wave <= 5 { return 2 }
	if wave <= 14 { return 3 }
	return 4
}

enemy_mutation_level_for_wave :: proc(wave: i32) -> i32 {
	return min(3, composition_tier_for_wave(wave))
}

cadence_multiplier_for_tier :: proc(tier: i32) -> f32 {
	switch min(4, max(0, tier)) {
	case 0: return 1.00
	case 1: return 0.96
	case 2: return 0.92
	case 3: return 0.88
	case 4: return 0.84
	}
	return 1.00
}

attack_interval_for_tier :: proc(tier: i32, base: f32) -> f32 {
	return max(MIN_ENEMY_FIRE_INTERVAL, base * cadence_multiplier_for_tier(tier))
}

encounter_pause_for_tier :: proc(tier: i32) -> f32 {
	switch min(4, max(0, tier)) {
	case 0: return 0.55
	case 1: return 0.50
	case 2: return 0.42
	case 3: return 0.35
	case 4: return 0.25
	}
	return 0.75
}

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
	case .Streaming: return 3.2
	case .Ring_Cage: return 3.6
	case .Spiral: return 4.0
	case .Micrododge: return 3.8
	case .Chaser_Pressure: return 4.6
	case .Crossfire: return 4.0
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
	game.encounter_stage = 0
	game.encounter_spawned = 0
	game.encounter_min_duration = 0
	game.wave_spawned = 0
	game.wave_director_done = false
	game.boss_spawned = !wave_has_boss(game.wave)
	game.wave_variation = (game.wave + game.director_seed) % 2
	game.composition_tier = composition_tier_for_wave(game.wave)
	game.enemy_mutation_level = enemy_mutation_level_for_wave(game.wave)
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
		update_encounter_reinforcements(game)
		if !encounter_has_active_enemies(game) && game.encounter_timer >= game.encounter_min_duration &&
			encounter_reinforcement_delay(game.encounter_kind, game.composition_tier, game.encounter_stage) < 0 {
			game.encounter_state = .Between
			game.encounter_pause_timer = encounter_pause_for_tier(game.composition_tier)
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
	game.encounter_stage = 0
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

turret_mutation_for_slot :: proc(game: ^Game, slot: i32) -> Enemy_Mutation_Kind {
	switch game.composition_tier {
	case 0: return .None
	case 1: return .Rotating_Ring
	case 2: return .Alternating_Ring
	case 3:
		return .Rotating_Ring if slot % 2 == 0 else .Alternating_Ring
	case 4:
		return .Spiral_Emitter if slot % 3 == 0 else .Alternating_Ring
	}
	return .None
}

spawn_encounter_formation :: proc(game: ^Game, kind: Encounter_Kind) {
	switch kind {
	case .Streaming:
		x := f32(145) if game.wave_variation == 0 else f32(SCREEN_W - 145)
		spawn_enemy_at(game, .Shooter, {x, 160}, .None)
		spawn_enemy_at(game, .Shooter, {x, 360}, .None)
		spawn_enemy_at(game, .Shooter, {x, 560}, .None)
	case .Ring_Cage:
		spawn_enemy_at_pattern(game, .Turret, {270, 180}, turret_mutation_for_slot(game, 0), 0.0)
		spawn_enemy_at_pattern(game, .Turret, {1010, 540}, turret_mutation_for_slot(game, 1), 0.32)
	case .Spiral:
		spawn_enemy_at_pattern(game, .Turret, {SCREEN_W / 2, 150}, .Spiral_Emitter, 0.0)
	case .Micrododge:
		spawn_enemy_at_pattern(game, .Turret, {SCREEN_W / 2, 130}, .Alternating_Ring, 0.18)
	case .Chaser_Pressure:
		spawn_enemy_at_pattern(game, .Turret, {SCREEN_W / 2, 150}, .Rotating_Ring, 0.0)
		spawn_enemy_at(game, .Chaser, {180, SCREEN_H + 20}, .None)
		spawn_enemy_at(game, .Chaser, {SCREEN_W - 180, SCREEN_H + 20}, .None)
		if game.wave >= 4 {
			spawn_enemy_at(game, .Dasher, {SCREEN_W / 2, -20}, .None)
		}
		if game.endless_mode {
			// Endless mode keeps the existing bomber/parry mechanic alive inside
			// a designed pressure encounter rather than as random global spam.
			spawn_enemy_at(game, .Bomber, {SCREEN_W / 2, SCREEN_H / 2}, .None)
		}
	case .Crossfire:
		spawn_enemy_at(game, .Shooter, {110, 155}, .None)
		spawn_enemy_at(game, .Shooter, {SCREEN_W - 110, SCREEN_H - 155}, .None)
	}
}

// Reinforcements are authored per encounter. Stage zero is the formation that
// appears at the start; later stages are deliberately timed interruptions.
encounter_reinforcement_delay :: proc(kind: Encounter_Kind, tier, stage: i32) -> f32 {
	switch kind {
	case .Streaming:
		if tier == 1 && stage == 0 { return 1.80 }
		if tier == 2 && stage == 0 { return 2.80 }
		if tier == 2 && stage == 1 { return 4.80 }
		if tier == 3 && stage == 0 { return 2.40 }
		if tier == 3 && stage == 1 { return 4.20 }
		if tier >= 4 && stage == 0 { return 2.00 }
		if tier >= 4 && stage == 1 { return 3.70 }
		if tier >= 4 && stage == 2 { return 5.10 }
	case .Ring_Cage:
		if tier == 1 && stage == 0 { return 1.80 }
		if tier == 2 && stage == 0 { return 3.00 }
		if tier == 2 && stage == 1 { return 5.00 }
		if tier == 3 && stage == 0 { return 2.50 }
		if tier == 3 && stage == 1 { return 4.60 }
		if tier >= 4 && stage == 0 { return 2.20 }
		if tier >= 4 && stage == 1 { return 4.00 }
		if tier >= 4 && stage == 2 { return 5.40 }
	case .Spiral:
		if tier == 1 && stage == 0 { return 2.00 }
		if tier == 2 && stage == 0 { return 2.80 }
		if tier == 2 && stage == 1 { return 4.70 }
		if tier == 3 && stage == 0 { return 2.40 }
		if tier == 3 && stage == 1 { return 4.20 }
		if tier >= 4 && stage == 0 { return 2.00 }
		if tier >= 4 && stage == 1 { return 3.80 }
		if tier >= 4 && stage == 2 { return 5.40 }
	case .Micrododge:
		if tier == 1 && stage == 0 { return 1.80 }
		if tier == 2 && stage == 0 { return 3.00 }
		if tier == 2 && stage == 1 { return 4.90 }
		if tier == 3 && stage == 0 { return 2.50 }
		if tier == 3 && stage == 1 { return 4.50 }
		if tier >= 4 && stage == 0 { return 2.10 }
		if tier >= 4 && stage == 1 { return 4.00 }
		if tier >= 4 && stage == 2 { return 5.30 }
	case .Chaser_Pressure:
		if tier == 2 && stage == 0 { return 2.60 }
		if tier == 3 && stage == 0 { return 2.40 }
		if tier == 3 && stage == 1 { return 4.80 }
		if tier >= 4 && stage == 0 { return 2.00 }
		if tier >= 4 && stage == 1 { return 4.20 }
	case .Crossfire:
		if tier == 1 && stage == 0 { return 1.80 }
		if tier == 2 && stage == 0 { return 2.80 }
		if tier == 2 && stage == 1 { return 4.60 }
		if tier == 3 && stage == 0 { return 2.40 }
		if tier == 3 && stage == 1 { return 4.20 }
		if tier >= 4 && stage == 0 { return 2.00 }
		if tier >= 4 && stage == 1 { return 3.80 }
		if tier >= 4 && stage == 2 { return 5.10 }
	}
	return -1.0
}

spawn_encounter_reinforcement :: proc(game: ^Game, kind: Encounter_Kind, stage: i32) {
	switch kind {
	case .Streaming:
		switch stage {
		case 0:
			spawn_enemy_at(game, .Chaser, {SCREEN_W / 2, SCREEN_H + 20}, .None)
		case 1:
			spawn_enemy_at_pattern(game, .Turret, {SCREEN_W / 2, 120}, turret_mutation_for_slot(game, 2), 0.16)
		case 2:
			spawn_enemy_at(game, .Volatile, {SCREEN_W / 2, SCREEN_H - 110}, .None)
		}
	case .Ring_Cage:
		switch stage {
		case 0:
			spawn_enemy_at(game, .Shooter, {SCREEN_W / 2, 105}, .None)
		case 1:
			spawn_enemy_at(game, .Chaser, {SCREEN_W / 2, SCREEN_H + 20}, .None)
		case 2:
			spawn_enemy_at(game, .Dasher, {SCREEN_W / 2, -20}, .None)
		}
	case .Spiral:
		switch stage {
		case 0:
			spawn_enemy_at(game, .Volatile, {SCREEN_W / 2, SCREEN_H - 110}, .None)
		case 1:
			spawn_enemy_at(game, .Shooter, {110, 150}, .None)
		case 2:
			spawn_enemy_at(game, .Dasher, {SCREEN_W - 110, 150}, .None)
		}
	case .Micrododge:
		switch stage {
		case 0:
			spawn_enemy_at(game, .Shooter, {SCREEN_W - 110, 150}, .None)
		case 1:
			spawn_enemy_at(game, .Chaser, {SCREEN_W / 2, SCREEN_H + 20}, .None)
		case 2:
			spawn_enemy_at(game, .Volatile, {SCREEN_W / 2, SCREEN_H - 110}, .None)
		}
	case .Chaser_Pressure:
		switch stage {
		case 0:
			spawn_enemy_at(game, .Shooter, {SCREEN_W / 2, 105}, .None)
		case 1:
			spawn_enemy_at(game, .Volatile, {SCREEN_W / 2, SCREEN_H - 110}, .None)
		}
	case .Crossfire:
		switch stage {
		case 0:
			spawn_enemy_at(game, .Chaser, {SCREEN_W / 2, SCREEN_H + 20}, .None)
		case 1:
			spawn_enemy_at_pattern(game, .Turret, {SCREEN_W / 2, 120}, turret_mutation_for_slot(game, 0), 0.36)
		case 2:
			spawn_enemy_at(game, .Volatile, {SCREEN_W / 2, SCREEN_H - 110}, .None)
		}
	}
}

update_encounter_reinforcements :: proc(game: ^Game) {
	delay := encounter_reinforcement_delay(game.encounter_kind, game.composition_tier, game.encounter_stage)
	if delay < 0 || game.encounter_timer < delay {
		return
	}
	spawn_encounter_reinforcement(game, game.encounter_kind, game.encounter_stage)
	game.encounter_stage += 1
}

boss_phase_duration :: proc(phase: Boss_Phase_Kind, wave: i32) -> f32 {
	base: f32
	switch phase {
	case .Rotating_Rings: base = BOSS_ROTATING_RING_DURATION
	case .Aimed_Bursts: base = BOSS_AIMED_BURST_DURATION
	case .Spiral: base = BOSS_SPIRAL_DURATION
	case .Finale: return 9999.0
	}
	// Boss phases tighten with the same authored tiers as encounters, but keep
	// a readable minimum for endless mode.
	extra_step: f32 = 0.35 if wave >= 10 else 0.0
	return max(BOSS_MIN_PHASE_DURATION, base - f32(composition_tier_for_wave(wave)) * BOSS_PHASE_TIER_STEP - extra_step)
}

advance_boss_phase :: proc(game: ^Game, enemy: ^Enemy) {
	if game.boss_phase == .Finale {
		return
	}
	game.boss_phase_index += 1
	game.boss_phase = Boss_Phase_Kind(game.boss_phase_index)
	game.boss_phase_timer = 0
	enemy.shot_timer = attack_interval_for_tier(game.composition_tier, 0.45)
	enemy.secondary_timer = attack_interval_for_tier(game.composition_tier, 0.85)
	clear_enemy_bullets(game)
}
