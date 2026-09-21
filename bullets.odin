package main

import "core:math"
import rl "vendor:raylib"

spawn_bullet :: proc(game: ^Game, pos, vel: rl.Vector2, radius: f32, kind: Bullet_Kind) {
	for &bullet in game.bullets {
		if bullet.active { continue }
		bullet = {active = true, pos = pos, vel = vel, radius = radius, kind = kind}
		return
	}
}

update_bullets :: proc(game: ^Game, dt: f32) {
	for &bullet in game.bullets {
		if !bullet.active { continue }
		bullet.pos = vec_add(bullet.pos, vec_scale(bullet.vel, dt))
		if bullet.pos.x < -30 || bullet.pos.x > SCREEN_W + 30 || bullet.pos.y < -30 || bullet.pos.y > SCREEN_H + 30 {
			bullet.active = false
		}
	}
}

// Shared attack constructors keep weapon and enemy behavior declarative.
fire_fan :: proc(game: ^Game, origin, direction: rl.Vector2, speed, radius: f32, kind: Bullet_Kind, angles: [3]f32) {
	for angle in angles {
		spawn_bullet(game, origin, vec_scale(rotate(direction, angle), speed), radius, kind)
	}
}

fire_ring :: proc(game: ^Game, origin: rl.Vector2, speed, radius: f32, kind: Bullet_Kind, count: int) {
	if count <= 0 { return }
	step := 2 * math_pi() / f32(count)
	for i in 0..<count {
		direction := rl.Vector2{f32(math.cos(f32(i) * step)), f32(math.sin(f32(i) * step))}
		spawn_bullet(game, origin, vec_scale(direction, speed), radius, kind)
	}
}

fire_spiral :: proc(game: ^Game, origin: rl.Vector2, angle: f32, speed, radius: f32, kind: Bullet_Kind) {
	direction := rl.Vector2{f32(math.cos(angle)), f32(math.sin(angle))}
	spawn_bullet(game, origin, vec_scale(direction, speed), radius, kind)
}

math_pi :: proc() -> f32 { return 3.14159265 }
