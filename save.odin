package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

SAVE_FILE :: "whiteout_save.dat"
SAVE_VERSION :: "WHITEOUT_SAVE_V4"

load_progress :: proc(game: ^Game, audio: ^Audio_State ) {
	data, err := os.read_entire_file(SAVE_FILE, context.temp_allocator)
	if err != nil {
		return
	}

	lines, split_err := strings.split_lines(string(data), context.temp_allocator)
	if split_err != nil || len(lines) < 3 || lines[0] != SAVE_VERSION {
		return
	}

	for line in lines {
		fields, field_err := strings.split(line, " ", context.temp_allocator)
		if field_err != nil || len(fields) < 2 {
			continue
		}

		switch fields[0] {
		case "BEST_SCORE":
			value, ok := strconv.parse_int(fields[1])
			if ok && value >= 0 {
				game.best_score = i32(value)
			}
		case "DISCOVERED":
			load_discovered_flags(game, fields[1])
		case "PREFERENCES":
			game.show_fps = fields[1] == "1"
			game.keyboard_aim = fields[2] == "1"
			value, ok := strconv.parse_int(fields[3])
			if ok && value >= 0 {
				game.parry_key_index = i32(value)
			}
			value, ok = strconv.parse_int(fields[4])
			if ok && value >= 0 {
				game.music_index = i32(value)
				audio.selected_music = game.music_index
			}
			value_f, ok_f := strconv.parse_f32(fields[5])
			if ok_f && value_f >= 0.0 {
				audio.music_volume = f32(value_f)
			}
			value_f, ok_f = strconv.parse_f32(fields[6])
			if ok_f && value_f >= 0.0 {
				audio.effects_volume = f32(value_f)
			}
		}
	}
}

load_discovered_flags :: proc(game: ^Game, flags: string) {
	for i in 0..<min(len(flags), len(game.discovered_enemies)) {
		if flags[i] == '1' {
			game.discovered_enemies[i] = true
		}
	}
}


save_progress :: proc(game: ^Game) {
	if game.score > game.best_score {
		game.best_score = game.score
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	fmt.sbprintfln(&builder, "%s", SAVE_VERSION)
	fmt.sbprintfln(&builder, "BEST_SCORE %i", game.best_score)
	fmt.sbprintf(&builder, "DISCOVERED ")
	for discovered in game.discovered_enemies {
		fmt.sbprintf(&builder, "%c", '0' if !discovered else '1')
	}
	fmt.sbprintf(&builder, "\n")
	fmt.sbprintf(&builder, "PREFERENCES ")
	fmt.sbprintf(&builder, "%c", '0' if !game.show_fps else '1')
	fmt.sbprintf(&builder, " %c", '0' if !game.keyboard_aim else '1')
	fmt.sbprintf(&builder, " %i", game.parry_key_index)
	fmt.sbprintf(&builder, " %i", game.music_index)
	fmt.sbprintf(&builder, " %f", game.audio.music_volume)
	fmt.sbprintf(&builder, " %f", game.audio.effects_volume)

	_ = os.write_entire_file(SAVE_FILE, strings.to_string(builder))
}
