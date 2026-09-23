package main

import "core:math"
import rl "vendor:raylib"

spawn_bullet :: proc(game: ^Game, pos, vel: rl.Vector2, radius: f32, kind: Bullet_Kind) {
	_ = spawn_bullet_checked(game, pos, vel, radius, kind)
}

spawn_bullet_checked :: proc(game: ^Game, pos, vel: rl.Vector2, radius: f32, kind: Bullet_Kind) -> bool {
	for &bullet in game.bullets {
		if bullet.active { continue }
		bullet = {
			active = true,
			pos = pos,
			vel = vel,
			radius = radius,
			kind = kind,
			trajectory = .Straight,
			pattern = .None,
			emitter_id = -1,
		}
		return true
	}
	return false
}

spawn_pattern_bullet :: proc(game: ^Game, pos, vel: rl.Vector2, radius: f32, kind: Bullet_Kind, pattern: Bullet_Pattern_Kind, lifetime: f32, emitter_id: i32) -> bool {
	for &bullet in game.bullets {
		if bullet.active { continue }
		bullet = {
			active = true,
			pos = pos,
			vel = vel,
			radius = radius,
			kind = kind,
			trajectory = .Straight,
			lifetime = lifetime,
			pattern = pattern,
			emitter_id = emitter_id,
		}
		return true
	}
	return false
}

spawn_curved_bullet :: proc(game: ^Game, pos, vel: rl.Vector2, radius: f32, kind: Bullet_Kind, curve_rate, lifetime: f32) -> bool {
	for &bullet in game.bullets {
		if bullet.active { continue }
		bullet = {
			active = true,
			pos = pos,
			vel = vel,
			radius = radius,
			kind = kind,
			trajectory = .Curved,
			curve_rate = curve_rate,
			lifetime = lifetime,
			pattern = .Curved_Stream,
			emitter_id = -1,
		}
		return true
	}
	return false
}

update_bullets :: proc(game: ^Game, dt: f32) {
	for &bullet in game.bullets {
		if !bullet.active { continue }
		if bullet.lifetime > 0 {
			bullet.lifetime -= dt
			if bullet.lifetime <= 0 {
				bullet.active = false
				continue
			}
		}
		if bullet.trajectory == .Curved {
			// Curved bullets turn at a constant rate; they never sample the
			// player's position after being emitted.
			bullet.vel = rotate(bullet.vel, bullet.curve_rate * dt)
		}
		bullet.pos = vec_add(bullet.pos, vec_scale(bullet.vel, dt))
		if bullet.pos.x < -30 || bullet.pos.x > SCREEN_W + 30 || bullet.pos.y < -30 || bullet.pos.y > SCREEN_H + 30 {
			bullet.active = false
		}
	}
}

active_bullet_count :: proc(game: ^Game) -> i32 {
	count: i32
	for bullet in game.bullets {
		if bullet.active {
			count += 1
		}
	}
	return count
}

clear_pattern_bullets :: proc(game: ^Game, pattern: Bullet_Pattern_Kind) {
	if pattern == .None { return }
	for &bullet in game.bullets {
		if bullet.active && bullet.pattern == pattern {
			bullet.active = false
		}
	}
}

clear_temporary_pattern_bullets :: proc(game: ^Game) {
	clear_pattern_bullets(game, .Cross)
	clear_pattern_bullets(game, .Curved_Stream)
}

spawn_emitter_bullet :: proc(game: ^Game, pos, vel: rl.Vector2, emitter_id: i32) -> bool {
	return spawn_pattern_bullet(game, pos, vel, CROSS_EMITTER_BULLET_RADIUS, .Enemy, .Cross, CROSS_EMITTER_FIRE_DURATION + 2.0, emitter_id)
}

clear_emitter_bullets :: proc(game: ^Game, emitter_id: i32) {
	if emitter_id < 0 { return }
	for &bullet in game.bullets {
		if bullet.active && bullet.emitter_id == emitter_id {
			bullet.active = false
		}
	}
}

// One salvo is all-or-nothing.  If the 512-slot pool cannot hold the four
// bullets, the emitter is retired by its caller instead of making a partial,
// accidental hole in one arm.
spawn_cross_salvo :: proc(game: ^Game, position: rl.Vector2, emitter_id: i32) -> bool {
	if active_bullet_count(game) + CROSS_EMITTER_SALVO_SIZE > MAX_BULLETS {
		return false
	}
	directions := [4]rl.Vector2{{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
	for direction in directions {
		if !spawn_emitter_bullet(game, position, vec_scale(direction, CROSS_EMITTER_BULLET_SPEED), emitter_id) {
			clear_emitter_bullets(game, emitter_id)
			return false
		}
	}
	return true
}

// Shared attack constructors keep weapon and enemy behavior declarative.
fire_fan :: proc(game: ^Game, origin, direction: rl.Vector2, speed, radius: f32, kind: Bullet_Kind, angles: [3]f32) {
	for angle in angles {
		spawn_bullet(game, origin, vec_scale(rotate(direction, angle), speed), radius, kind)
	}
}

fire_ring :: proc(game: ^Game, origin: rl.Vector2, speed, radius: f32, kind: Bullet_Kind, count: int) {
	fire_ring_offset(game, origin, speed, radius, kind, count, 0)
}

fire_ring_offset :: proc(game: ^Game, origin: rl.Vector2, speed, radius: f32, kind: Bullet_Kind, count: int, pattern_angle: f32) {
	if count <= 0 { return }
	step := 2 * math_pi() / f32(count)
	for i in 0..<count {
		angle := f32(i) * step + pattern_angle
		direction := rl.Vector2{f32(math.cos(angle)), f32(math.sin(angle))}
		spawn_bullet(game, origin, vec_scale(direction, speed), radius, kind)
	}
}

fire_spiral :: proc(game: ^Game, origin: rl.Vector2, angle: f32, speed, radius: f32, kind: Bullet_Kind) {
	direction := rl.Vector2{f32(math.cos(angle)), f32(math.sin(angle))}
	spawn_bullet(game, origin, vec_scale(direction, speed), radius, kind)
}

fire_curved_bullet :: proc(game: ^Game, origin, direction: rl.Vector2, speed, radius: f32, kind: Bullet_Kind, curve_rate, lifetime: f32) -> bool {
	return spawn_curved_bullet(game, origin, vec_scale(normalized(direction), speed), radius, kind, curve_rate, lifetime)
}

math_pi :: proc() -> f32 { return 3.14159265 }

clear_enemy_bullets :: proc(game: ^Game) {
	for &bullet in game.bullets {
		if bullet.active && bullet.kind == .Enemy {
			bullet.active = false
		}
	}
}
