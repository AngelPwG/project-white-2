package main

import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"

// Interface palette: muted slate surfaces, warm readable text, and restrained
// accents keep menus comfortable without competing with gameplay bullets.
UI_MENU_BACKGROUND :: rl.Color{31, 39, 54, 255}
UI_WORLD_BACKGROUND :: rl.Color{37, 42, 69, 255}
UI_WORLD_BORDER :: rl.Color{73, 139, 166, 220}
UI_TITLE :: rl.Color{238, 242, 235, 255}
UI_PRIMARY :: rl.Color{224, 231, 232, 255}
UI_SECONDARY :: rl.Color{177, 193, 198, 255}
UI_MUTED :: rl.Color{132, 151, 160, 255}
UI_ACCENT :: rl.Color{116, 194, 190, 255}
UI_ACCENT_SOFT :: rl.Color{78, 133, 145, 255}
UI_PANEL :: rl.Color{45, 57, 76, 245}
UI_PANEL_BORDER :: rl.Color{111, 177, 181, 220}
UI_CARD :: rl.Color{222, 226, 220, 255}
UI_CARD_HOVER :: rl.Color{239, 236, 220, 255}
UI_CARD_TEXT :: rl.Color{38, 48, 58, 255}
UI_CARD_SECONDARY :: rl.Color{79, 94, 99, 255}
UI_HP :: rl.Color{242, 133, 117, 255}
UI_BOSS :: rl.Color{240, 153, 135, 255}
UI_WARNING :: rl.Color{211, 177, 116, 255}
UI_DANGER :: rl.Color{126, 52, 62, 245}
UI_GOOD :: rl.Color{105, 196, 151, 245}
UI_OVERLAY :: rl.Color{12, 18, 28, 220}
UI_BAR_BACKGROUND :: rl.Color{72, 82, 94, 255}

draw :: proc(game: ^Game) {
	rl.BeginDrawing()
	defer rl.EndDrawing()
	if game.phase == .Dialog {
		rl.ClearBackground(rl.BLACK)
		draw_dialog_scene(game)
		return
	}
	if game.phase == .Title {
		draw_menu_background()
		draw_title_menu(game)
		return
	}
	if game.phase == .Options {
		draw_menu_background()
		draw_options_menu(game)
		return
	}
	if game.phase == .Encyclopedia {
		draw_menu_background()
		draw_encyclopedia(game)
		return
	}
	draw_world_background(game)
	draw_bullets(game)
	draw_enemies(game)
	draw_explosion(game)
	draw_player(game)
	draw_hud(game)
}

draw_menu_background :: proc() {
	rl.ClearBackground(UI_MENU_BACKGROUND)
}

draw_dialog_scene :: proc(game: ^Game) {
	rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, UI_OVERLAY)
	draw_text_wrapped(string(dialog_text(game.dialog_page)), 170, 275, 34, 940, UI_PRIMARY)
	if game.dialog_page < 1 {
		centered_text("ENTER / SPACE  CONTINUE", 590, 18, UI_SECONDARY)
	} else {
		centered_text("ENTER / SPACE  ENTER THE ARENA", 590, 18, UI_SECONDARY)
	}
}

dialog_text :: proc(page: i32) -> cstring {
	switch page {
	case 0:
		return "I know you are anxious, but stay focused."
	case 1:
		return "You need to destroy them now."
	}
	return "I am ready."
}

draw_world_background :: proc(game: ^Game) {
	rl.ClearBackground(UI_WORLD_BACKGROUND)
	for i in 0..<24 {
		center := rl.Vector2{f32((i * 113 + 31) % SCREEN_W), f32((i * 71 + 17) % SCREEN_H)}
		rl.DrawCircleV(center, 1.5, {95, 150, 195, 120})
	}
	rl.DrawRectangleLinesEx({3, 3, SCREEN_W - 6, SCREEN_H - 6}, 3, UI_WORLD_BORDER)
}

