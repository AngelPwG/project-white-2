package main

import "core:c"
import "core:math"
import rl "vendor:raylib"

AUDIO_SAMPLE_RATE :: 22050
SHOOT_SAMPLE_COUNT :: 2205
HIT_SAMPLE_COUNT :: 3307
DEATH_SAMPLE_COUNT :: 11025
MUSIC_SAMPLE_COUNT :: 132300
MUSIC_PATHS :: [13]cstring{
    "music/All_Clear_01_loop.ogg",
    "music/All_Clear_02_loop.ogg",
    "music/Midboss_01_loop.ogg",
    "music/Midboss_02_loop.ogg",
    "music/Shooter_Boss_01_loop.ogg",
    "music/Shooter_Boss_02_loop.ogg",
    "music/Shooter_Shop_01_loop.ogg",
    "music/Shooter_Shop_02_loop.ogg",
    "music/Spell_Card_01_loop.ogg",
    "music/Spell_Card_02_loop.ogg",
    "music/Stage_One_01_loop.ogg",
    "music/Stage_One_02_loop.ogg",
    "music/FROL.mp3",
}
MUSIC_NAMES := [13]cstring{
    "All Clear 01",
    "All Clear 02",
    "Midboss 01",
    "Midboss 02",
    "Shooter Boss 01",
    "Shooter Boss 02",
    "Shooter Shop 01",
    "Shooter Shop 02",
    "Spell Card 01",
    "Spell Card 02",
    "Stage One 01",
    "Stage One 02",
    "FROL",
}
SHOOT_SOUND_PATH :: "sound-effects/plshoot.wav"
HIT_SOUND_PATH :: "sound-effects/damage.wav"
DEATH_SOUND_PATH :: "sound-effects/pldead.wav"

Audio_State :: struct {
	ready: bool,
	shoot: rl.Sound,
	hit: rl.Sound,
	death: rl.Sound,
	fallback_music: rl.Sound,
	music_tracks: [13]rl.Music,
	music_track_count: i32,
	selected_music: i32,
	music_playing: bool,
	music_volume: f32,
	effects_volume: f32,
	shoot_samples: [SHOOT_SAMPLE_COUNT]i16,
	hit_samples: [HIT_SAMPLE_COUNT]i16,
	death_samples: [DEATH_SAMPLE_COUNT]i16,
	music_samples: [MUSIC_SAMPLE_COUNT]i16,
}

init_audio :: proc(audio: ^Audio_State) {
	audio.music_volume = 0.25
	audio.effects_volume = 0.25
	rl.InitAudioDevice()
	if !rl.IsAudioDeviceReady() {
		return
	}

	generate_audio_samples(audio)
	audio.shoot = sound_from_samples(audio.shoot_samples[:])
	audio.hit = sound_from_samples(audio.hit_samples[:])
	audio.death = sound_from_samples(audio.death_samples[:])
	audio.fallback_music = sound_from_samples(audio.music_samples[:])
	load_sound_effects(audio)
	for path in MUSIC_PATHS {
		track := rl.LoadMusicStream(path)
		if rl.IsMusicValid(track) && audio.music_track_count < len(audio.music_tracks) {
			audio.music_tracks[audio.music_track_count] = track
			audio.music_track_count += 1
		}
	}
	audio.ready = true
	audio.music_playing = false
	rl.SetSoundVolume(audio.shoot, 0.12)
	set_effects_volume(audio)
	set_music_volume(audio)
	select_music(audio, 0)
}

load_sound_effects :: proc(audio: ^Audio_State) {
	shoot := rl.LoadSound(SHOOT_SOUND_PATH)
	if rl.IsSoundValid(shoot) {
		rl.UnloadSound(audio.shoot)
		audio.shoot = shoot
	}
	hit := rl.LoadSound(HIT_SOUND_PATH)
	if rl.IsSoundValid(hit) {
		rl.UnloadSound(audio.hit)
		audio.hit = hit
	}
	death := rl.LoadSound(DEATH_SOUND_PATH)
	if rl.IsSoundValid(death) {
		rl.UnloadSound(audio.death)
		audio.death = death
	}
}

shutdown_audio :: proc(audio: ^Audio_State) {
	if !audio.ready {
		return
	}
	rl.UnloadSound(audio.shoot)
	rl.UnloadSound(audio.hit)
	rl.UnloadSound(audio.death)
	rl.UnloadSound(audio.fallback_music)
	for i in 0..<audio.music_track_count {
		rl.UnloadMusicStream(audio.music_tracks[i])
	}
	rl.CloseAudioDevice()
	audio.ready = false
}

update_audio :: proc(audio: ^Audio_State) {
	if !audio.ready {
		return
	}
	// The opening dialog keeps music_playing false until it is dismissed.
	if !audio.music_playing {
		return
	}
	if audio.music_track_count > 0 {
		track := &audio.music_tracks[audio.selected_music]
		rl.UpdateMusicStream(track^)
		if !rl.IsMusicStreamPlaying(track^) {
			rl.PlayMusicStream(track^)
		}
	} else if !rl.IsSoundPlaying(audio.fallback_music) {
		rl.PlaySound(audio.fallback_music)
	}
}

