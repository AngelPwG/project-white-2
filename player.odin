package main

import rl "vendor:raylib"

update_player :: proc(game: ^Game, dt: f32) {
	move: rl.Vector2
	if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP) { move.y -= 1 }
	if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) { move.y += 1 }
	if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT) { move.x -= 1 }
	if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) { move.x += 1 }

	move = normalized(move)
	game.dash_cooldown = max(0, game.dash_cooldown - dt)
	if game.dash_timer > 0 {
		game.dash_timer -= dt
		game.player_pos = vec_add(game.player_pos, vec_scale(game.dash_direction, DASH_SPEED * dt))
		game.invulnerability_timer = max(game.invulnerability_timer, game.dash_timer)
	} else {
		if game.dash_unlocked && rl.IsMouseButtonPressed(.LEFT) && game.dash_cooldown <= 0 {
			dash_direction := move
			if length_squared(dash_direction) <= 0 {
				dash_direction = player_aim_direction(game)
			}
			game.dash_direction = dash_direction
			game.dash_timer = DASH_DURATION
			game.dash_cooldown = DEFAULT_DASH_COOLDOWN
			game.invulnerability_timer = max(game.invulnerability_timer, DASH_DURATION)
		} else {
			game.player_pos = vec_add(game.player_pos, vec_scale(move, game.move_speed * dt))
		}
	}
	game.player_pos.x = clamp(game.player_pos.x, game.player_size / 2, SCREEN_W - game.player_size / 2)
	game.player_pos.y = clamp(game.player_pos.y, game.player_size / 2, SCREEN_H - game.player_size / 2)

	game.shot_timer -= dt
	if game.shot_timer <= 0 {
		fire_player_shotgun(game)
	}
}

fire_player_shotgun :: proc(game: ^Game) {
	direction := player_aim_direction(game)

	origin := vec_add(game.player_pos, vec_scale(direction, 18))
	switch game.weapon {
	case .Pistol:
		spawn_bullet(game, origin, vec_scale(direction, game.shot_speed + 80), 4, .Player)
		game.shot_timer = game.fire_interval
	case .Shotgun:
		fire_fan(game, origin, direction, game.shot_speed, 4, .Player, SHOTGUN_ANGLES)
		game.shot_timer = game.fire_interval * 1.45
	case .Burst:
		fire_fan(game, origin, direction, game.shot_speed + 40, 3, .Player, BURST_ANGLES)
		game.shot_timer = game.fire_interval * 0.75
	}
	play_shoot_sound(game.audio)
}

player_aim_direction :: proc(game: ^Game) -> rl.Vector2 {
	if game.keyboard_aim {
		direction: rl.Vector2
		if rl.IsKeyDown(.I) { direction.y -= 1 }
		if rl.IsKeyDown(.K) { direction.y += 1 }
		if rl.IsKeyDown(.J) { direction.x -= 1 }
		if rl.IsKeyDown(.L) { direction.x += 1 }
		direction = normalized(direction)
		if length_squared(direction) > 0 { return direction }
		return {1, 0}
	}
	direction := normalized(vec_sub(rl.GetMousePosition(), game.player_pos))
	if length_squared(direction) <= 0 { return {1, 0} }
	return direction
}