draw_title_menu :: proc(game: ^Game) {
	centered_text("PROJECT WHITE", 155, 86, UI_TITLE)
	centered_text("A ROGUELIKE BULLET HELL", 250, 22, UI_SECONDARY)
	rl.DrawRectangle(SCREEN_W / 2 - 190, 330, 380, 66, UI_PANEL)
	centered_text("PRESS ENTER TO START", 350, 24, UI_PRIMARY)
	centered_text(rl.TextFormat("BEST SCORE: %i", game.best_score), 400, 18, UI_SECONDARY)
	centered_text("O  OPTIONS", 435, 20, UI_SECONDARY)
	centered_text("E  ENEMY ENCYCLOPEDIA", 475, 20, UI_SECONDARY)
	centered_text("WASD MOVE     MOUSE/IJKL AIM     AUTO FIRE     LEFT CLICK DASH", 625, 16, UI_MUTED)
}

draw_options_menu :: proc(game: ^Game) {
	centered_text("OPTIONS", 120, 56, UI_TITLE)
	draw_option_line(game, 2, "P   SHOW FPS", "ON" if game.show_fps else "OFF", 270)
	draw_option_line(game, 3, "K   KEYBOARD AIM (IJKL)", "ON" if game.keyboard_aim else "OFF", 335)
	draw_option_line(game, 4, "PARRY KEY", parry_key_name(game), 400)
	draw_option_line(game, 5, "BACKGROUND MUSIC", music_name(game.audio), 465)
	draw_option_line(game, 6, "MUSIC VOLUME", volume_percent(game.audio.music_volume), 530)
	draw_option_line(game, 7, "EFFECTS VOLUME", volume_percent(game.audio.effects_volume), 595)
	centered_text("UP / DOWN SELECT   LEFT / RIGHT CHANGE   ENTER TOGGLE", 670, 14, UI_SECONDARY)
	centered_text("B   BACK TO TITLE     ESC   QUIT", 705, 18, UI_MUTED)
}

volume_percent :: proc(volume: f32) -> cstring {
	return rl.TextFormat("%i%%", i32(volume * 100))
}

draw_option_line :: proc(game: ^Game, index: i32, label, value: cstring, y: i32) {
	if game.options_cursor == index {
		rl.DrawRectangle(SCREEN_W / 2 - 360, y - 10, 720, 66, UI_PANEL)
		rl.DrawRectangleLinesEx({f32(SCREEN_W / 2 - 360), f32(y - 10), 720, 66}, 2, UI_PANEL_BORDER)
	}
	centered_text(label, y, 20, UI_PRIMARY)
	centered_text(value, y + 27, 18, UI_ACCENT)
}

draw_encyclopedia :: proc(game: ^Game) {
	centered_text("ENEMY ENCYCLOPEDIA", 70, 44, UI_TITLE)
	centered_text("FIELD GUIDE TO ENCOUNTERED ENTITIES", 120, 16, UI_SECONDARY)
	draw_enemy_entry(game, .Chaser, 150)
	draw_enemy_entry(game, .Shooter, 230)
	draw_enemy_entry(game, .Turret, 310)
	draw_enemy_entry(game, .Dasher, 390)
	draw_enemy_entry(game, .Bomber, 470)
	draw_enemy_entry(game, .Volatile, 550)
	draw_enemy_entry(game, .Boss, 630)
	centered_text("B  BACK", 680, 18, UI_SECONDARY)
}

draw_enemy_entry :: proc(game: ^Game, kind: Enemy_Kind, y: i32) {
	if !enemy_discovered(game, kind) {
		centered_text(rl.TextFormat("???  [DISCOVER THIS ENEMY]"), y, 20, UI_MUTED)
		return
	}
	centered_text(rl.TextFormat("%s  —  %s", enemy_name(kind), enemy_description(kind)), y, 18, UI_PRIMARY)
}

draw_bullets :: proc(game: ^Game) {
	for bullet in game.bullets {
		if !bullet.active { continue }
		color := rl.WHITE if bullet.kind == .Player else rl.Color{241, 108, 103, 255}
		trail := normalized(bullet.vel)
		rl.DrawLineEx(vec_sub(bullet.pos, vec_scale(trail, 10)), bullet.pos, bullet.radius * 1.5, {color.r, color.g, color.b, 100})
		rl.DrawCircleV(bullet.pos, bullet.radius, color)
	}
}

