extends SceneTree
## Генератор звука Knight Quest: пишет WAV-файлы (SFX + две музыкальные темы).
## Запуск: godot --headless --path . --script res://tools/gen_audio.gd

const OUT := "res://audio/"
const RATE := 22050

var noise_state := 12345

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	print("=== Генерация звука ===")
	gen_sfx()
	gen_music()
	print("=== Готово ===")
	quit()

# ---------------------------------------------------------------- буфер / микшер
func new_buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE) + 1)
	b.fill(0.0)
	return b

func noise() -> float:
	noise_state = (noise_state * 1103515245 + 12345) & 0x7FFFFFFF
	return float(noise_state % 20000) / 10000.0 - 1.0

func wave_value(kind: String, phase: float, duty := 0.5) -> float:
	match kind:
		"square":
			return 1.0 if fmod(phase, 1.0) < duty else -1.0
		"saw":
			return 2.0 * fmod(phase, 1.0) - 1.0
		"tri":
			var p := fmod(phase, 1.0)
			return 4.0 * absf(p - 0.5) - 1.0
		"sine":
			return sin(phase * TAU)
		"noise":
			return noise()
	return 0.0

## Добавляет ноту в буфер.
## start/dur в секундах, freq в Гц (или -1 для шума), attack/release в секундах.
func note(buf: PackedFloat32Array, start: float, dur: float, freq: float, kind: String,
		vol: float, attack := 0.005, release := 0.06, glide := 0.0, duty := 0.5) -> void:
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	var phase := 0.0
	for i in n:
		var idx := i0 + i
		if idx < 0 or idx >= buf.size():
			continue
		var t := float(i) / RATE
		var f := freq
		if glide != 0.0:
			f = freq * pow(2.0, glide * (t / maxf(dur, 0.001)))
		phase += f / RATE
		var env := 1.0
		if attack > 0.0 and t < attack:
			env = t / attack
		else:
			var rel := (dur - t)
			if rel < release:
				env = maxf(rel / release, 0.0)
		buf[idx] += wave_value(kind, phase, duty) * vol * env

func drum(buf: PackedFloat32Array, start: float, kind: String, vol := 0.35) -> void:
	match kind:
		"kick":
			var i0 := int(start * RATE)
			var n := int(0.12 * RATE)
			var phase := 0.0
			for i in n:
				var idx := i0 + i
				if idx < 0 or idx >= buf.size():
					continue
				var t := float(i) / RATE
				var f: float = 150.0 * exp(-t * 22.0) + 45.0
				phase += f / RATE
				buf[idx] += sin(phase * TAU) * vol * exp(-t * 14.0)
		"snare":
			var i0 := int(start * RATE)
			var n := int(0.12 * RATE)
			for i in n:
				var idx := i0 + i
				if idx < 0 or idx >= buf.size():
					continue
				var t := float(i) / RATE
				buf[idx] += noise() * vol * 0.6 * exp(-t * 30.0)
				buf[idx] += sin(TAU * 190.0 * t) * vol * 0.25 * exp(-t * 25.0)
		"hat":
			var i0 := int(start * RATE)
			var n := int(0.04 * RATE)
			for i in n:
				var idx := i0 + i
				if idx < 0 or idx >= buf.size():
					continue
				var t := float(i) / RATE
				buf[idx] += noise() * vol * 0.35 * exp(-t * 90.0)

func normalize(buf: PackedFloat32Array, peak := 0.86) -> PackedFloat32Array:
	var mx := 0.0
	for v in buf:
		mx = maxf(mx, absf(v))
	if mx < 0.0001:
		return buf
	var k := peak / mx
	for i in buf.size():
		buf[i] = clampf(buf[i] * k, -1.0, 1.0)
	return buf

func save_wav(name: String, buf: PackedFloat32Array) -> void:
	var path := OUT + name + ".wav"
	var data := PackedByteArray()
	for v in buf:
		var s := int(clampf(v, -1.0, 1.0) * 32000.0)
		data.append(s & 0xFF)
		data.append((s >> 8) & 0xFF)
	var hdr := PackedByteArray()
	push_str(hdr, "RIFF")
	push_u32(hdr, 36 + data.size())
	push_str(hdr, "WAVE")
	push_str(hdr, "fmt ")
	push_u32(hdr, 16)
	push_u16(hdr, 1)
	push_u16(hdr, 1)
	push_u32(hdr, RATE)
	push_u32(hdr, RATE * 2)
	push_u16(hdr, 2)
	push_u16(hdr, 16)
	push_str(hdr, "data")
	push_u32(hdr, data.size())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("ERR не могу записать ", path)
		return
	f.store_buffer(hdr)
	f.store_buffer(data)
	f.close()
	print("  audio/%s.wav  %.2f с" % [name, float(buf.size()) / RATE])

