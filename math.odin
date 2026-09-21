package main

import "core:math"
import rl "vendor:raylib"

length_squared :: proc(v: rl.Vector2) -> f32 { return v.x * v.x + v.y * v.y }

normalized :: proc(v: rl.Vector2) -> rl.Vector2 {
	length_sq := length_squared(v)
	if length_sq <= 0.0001 { return {} }
	return vec_scale(v, 1.0 / f32(math.sqrt(length_sq)))
}

vec_add :: proc(a, b: rl.Vector2) -> rl.Vector2 { return {a.x + b.x, a.y + b.y} }
vec_sub :: proc(a, b: rl.Vector2) -> rl.Vector2 { return {a.x - b.x, a.y - b.y} }
vec_scale :: proc(v: rl.Vector2, scale: f32) -> rl.Vector2 { return {v.x * scale, v.y * scale} }

rotate :: proc(v: rl.Vector2, angle: f32) -> rl.Vector2 {
	c := f32(math.cos(angle))
	s := f32(math.sin(angle))
	return {v.x * c - v.y * s, v.x * s + v.y * c}
}

centered_rect :: proc(pos: rl.Vector2, size: f32) -> rl.Rectangle {
	return {pos.x - size / 2, pos.y - size / 2, size, size}
}