draw_explosion :: proc(game: ^Game) {
	if game.explosion_timer <= 0 {
		return
	}
	scale := 1.0 - game.explosion_timer / 0.35
	if game.explosion_global {
		rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, {222, 74, 66, 80})
	}
	rl.DrawCircleV(game.explosion_pos, game.explosion_radius * scale, {245, 100, 35, 100})
	rl.DrawCircleLinesV(game.explosion_pos, game.explosion_radius * scale, {255, 220, 120, 220})
}

draw_enemies :: proc(game: ^Game) {
	for enemy in game.enemies {
		if !enemy.active { continue }
		size := enemy_size(enemy.kind)
		color := enemy_color(enemy.kind)
		if enemy.kind == .Dasher {
			rl.DrawTriangle(
				{enemy.pos.x, enemy.pos.y - size / 2},
				{enemy.pos.x - size / 2, enemy.pos.y + size / 2},
				{enemy.pos.x + size / 2, enemy.pos.y + size / 2}, color)
		} else if enemy.kind == .Bomber {
			pulse := 1.0 + f32((1.0 + math.sin(f32(rl.GetTime()) * 8)) * 0.08)
			rl.DrawCircleV(enemy.pos, size * 0.55 * pulse, color)
		} else if enemy.kind == .Volatile {
			rl.DrawCircleV(enemy.pos, size * 0.55, color)
			rl.DrawCircleLinesV(enemy.pos, size * 0.55, rl.WHITE)
		} else {
			rl.DrawRectangleRec(centered_rect(enemy.pos, size), color)
		}
		if enemy.kind == .Chaser || enemy.kind == .Shooter || enemy.kind == .Dasher || enemy.kind == .Bomber || enemy.kind == .Volatile {
			direction := normalized(vec_sub(game.player_pos, enemy.pos))
			rl.DrawLineEx(enemy.pos, vec_add(enemy.pos, vec_scale(direction, 22)), 5, color)
		} else {
			rl.DrawCircleLinesV(enemy.pos, size / 2 - 4, rl.WHITE)
		}
		if enemy.kind == .Boss {
			rl.DrawRectangleLinesEx(centered_rect(enemy.pos, size), 3, rl.RED)
			rl.DrawRectangleRec({enemy.pos.x - 35, enemy.pos.y - 46, 70, 5}, UI_BAR_BACKGROUND)
			rl.DrawRectangleRec({enemy.pos.x - 35, enemy.pos.y - 46, 70 * f32(enemy.health) / f32(enemy_health_for_run(.Boss, game.wave, game.damage)), 5}, rl.RED)
		}
		rl.DrawRectangleLinesEx(centered_rect(enemy.pos, size), 2, {255, 255, 255, 110})
	}
}

enemy_color :: proc(kind: Enemy_Kind) -> rl.Color {
	switch kind {
	case .Chaser: return {116, 128, 150, 255}
	case .Shooter: return {154, 142, 184, 255}
	case .Turret: return {100, 178, 190, 255}
	case .Dasher: return {232, 166, 92, 255}
	case .Bomber: return {220, 91, 83, 255}
	case .Volatile: return {194, 117, 210, 255}
	case .Boss: return {218, 105, 120, 255}
	}
	return UI_MUTED
}

draw_player :: proc(game: ^Game) {
	if game.invulnerability_timer > 0 && i32(game.invulnerability_timer * 12) % 2 == 0 { return }
	aim := player_aim_direction(game)
	rl.DrawCircleV(game.player_pos, game.player_size * 1.3, {90, 210, 235, 35})
	rl.DrawLineEx(game.player_pos, vec_add(game.player_pos, vec_scale(aim, 25)), 7, rl.WHITE)
	rl.DrawRectangleRec(centered_rect(game.player_pos, game.player_size), rl.WHITE)
	rl.DrawRectangleLinesEx(centered_rect(game.player_pos, game.player_size), 2, rl.BLACK)
}