func push_str(b: PackedByteArray, s: String) -> void:
	for c in s.to_utf8_buffer():
		b.append(c)

func push_u32(b: PackedByteArray, v: int) -> void:
	b.append(v & 0xFF)
	b.append((v >> 8) & 0xFF)
	b.append((v >> 16) & 0xFF)
	b.append((v >> 24) & 0xFF)

func push_u16(b: PackedByteArray, v: int) -> void:
	b.append(v & 0xFF)
	b.append((v >> 8) & 0xFF)

# ---------------------------------------------------------------- ноты
func midi_of(name: String) -> int:
	if name == "R" or name == "":
		return -1
	var semis := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
	var i := 0
	var letter := name[0]
	var v: int = semis.get(letter, 0)
	i = 1
	while i < name.length() and (name[i] == "#" or name[i] == "b"):
		v += 1 if name[i] == "#" else -1
		i += 1
	var octave := int(name.substr(i))
	return (octave + 1) * 12 + v

func freq_of(name: String) -> float:
	var m := midi_of(name)
	if m < 0:
		return 0.0
	return 440.0 * pow(2.0, (m - 69) / 12.0)

## pattern: "C4:4 E4:2 ..." — длина в шестнадцатых
func play_pattern(buf: PackedFloat32Array, pattern: String, kind: String, vol: float,
		step: float, offset := 0.0, glide := 0.0, duty := 0.5) -> void:
	var t := offset
	for tok in pattern.split(" ", false):
		var parts := tok.split(":")
		var nm := parts[0]
		var ln := 4
		if parts.size() > 1:
			ln = int(parts[1])
		var dur := ln * step
		var m := midi_of(nm)
		if m >= 0:
			var g := 0.0
			if parts.size() > 2:
				var target := freq_of(parts[2])
				var base := freq_of(nm)
				if base > 0.0 and target > 0.0:
					g = log(target / base) / log(2.0)
			note(buf, t, dur * 0.96, freq_of(nm), kind, vol, 0.004, dur * 0.25, glide if glide != 0.0 else g, duty)
		t += dur