select_music :: proc(audio: ^Audio_State, index: i32) {
	if audio == nil || !audio.ready {
		return
	}
	if audio.music_track_count == 0 {
		return
	}
	audio.selected_music = clamp(index, 0, audio.music_track_count - 1)
	for i in 0..<audio.music_track_count {
		rl.StopMusicStream(audio.music_tracks[i])
	}
	rl.SetMusicVolume(audio.music_tracks[audio.selected_music], audio.music_volume)
	if audio.music_playing {
		rl.PlayMusicStream(audio.music_tracks[audio.selected_music])
	}
}

change_music_volume :: proc(audio: ^Audio_State, direction: i32) {
	if audio == nil { return }
	audio.music_volume = clamp(audio.music_volume + f32(direction) * 0.05, 0.0, 1.0)
	set_music_volume(audio)
}

change_effects_volume :: proc(audio: ^Audio_State, direction: i32) {
	if audio == nil { return }
	audio.effects_volume = clamp(audio.effects_volume + f32(direction) * 0.05, 0.0, 1.0)
	set_effects_volume(audio)
}

set_music_volume :: proc(audio: ^Audio_State) {
	if audio == nil || !audio.ready { return }
	for i in 0..<audio.music_track_count {
		rl.SetMusicVolume(audio.music_tracks[i], audio.music_volume)
	}
	rl.SetSoundVolume(audio.fallback_music, audio.music_volume * 0.625)
}

set_effects_volume :: proc(audio: ^Audio_State) {
	if audio == nil || !audio.ready { return }
	factor := audio.effects_volume / 0.25
	rl.SetSoundVolume(audio.shoot, 0.12 * factor)
	rl.SetSoundVolume(audio.hit, 0.25 * factor)
	rl.SetSoundVolume(audio.death, 0.32 * factor)
}

start_music :: proc(audio: ^Audio_State) {
	if audio == nil || !audio.ready {
		return
	}
	audio.music_playing = true
	if audio.music_track_count > 0 {
		rl.PlayMusicStream(audio.music_tracks[audio.selected_music])
	} else if !rl.IsSoundPlaying(audio.fallback_music) {
		rl.PlaySound(audio.fallback_music)
	}
}

music_name :: proc(audio: ^Audio_State) -> cstring {
	if audio == nil || audio.music_track_count == 0 {
		return "PROCEDURAL FALLBACK"
	}
	return MUSIC_NAMES[audio.selected_music]
}

play_shoot_sound :: proc(audio: ^Audio_State) {
	if audio != nil && audio.ready {
		rl.PlaySound(audio.shoot)
	}
}

play_hit_sound :: proc(audio: ^Audio_State) {
	if audio != nil && audio.ready {
		rl.PlaySound(audio.hit)
	}
}

play_death_sound :: proc(audio: ^Audio_State) {
	if audio != nil && audio.ready {
		rl.PlaySound(audio.death)
	}
}

sound_from_samples :: proc(samples: []i16) -> rl.Sound {
	wave := rl.Wave{
		frameCount = cast(c.uint)len(samples),
		sampleRate = AUDIO_SAMPLE_RATE,
		sampleSize = 16,
		channels = 1,
		data = rawptr(&samples[0]),
	}
	return rl.LoadSoundFromWave(wave)
}

generate_audio_samples :: proc(audio: ^Audio_State) {
	for i in 0..<SHOOT_SAMPLE_COUNT {
		t := f32(i) / f32(AUDIO_SAMPLE_RATE)
		envelope := 1.0 - f32(i) / f32(SHOOT_SAMPLE_COUNT)
		audio.shoot_samples[i] = i16(16000 * envelope * math.sin(2 * math_pi() * (440 + t * 500) * t))
	}

	for i in 0..<HIT_SAMPLE_COUNT {
		t := f32(i) / f32(AUDIO_SAMPLE_RATE)
		envelope := 1.0 - f32(i) / f32(HIT_SAMPLE_COUNT)
		audio.hit_samples[i] = i16(18000 * envelope * math.sin(2 * math_pi() * 120 * t))
	}

	for i in 0..<DEATH_SAMPLE_COUNT {
		t := f32(i) / f32(AUDIO_SAMPLE_RATE)
		envelope := 1.0 - f32(i) / f32(DEATH_SAMPLE_COUNT)
		frequency := 280 - 180 * t
		audio.death_samples[i] = i16(20000 * envelope * math.sin(2 * math_pi() * frequency * t))
	}

	// A quiet four-note arpeggio acts as an unobtrusive looping soundtrack.
	notes := [4]f32{110, 138.59, 164.81, 220}
	for i in 0..<MUSIC_SAMPLE_COUNT {
		t := f32(i) / f32(AUDIO_SAMPLE_RATE)
		beat := i / (AUDIO_SAMPLE_RATE / 2)
		frequency := notes[beat % len(notes)]
		note_time := f32(i % (AUDIO_SAMPLE_RATE / 2)) / f32(AUDIO_SAMPLE_RATE / 2)
		envelope := 0.55 - 0.35 * note_time
		value := math.sin(2 * math_pi() * frequency * t) + 0.35 * math.sin(2 * math_pi() * frequency * 2 * t)
		audio.music_samples[i] = i16(9000 * envelope * value)
	}
}