draw_hud :: proc(game: ^Game) {
	rl.DrawText(rl.TextFormat("SCORE  %04i", game.score), 18, 16, 24, UI_PRIMARY)
	rl.DrawText(rl.TextFormat("HP  %i/%i", game.health, game.max_health), 18, 44, 22, UI_HP)
	rl.DrawText(rl.TextFormat("WAVE  %i%s    %s", game.wave, " ENDLESS" if game.endless_mode else "", weapon_name(game.weapon)), 18, 72, 20, UI_ACCENT)
	if game.encounter_state == .Active && !game.wave_director_done {
		rl.DrawText(rl.TextFormat("ENCOUNTER %i/%i  %s", game.encounter_index + 1, game.encounter_plan_count, encounter_name(game.encounter_kind)), 830, 72, 18, UI_SECONDARY)
	} else if !game.wave_director_done {
		rl.DrawText("NEXT ENCOUNTER", 930, 72, 18, UI_MUTED)
	}
	if game.enemy_mutation_level > 0 {
		rl.DrawText(rl.TextFormat("ENEMY MUTATION TIER %i", game.enemy_mutation_level), 18, 128, 16, UI_WARNING)
	}
	if game.wave_director_done && wave_has_boss(game.wave) {
		rl.DrawText(rl.TextFormat("BOSS PHASE  %s", boss_phase_name(game.boss_phase)), 830, 100, 18, UI_BOSS)
	}
	rl.DrawText("WASD MOVE    MOUSE/IJKL AIM    AUTO FIRE    P PAUSE", 18, SCREEN_H - 30, 16, UI_SECONDARY)
	if game.phase == .Playing {
		rl.DrawRectangleRec(pause_button_rect(), UI_PANEL)
		rl.DrawRectangleLinesEx(pause_button_rect(), 2, UI_PANEL_BORDER)
		centered_card_text("PAUSE  [P]", PAUSE_BUTTON_X, PAUSE_BUTTON_Y + 11, PAUSE_BUTTON_WIDTH, 16, UI_PRIMARY)
	}
	if game.dash_unlocked {
		rl.DrawText(rl.TextFormat("DASH  %s", "READY" if game.dash_cooldown <= 0 else "COOLDOWN"), 18, 100, 18, UI_SECONDARY)
	}
	if game.parry_active {
		rl.DrawRectangle(300, 105, 680, 56, UI_DANGER)
		centered_text(rl.TextFormat("BOMB INCOMING — TIME %s IN THE ZONE  %.1fs", parry_key_name(game), game.parry_timer), 122, 20, UI_PRIMARY)
		draw_parry_skill_check(game)
	} else if game.endless_mode && game.parry_cooldown > 0 {
		rl.DrawText(rl.TextFormat("PARRY COOLDOWN  %.1fs", game.parry_cooldown), 18, 124, 16, UI_SECONDARY)
	}
	if game.show_fps { rl.DrawFPS(SCREEN_W - 90, 16) }
	if game.phase == .Upgrade {
		draw_upgrade_menu(game)
	}
	if game.phase == .GameOver {
		draw_game_over(game)
	}
	if game.phase == .Paused {
		draw_pause_menu(game)
	}
}

draw_pause_menu :: proc(game: ^Game) {
	x: i32 = SCREEN_W / 2 - PAUSE_MENU_WIDTH / 2
	y: i32 = 215
	rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, UI_OVERLAY)
	rl.DrawRectangle(x, y, PAUSE_MENU_WIDTH, PAUSE_MENU_HEIGHT, UI_PANEL)
	rl.DrawRectangleLinesEx({f32(x), f32(y), f32(PAUSE_MENU_WIDTH), f32(PAUSE_MENU_HEIGHT)}, 2, UI_PANEL_BORDER)
	centered_text("PAUSED", 245, 34, UI_TITLE)
	centered_text("SIMULATION FROZEN", 278, 16, UI_SECONDARY)
	draw_pause_button("RESUME", pause_resume_rect(), rl.CheckCollisionPointRec(rl.GetMousePosition(), pause_resume_rect()))
	draw_pause_button("RETURN TO TITLE", pause_title_rect(), rl.CheckCollisionPointRec(rl.GetMousePosition(), pause_title_rect()))
	centered_text("P / ENTER  RESUME     T  TITLE", 430, 15, UI_MUTED)
}

