package main

import rl "vendor:raylib"

audio_global: Audio_State

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(SCREEN_W, SCREEN_H, "Project White- Odin bullet hell MVP")
	defer rl.CloseWindow()
	rl.SetTargetFPS(120)

	init_audio(&audio_global)
	defer shutdown_audio(&audio_global)

	game: Game
	reset_game(&game)
	load_progress(&game, &audio_global)
	game.audio = &audio_global

	for !rl.WindowShouldClose() {
		dt := min(rl.GetFrameTime(), MAX_FRAME_TIME)
		update(&game, dt)
		draw(&game)
	}
}
