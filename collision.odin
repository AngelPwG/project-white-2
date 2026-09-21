package main

import rl "vendor:raylib"

handle_collisions :: proc(game: ^Game) {
	player_rect := centered_rect(game.player_pos, game.player_size)

	for &bullet in game.bullets {
		if !bullet.active { continue }
		// During a dash, enemy bullets pass through the player and remain active.
		if game.dash_timer > 0 && bullet.kind == .Enemy { continue }
		if bullet.kind == .Enemy && rl.CheckCollisionCircleRec(bullet.pos, bullet.radius, player_rect) {
			bullet.active = false
			damage_player(game)
			continue
		}
		if bullet.kind != .Player { continue }

		for &enemy in game.enemies {
			if !enemy.active { continue }
			// Bombers are invulnerable parry targets; player bullets pass through them.
			if enemy.kind == .Bomber { continue }
			if rl.CheckCollisionCircleRec(bullet.pos, bullet.radius, centered_rect(enemy.pos, enemy_size(enemy.kind))) {
				bullet.active = false
				enemy.health -= game.damage
				play_hit_sound(game.audio)
				if enemy.health <= 0 {
					enemy.active = false
					game.score += 1
					if enemy.kind == .Volatile {
						detonate_volatile_at(game, enemy.pos)
					} else {
						play_death_sound(game.audio)
					}
				}
				break
			}
		}
	}

	for &enemy in game.enemies {
		if enemy.active && rl.CheckCollisionRecs(centered_rect(enemy.pos, enemy_size(enemy.kind)), player_rect) {
			if enemy.kind == .Bomber {
				// The static bomber is handled by its parry/fuse warning.
				continue
			}
			if enemy.kind == .Volatile {
				enemy.active = false
				detonate_volatile_at(game, enemy.pos)
				continue
			}
			// Bosses persist on contact; all other enemies are consumed.
			if enemy.kind != .Boss {
				enemy.active = false
			}
			damage_player(game)
		}
	}
}