draw_pause_button :: proc(label: cstring, rect: rl.Rectangle, hovered: bool) {
	color := UI_CARD_HOVER if hovered else UI_CARD
	border := UI_ACCENT if hovered else UI_CARD_SECONDARY
	rl.DrawRectangleRec(rect, color)
	rl.DrawRectangleLinesEx(rect, 2, border)
	rl.DrawText(label, i32(rect.x + (rect.width - f32(rl.MeasureText(label, 18))) / 2), i32(rect.y + 14), 18, UI_CARD_TEXT)
}

draw_parry_skill_check :: proc(game: ^Game) {
	x: i32 = 360
	y: i32 = 170
	width: i32 = 560
	height: i32 = 24
	rl.DrawRectangle(x, y, width, height, UI_BAR_BACKGROUND)
	zone_x := x + i32(game.parry_skill_zone_start * f32(width))
	zone_width := i32((game.parry_skill_zone_end - game.parry_skill_zone_start) * f32(width))
	rl.DrawRectangle(zone_x, y, zone_width, height, UI_GOOD)
	marker_x := x + i32(clamp(game.parry_skill_position, 0.0, 1.0) * f32(width))
	rl.DrawRectangle(marker_x - 3, y - 7, 6, height + 14, rl.WHITE)
	rl.DrawRectangleLines(x, y, width, height, rl.WHITE)
}

draw_game_over :: proc(game: ^Game) {
	rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, UI_OVERLAY)
	centered_text("THE PURITY COMMITTEE HAS ADJOURNED", 42, 32, UI_TITLE)
	centered_text(rl.TextFormat("FINAL SCORE: %i    BEST: %i    WAVE: %i", game.score, game.best_score, game.wave), 86, 22, UI_SECONDARY)
	centered_text(end_run_phrase(game), 124, 18, UI_SECONDARY)
	rl.DrawText("POWERUPS ACQUIRED", 90, 185, 22, UI_PRIMARY)
	draw_powerup_summary(game, .Heal, 90, 225)
	draw_powerup_summary(game, .Damage, 90, 270)
	draw_powerup_summary(game, .RapidFire, 90, 315)
	draw_powerup_summary(game, .Shotgun, 90, 360)
	draw_powerup_summary(game, .Burst, 90, 405)
	draw_powerup_summary(game, .MaxHealth, 90, 450)
	draw_powerup_summary(game, .Speed, 560, 225)
	draw_powerup_summary(game, .Invulnerability, 560, 270)
	draw_powerup_summary(game, .Dash, 560, 315)
	if total_powerups(game) == 0 {
		rl.DrawText("No powerups acquired.", 90, 225, 18, UI_SECONDARY)
	}
	rl.DrawText("PLAYER'S ACCOUNT", 90, 525, 18, UI_PRIMARY)
	draw_text_wrapped(string(player_perspective(game)), 90, 552, 15, 1100, UI_SECONDARY)
	rl.DrawText("B  BACK", 720, 685, 18, UI_SECONDARY)
	rl.DrawText("E  ENCYCLOPEDIA", 900, 685, 18, UI_SECONDARY)
	rl.DrawText("R  RESTART", 1080, 685, 18, UI_SECONDARY)
}

draw_powerup_summary :: proc(game: ^Game, upgrade: Upgrade_Kind, x, y: i32) {
	count := powerup_count(game, upgrade)
	if count == 0 {
		return
	}
	rl.DrawText(rl.TextFormat("%s  x%i", upgrade_name(upgrade), count), x, y, 18, UI_PRIMARY)
	draw_text_wrapped(string(upgrade_description(upgrade)), x, y + 22, 14, 310, UI_SECONDARY)
}

powerup_count :: proc(game: ^Game, upgrade: Upgrade_Kind) -> i32 {
	switch upgrade {
	case .Heal: return game.powerup_counts[0]
	case .Damage: return game.powerup_counts[1]
	case .RapidFire: return game.powerup_counts[2]
	case .Shotgun: return game.powerup_counts[3]
	case .Burst: return game.powerup_counts[4]
	case .MaxHealth: return game.powerup_counts[5]
	case .Speed: return game.powerup_counts[6]
	case .Invulnerability: return game.powerup_counts[7]
	case .Dash: return game.powerup_counts[8]
	}
	return 0
}

total_powerups :: proc(game: ^Game) -> i32 {
	total: i32
	for count in game.powerup_counts {
		total += count
	}
	return total
}