# ---------------------------------------------------------------- SFX
func gen_sfx() -> void:
	var buffer := new_buf(0.35)
	note(buffer, 0.0, 0.22, 320.0, "square", 0.35, 0.004, 0.06, 1.0, 0.35)
	note(buffer, 0.0, 0.10, 620.0, "square", 0.12, 0.004, 0.05, 0.6, 0.5)
	save_wav("jump", normalize(buffer, 0.7))

	buffer = new_buf(0.4)
	note(buffer, 0.0, 0.09, 988.0, "square", 0.3, 0.002, 0.03, 0.0, 0.5)
	note(buffer, 0.09, 0.22, 1319.0, "square", 0.3, 0.002, 0.16, 0.0, 0.25)
	save_wav("coin", normalize(buffer, 0.7))

	buffer = new_buf(0.3)
	note(buffer, 0.0, 0.16, 900.0, "noise", 0.4, 0.001, 0.12, 0.0)
	note(buffer, 0.02, 0.14, 1400.0, "square", 0.12, 0.002, 0.1, -0.4, 0.2)
	save_wav("slash", normalize(buffer, 0.6))

	buffer = new_buf(0.35)
	note(buffer, 0.0, 0.18, 520.0, "square", 0.3, 0.002, 0.1, -0.9, 0.35)
	note(buffer, 0.0, 0.18, 260.0, "saw", 0.18, 0.002, 0.12, -0.5)
	drum(buffer, 0.0, "snare", 0.3)
	save_wav("enemy_hit", normalize(buffer, 0.7))

	buffer = new_buf(0.3)
	drum(buffer, 0.0, "kick", 0.5)
	note(buffer, 0.0, 0.2, 180.0, "square", 0.3, 0.002, 0.12, -0.7, 0.25)
	save_wav("stomp", normalize(buffer, 0.75))

	buffer = new_buf(0.5)
	note(buffer, 0.0, 0.42, 440.0, "square", 0.3, 0.003, 0.25, -1.2, 0.5)
	drum(buffer, 0.0, "snare", 0.35)
	save_wav("hurt", normalize(buffer, 0.75))

	buffer = new_buf(1.0)
	note(buffer, 0.0, 0.9, 400.0, "saw", 0.3, 0.004, 0.5, -1.6)
	note(buffer, 0.12, 0.8, 300.0, "square", 0.2, 0.004, 0.5, -1.3, 0.3)
	drum(buffer, 0.0, "kick", 0.5)
	save_wav("death", normalize(buffer, 0.8))

	buffer = new_buf(0.28)
	drum(buffer, 0.0, "hat", 0.5)
	note(buffer, 0.0, 0.07, 1800.0, "square", 0.25, 0.001, 0.04, -0.5, 0.15)
	note(buffer, 0.09, 0.09, 1200.0, "square", 0.22, 0.001, 0.05, -0.6, 0.15)
	save_wav("lever", normalize(buffer, 0.65))

	buffer = new_buf(0.6)
	for i in 4:
		note(buffer, i * 0.06, 0.16, 700.0 * pow(1.26, i), "tri", 0.28, 0.003, 0.08)
	save_wav("key", normalize(buffer, 0.7))

	buffer = new_buf(0.7)
	for i in 4:
		note(buffer, i * 0.08, 0.22, 520.0 * pow(1.33, i), "square", 0.26, 0.004, 0.12, 0.0, 0.35)
	save_wav("checkpoint", normalize(buffer, 0.7))

	buffer = new_buf(0.8)
	note(buffer, 0.0, 0.7, 120.0, "saw", 0.28, 0.01, 0.4, 0.6)
	drum(buffer, 0.0, "kick", 0.5)
	drum(buffer, 0.18, "kick", 0.35)
	save_wav("door", normalize(buffer, 0.8))

	buffer = new_buf(0.25)
	note(buffer, 0.0, 0.06, 1400.0, "square", 0.2, 0.001, 0.03, -0.5, 0.1)
	note(buffer, 0.08, 0.1, 900.0, "square", 0.18, 0.001, 0.05, -0.6, 0.1)
	save_wav("gate", normalize(buffer, 0.6))

	buffer = new_buf(0.1)
	note(buffer, 0.0, 0.05, 900.0, "square", 0.2, 0.001, 0.03, 0.0, 0.25)
	save_wav("select", normalize(buffer, 0.6))

	buffer = new_buf(0.3)
	drum(buffer, 0.0, "kick", 0.45)
	note(buffer, 0.0, 0.2, 140.0, "square", 0.22, 0.002, 0.14, -0.5, 0.5)
	save_wav("boss_hit", normalize(buffer, 0.8))

	# победа: фанфары
	buffer = new_buf(2.4)
	var fan := "C5:4 E5:4 G5:4 C6:8 G5:4 C6:12 R:4 E6:4 D6:4 C6:16"
	play_pattern(buffer, fan, "square", 0.3, 0.075, 0.0, 0.0, 0.4)
	var bass := "C3:16 G3:16 C3:16 G3:16"
	play_pattern(buffer, bass, "saw", 0.22, 0.075, 0.0, 0.0, 0.4)
	play_pattern(buffer, "C4:8 E4:8 G4:8 E4:8", "tri", 0.18, 0.075, 0.6)
	for i in 8:
		drum(buffer, 0.6 + i * 0.1, "hat", 0.3)
	save_wav("win", normalize(buffer, 0.85))

	buffer = new_buf(1.2)
	note(buffer, 0.0, 0.3, 330.0, "square", 0.28, 0.003, 0.2, -0.5, 0.4)
	note(buffer, 0.28, 0.35, 262.0, "square", 0.26, 0.003, 0.22, -0.5, 0.4)
	note(buffer, 0.62, 0.5, 196.0, "saw", 0.24, 0.003, 0.35, -0.4)
	save_wav("lose", normalize(buffer, 0.8))

