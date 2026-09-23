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
	case .Bullet_Cage: return 2
	case .Bullet_Cross: return 2
	case .Curve_Stream: return 1
	case .Rapid_Pressure: return 1
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
	case .Bullet_Cage: return 4.6
	case .Bullet_Cross: return 4.8
	case .Curve_Stream: return 4.2
	case .Rapid_Pressure: return 4.2
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
	case .Bullet_Cage: return 2
	case .Bullet_Cross: return 1
	case .Curve_Stream: return 1
	case .Rapid_Pressure: return 1
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
	case .Bullet_Cage: return "BULLET CAGE"
	case .Bullet_Cross: return "BULLET CROSS"
	case .Curve_Stream: return "CURVED STREAM"
	case .Rapid_Pressure: return "QUICKDRAW PRESSURE"
	}
	return "UNKNOWN"
}

encounter_is_temporary_pattern :: proc(kind: Encounter_Kind) -> bool {
	switch kind {
	case .Bullet_Cage, .Bullet_Cross, .Curve_Stream, .Rapid_Pressure:
		return true
	case .Streaming, .Ring_Cage, .Spiral, .Micrododge, .Chaser_Pressure, .Crossfire:
		return false
	}
	return false
}

encounter_plan_has_temporary_pattern :: proc(game: ^Game) -> bool {
	for i in 0..<game.encounter_plan_count {
		if encounter_is_temporary_pattern(game.encounter_plan[i]) {
			return true
		}
	}
	return false
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
	} else if game.wave == 6 {
		// First lesson: the cage is isolated before it can appear beside
		// another authored hazard.
		game.encounter_plan[0] = .Bullet_Cage
		game.encounter_plan[1] = .Streaming
		game.encounter_plan_count = 2
		game.wave_threat_budget = 3
	} else if game.wave == 7 {
		game.encounter_plan[0] = .Bullet_Cross
		game.encounter_plan[1] = .Ring_Cage
		game.encounter_plan_count = 2
		game.wave_threat_budget = 3
	} else if game.wave == 8 {
		game.encounter_plan[0] = .Curve_Stream
		game.encounter_plan[1] = .Micrododge
		game.encounter_plan_count = 2
		game.wave_threat_budget = 3
	} else if game.wave == 9 {
		game.encounter_plan[0] = .Rapid_Pressure
		game.encounter_plan[1] = .Chaser_Pressure
		game.encounter_plan_count = 2
		game.wave_threat_budget = 4
	} else {
		candidates := [10]Encounter_Kind{.Streaming, .Ring_Cage, .Crossfire, .Spiral, .Micrododge, .Chaser_Pressure, .Bullet_Cage, .Bullet_Cross, .Curve_Stream, .Rapid_Pressure}
		cursor := (game.wave * 3 + game.director_seed) % i32(len(candidates))
		for i in 0..<MAX_WAVE_ENCOUNTERS {
			candidate := candidates[(cursor + i32(i)) % i32(len(candidates))]
			cost := encounter_cost(candidate)
			if game.last_encounter_valid && candidate == game.last_encounter_kind {
				continue
			}
			// Keep the high-geometry warning patterns separate within a
			// wave. They can still be reused in later waves with normal
			// encounters between them.
			if encounter_is_temporary_pattern(candidate) && encounter_plan_has_temporary_pattern(game) {
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
	// No temporary formation survives a wave boundary or the upgrade screen.
	clear_enemy_bullets(game)
	clear_pattern_emitters(game)
	game.pattern_pool_limited = false
	game.peak_active_bullets = 0
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
		update_pattern_emitters(game, dt)
		if !encounter_has_active_enemies(game) && game.encounter_timer >= game.encounter_min_duration &&
			encounter_reinforcement_delay(game.encounter_kind, game.composition_tier, game.encounter_stage) < 0 {
			release_pattern_emitters(game, game.encounter_index)
			clear_temporary_pattern_bullets(game)
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
	game.pattern_pool_limited = false
	game.peak_active_bullets = 0
	if encounter_is_temporary_pattern(game.encounter_kind) {
		// Release old enemy projectiles before reserving a complete new
		// formation, so a full pool cannot punch accidental holes in it.
		clear_enemy_bullets(game)
	}
	clear_pattern_emitters(game)
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

cage_emitter_position :: proc(index: i32) -> rl.Vector2 {
	if index == 0 {
		return {f32(SCREEN_W) * 0.35, f32(SCREEN_H) * 0.35}
	}
	return {f32(SCREEN_W) * 0.65, f32(SCREEN_H) * 0.65}
}

spawn_pattern_emitter :: proc(game: ^Game, position: rl.Vector2, encounter_id, gap_offset: i32) -> bool {
	for index in 0..<MAX_PATTERN_EMITTERS {
		emitter := &game.pattern_emitters[index]
		if emitter.active { continue }
		max_duration: f32 = CROSS_EMITTER_MAX_DURATION
		if game.encounter_kind == .Bullet_Cage {
			max_duration = CAGE_MAX_DURATION
		}
		emitter^ = {
			active = true,
			kind = .Cross,
			pos = position,
			encounter_id = encounter_id,
			warning_timer = CROSS_EMITTER_WARNING_DURATION,
			fire_timer = CROSS_EMITTER_SHOT_INTERVAL,
			lifetime = max_duration,
			salvos_since_gap = gap_offset,
			gap_offset = gap_offset,
		}
		return true
	}
	return false
}

clear_pattern_emitters :: proc(game: ^Game) {
	for index in 0..<MAX_PATTERN_EMITTERS {
		clear_emitter_bullets(game, i32(index))
		game.pattern_emitters[index] = {}
	}
}

release_pattern_emitters :: proc(game: ^Game, encounter_id: i32) {
	for index in 0..<MAX_PATTERN_EMITTERS {
		emitter := &game.pattern_emitters[index]
		if !emitter.active || emitter.encounter_id != encounter_id { continue }
		clear_emitter_bullets(game, i32(index))
		emitter.active = false
	}
}

update_pattern_emitters :: proc(game: ^Game, dt: f32) {
	if game.encounter_kind != .Bullet_Cage && game.encounter_kind != .Bullet_Cross {
		return
	}
	can_release := game.encounter_timer >= CAGE_MIN_ACTIVE_DURATION &&
		!encounter_has_active_enemies(game) &&
		encounter_reinforcement_delay(game.encounter_kind, game.composition_tier, game.encounter_stage) < 0
	if can_release {
		release_pattern_emitters(game, game.encounter_index)
		return
	}

	for index in 0..<MAX_PATTERN_EMITTERS {
		emitter := &game.pattern_emitters[index]
		if !emitter.active || emitter.encounter_id != game.encounter_index { continue }
		emitter.lifetime -= dt
		if emitter.lifetime <= 0 {
			clear_emitter_bullets(game, i32(index))
			emitter.active = false
			continue
		}
		if emitter.warning_timer > 0 {
			emitter.warning_timer -= dt
			continue
		}
		if emitter.gap_active {
			emitter.gap_timer -= dt
			if emitter.gap_timer <= 0 {
				emitter.gap_active = false
				emitter.salvos_since_gap = emitter.gap_offset
				emitter.fire_timer = 0
			}
			continue
		}
		emitter.fire_timer -= dt
		if emitter.fire_timer > 0 { continue }
		if emitter.salvos_since_gap >= CROSS_EMITTER_GAP_EVERY_SALVOS {
			emitter.gap_active = true
			emitter.gap_timer = CROSS_EMITTER_GAP_DURATION
			emitter.fire_timer = CROSS_EMITTER_SHOT_INTERVAL
			continue
		}
		if !spawn_cross_salvo(game, emitter.pos, i32(index)) {
			// Never leave a partially constructed arm: retire this emitter and
			// remove its bullets if the global pool is unexpectedly full.
			clear_emitter_bullets(game, i32(index))
			game.pattern_pool_limited = true
			emitter.active = false
			continue
		}
		emitter.salvos_since_gap += 1
		emitter.fire_timer = CROSS_EMITTER_SHOT_INTERVAL
	}
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
	case .Bullet_Cage:
		// These are pattern objects, not enemies: they cannot be shot, do not
		// touch the player, and never keep the encounter alive by themselves.
		spawn_pattern_emitter(game, cage_emitter_position(0), game.encounter_index, 0)
		spawn_pattern_emitter(game, cage_emitter_position(1), game.encounter_index, 5)
		spawn_enemy_at(game, .Shooter, {130, 140}, .None)
		spawn_enemy_at(game, .Chaser, {SCREEN_W - 130, SCREEN_H + 20}, .None)
	case .Bullet_Cross:
		spawn_pattern_emitter(game, {SCREEN_W / 2, SCREEN_H / 2}, game.encounter_index, 0)
		spawn_enemy_at(game, .Shooter, {SCREEN_W - 130, 130}, .None)
	case .Curve_Stream:
		spawn_enemy_at_pattern(game, .Turret, {SCREEN_W / 2, 125}, .Curved_Stream, 0.0)
	case .Rapid_Pressure:
		x := f32(180) if game.wave_variation == 0 else f32(SCREEN_W - 180)
		spawn_enemy_at_pattern(game, .Shooter, {x, 150}, .Rapid_Shot, 0.0)
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
	case .Bullet_Cage:
		if stage == 0 { return 2.80 }
	case .Bullet_Cross:
		if stage == 0 { return 2.60 }
	case .Curve_Stream, .Rapid_Pressure:
		return -1.0
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
	case .Bullet_Cage:
		if stage == 0 {
			spawn_enemy_at(game, .Shooter, {SCREEN_W / 2, 105}, .None)
		}
	case .Bullet_Cross:
		if stage == 0 {
			spawn_enemy_at(game, .Chaser, {SCREEN_W / 2, SCREEN_H + 20}, .None)
		}
	case .Curve_Stream, .Rapid_Pressure:
		// These formations are authored as complete encounters.
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