end_run_phrase :: proc(game: ^Game) -> cstring {
	if game.wave >= 10 { return "The square survived long enough to file an appeal." }
	if game.wave >= 5 { return "A respectable geometric scandal." }
	return "The committee recommends more evasive paperwork."
}

player_perspective :: proc(game: ^Game) -> cstring {
	if game.wave >= 10 {
		return "I made it farther than the others because I learned to call suspicion strategy. I treated my own whiteness as proof of order and darker shapes as proof of danger. Every collision became an accusation, and every upgrade became proof that my hierarchy was right. The report disagrees: the system was mine, the fear was mine, and neither was a reliable reading of the world."
	}
	if game.wave >= 5 {
		return "I kept sorting the arena into clean shapes and threatening shapes. I called my own color superior and treated darker shapes as lesser. It felt like reason while I was inside it. From the outside, it looks like racism wearing a uniform: these were opponents in a game, and the hierarchy existed only in my head."
	}
	return "I said the arena was simple: my color on one side, everyone else on the other. I mistook whiteness for virtue and difference for danger. That was my interpretation, not a fact. The archivist's note is less flattering: I was frightened, racist, and very confident in ideas I had invented."
}

draw_upgrade_menu :: proc(game: ^Game) {
	rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, UI_OVERLAY)
	centered_text(rl.TextFormat("WAVE %i CLEARED", game.wave), 90, 38, UI_TITLE)
	centered_text("CHOOSE A POWERUP  (CLICK A CARD)", 140, 22, UI_SECONDARY)
	draw_upgrade_card(game, (SCREEN_W / 2) - 285, game.upgrade_options[0])
	draw_upgrade_card(game, (SCREEN_W / 2) + 15, game.upgrade_options[1])
}

draw_upgrade_card :: proc(game: ^Game, x: i32, upgrade: Upgrade_Kind) {
	rect := rl.Rectangle{f32(x), 205, 270, 220}
	hovered := rl.CheckCollisionPointRec(rl.GetMousePosition(), rect)
	card_color := UI_CARD_HOVER if hovered else UI_CARD
	border_color := UI_ACCENT if hovered else UI_CARD_SECONDARY
	rl.DrawRectangleRec(rect, card_color)
	rl.DrawRectangleLinesEx(rect, 3 if hovered else 2, border_color)
	centered_card_text("CLICK", x, 220, 270, 16, UI_CARD_TEXT)
	draw_text_wrapped(string(upgrade_name(upgrade)), x + 18, 270, 20, 234, UI_CARD_TEXT)
	draw_text_wrapped(string(upgrade_description(upgrade)), x + 18, 315, 16, 234, UI_CARD_SECONDARY)
}

centered_card_text :: proc(text: cstring, x, y, width, size: i32, color: rl.Color) {
	rl.DrawText(text, x + (width - rl.MeasureText(text, size)) / 2, y, size, color)
}

centered_text :: proc(text: cstring, y, size: i32, color: rl.Color) {
	w := rl.MeasureText(text, size)
	rl.DrawText(text, (SCREEN_W - w) / 2, y, size, color)
}

draw_text_wrapped :: proc(text: string, x, y : i32, font_size: i32, max_width: f32, color: rl.Color) {
	context.allocator = context.temp_allocator
	words := strings.split(text, " ")
	
	sb := strings.builder_make()
	current_line_width: f32 = 0.0

	font := rl.GetFontDefault()
	spacing: f32 = f32(font_size) / 10.0

	for word, index in words {
		word_with_space := index == 0 ? word : fmt.tprint(" ", word)
		word_width := rl.MeasureTextEx(font, strings.clone_to_cstring(word_with_space), f32(font_size), spacing).x
		if current_line_width + word_width > max_width {
			strings.write_string(&sb, "\n")
			strings.write_string(&sb, word)
			current_line_width = rl.MeasureTextEx(font, strings.clone_to_cstring(word), f32(font_size), spacing).x
		} else {
			strings.write_string(&sb, word_with_space)
			current_line_width += word_width
		}
	}

	final_text := strings.to_string(sb)
	c_text := strings.clone_to_cstring(final_text)

	rl.DrawTextEx(font, c_text, {f32(x), f32(y)}, f32(font_size), spacing, color)
}