# ---------------------------------------------------------------- музыка
func gen_music() -> void:
	# ---- мирная тема: 8 тактов, 130 BPM
	var step := 60.0 / 130.0 / 4.0 # одна шестнадцатая
	var buf := new_buf(step * 128 + 1.5)
	var lead := "G4:2 A4:2 B4:2 C5:2 D5:2 E5:4 C5:2 | A4:2 B4:2 C5:2 D5:2 E5:4 A4:4 | F4:2 G4:2 A4:2 C5:2 F5:4 A4:4 | G4:2 B4:2 D5:2 G5:4 D5:2 B4:4 | C5:2 E5:2 G5:2 C6:4 G5:2 E5:4 | A5:2 G5:2 E5:2 C5:4 E5:2 A4:4 | F5:2 E5:2 D5:2 C5:2 A4:4 F4:4 | G4:4 B4:4 D5:4 G5:4"
	play_pattern(buf, lead.replace("|", ""), "square", 0.26, step, 0.0, 0.0, 0.35)
	var bass := "C3:8 C3:4 G3:4 | A2:8 A2:4 E3:4 | F2:8 F2:4 C3:4 | G2:8 G2:4 D3:4 | C3:8 C3:4 G3:4 | A2:8 A2:4 E3:4 | F2:8 F2:4 C3:4 | G2:8 G2:8"
	play_pattern(buf, bass.replace("|", ""), "saw", 0.24, step, 0.0, 0.0, 0.4)
	var arp := "C4:2 E4:2 G4:2 C5:2 E5:2 G5:2 E5:2 C5:2" + \
		" A3:2 C4:2 E4:2 A4:2 C5:2 E5:2 C5:2 A4:2" + \
		" F3:2 A3:2 C4:2 F4:2 A4:2 C5:2 A4:2 F4:2" + \
		" G3:2 B3:2 D4:2 G4:2 B4:2 D5:2 B4:2 G4:2" + \
		" C4:2 E4:2 G4:2 C5:2 E5:2 G5:2 E5:2 C5:2" + \
		" A3:2 C4:2 E4:2 A4:2 C5:2 E5:2 C5:2 A4:2" + \
		" F3:2 A3:2 C4:2 F4:2 A4:2 C5:2 A4:2 F4:2" + \
		" G3:2 B3:2 D4:2 G4:2 B4:2 D5:2 B4:2 G4:2"
	play_pattern(buf, arp, "tri", 0.1, step, 0.0, 0.0)
	for bar in 8:
		var t := bar * step * 16
		drum(buf, t, "kick", 0.4)
		drum(buf, t + step * 4, "snare", 0.3)
		drum(buf, t + step * 8, "kick", 0.36)
		drum(buf, t + step * 12, "snare", 0.3)
		for h in 8:
			drum(buf, t + step * h * 2, "hat", 0.12)
	save_wav("music_world", normalize(buf, 0.72))

	# ---- тема замка/босса: 8 тактов, 150 BPM, минор
	var bstep := 60.0 / 150.0 / 4.0
	var bbuf := new_buf(bstep * 128 + 1.5)
	var blead := "A4:4 C5:4 E5:4 A5:4 | G5:2 E5:2 C5:4 B4:4 A4:4 | F4:4 A4:4 C5:4 F5:4 | E5:2 C5:2 A4:4 G4:4 E4:4 | A4:4 C5:4 E5:4 A5:4 | B5:2 A5:2 G5:4 E5:4 C5:4 | D5:4 F5:4 A5:4 D6:4 | C6:2 A5:2 E5:4 A4:8"
	play_pattern(bbuf, blead.replace("|", ""), "square", 0.24, bstep, 0.0, 0.0, 0.25)
	var bbass := "A2:4 A2:4 A2:4 E3:4 | A2:4 A2:4 G2:4 G2:4 | F2:4 F2:4 F2:4 C3:4 | E2:4 E2:4 E2:4 E3:4 | A2:4 A2:4 A2:4 E3:4 | G2:4 G2:4 C3:4 C3:4 | D3:4 D3:4 D3:4 A3:4 | E3:4 E3:4 A2:8"
	play_pattern(bbuf, bbass.replace("|", ""), "saw", 0.3, bstep, 0.0, 0.0, 0.5)
	var harm := "A3:2 A4:2 A3:2 A4:2 A3:2 A4:2 E3:2 E4:2"
	play_pattern(bbuf, harm, "tri", 0.12, bstep, 0.0, 0.0)
	for bar in 8:
		var t := bar * bstep * 16
		drum(bbuf, t, "kick", 0.45)
		drum(bbuf, t + bstep * 4, "snare", 0.32)
		drum(bbuf, t + bstep * 8, "kick", 0.4)
		drum(bbuf, t + bstep * 11, "snare", 0.26)
		drum(bbuf, t + bstep * 12, "snare", 0.32)
		for h in 8:
			drum(bbuf, t + bstep * h * 2, "hat", 0.1)
	save_wav("music_boss", normalize(bbuf, 0.74))
