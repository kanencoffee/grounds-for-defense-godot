extends Node
# Procedural audio for Grounds for Defense (Godot 4)
# Pre-generates AudioStreamWAV samples at startup, plays via a pool of AudioStreamPlayers.

const SR := 44100  # sample rate
const POOL_SIZE := 12

var _streams := {}     # name -> AudioStreamWAV
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var muted := false

func _ready():
	# Build player pool
	for i in POOL_SIZE:
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	# Pre-generate all SFX
	_streams["drip"]      = _tone_decay(880.0, 0.05, 0.18, true)
	_streams["espressoCh"]= _sweep(120.0, 600.0, 1.4, 0.16)
	_streams["espressoF"] = _layer([_sweep(900.0, 100.0, 0.35, 0.30), _noise(0.25, 0.18, 1200.0, 6000.0)])
	_streams["frother"]   = _layer([_noise(0.18, 0.18, 800.0, 4000.0), _tone_decay(420.0, 0.12, 0.14)])
	_streams["cold"]      = _tone_decay(140.0, 0.18, 0.12)
	_streams["grinder"]   = _noise(0.12, 0.22, 1200.0, 5000.0)
	_streams["pourover"]  = _layer([_tone_decay(700.0, 0.08, 0.18, true), _tone_decay(900.0, 0.06, 0.14, true)])
	_streams["aeropress"] = _layer([_tone_decay(220.0, 0.04, 0.22, true), _noise(0.06, 0.14, 600.0, 3000.0)])
	_streams["hit"]       = _tone_decay(1400.0, 0.04, 0.14, true)
	_streams["enemyDie"]  = _layer([_sweep(440.0, 60.0, 0.25, 0.24), _noise(0.15, 0.10, 200.0, 2000.0)])
	_streams["reachEnd"]  = _sweep(220.0, 80.0, 0.4, 0.28)
	_streams["place"]     = _layer([_tone_decay(523.0, 0.06, 0.22), _tone_decay(784.0, 0.12, 0.18)])
	_streams["sell"]      = _layer([_tone_decay(659.0, 0.06, 0.20), _tone_decay(440.0, 0.12, 0.16)])
	_streams["upgrade"]   = _arpeggio([523.0, 659.0, 784.0], 0.08, 0.20, true)
	_streams["waveStart"] = _arpeggio([440.0, 554.0, 659.0], 0.10, 0.20, true)
	_streams["waveClear"] = _arpeggio([523.0, 659.0, 784.0, 1047.0], 0.13, 0.22)
	_streams["perfect"]   = _layer([_sweep(2000.0, 200.0, 0.5, 0.30), _noise(0.3, 0.20, 600.0, 8000.0)])
	_streams["lose"]      = _arpeggio([392.0, 370.0, 311.0, 261.0], 0.40, 0.30, false, 0.20)
	_streams["win"]       = _arpeggio([523.0, 659.0, 784.0, 1047.0, 1319.0], 0.30, 0.26)
	_streams["error"]     = _tone_decay(180.0, 0.10, 0.20, true)
	_streams["splash"]    = _layer([_noise(0.18, 0.18, 200.0, 2000.0), _tone_decay(180.0, 0.15, 0.12)])

func play(name: String):
	if muted: return
	if not _streams.has(name): return
	var p = _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	p.stop()
	p.stream = _streams[name]
	p.volume_db = -2.0
	p.play()

func set_mute(m: bool):
	muted = m
	if m:
		for p in _players: p.stop()

func is_muted() -> bool:
	return muted

# ============== GENERATORS ==============

# Single tone with exponential decay envelope
func _tone_decay(freq: float, dur: float, vol: float, square := false) -> AudioStreamWAV:
	var n = int(SR * dur)
	var data = PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t = float(i) / SR
		var env = exp(-4.0 * t / dur)
		var phase = 2.0 * PI * freq * t
		var s: float
		if square:
			s = (1.0 if sin(phase) >= 0.0 else -1.0)
		else:
			s = sin(phase)
		var sample = clamp(s * vol * env, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767))
	return _wrap_wav(data)

# Frequency sweep (sawtooth-like) — used for espresso, enemy die, perfect shot
func _sweep(f1: float, f2: float, dur: float, vol: float) -> AudioStreamWAV:
	var n = int(SR * dur)
	var data = PackedByteArray()
	data.resize(n * 2)
	var phase = 0.0
	for i in n:
		var t = float(i) / SR
		# exponential interp from f1 to f2
		var freq = f1 * pow(f2 / f1, t / dur)
		phase += 2.0 * PI * freq / SR
		var env = clamp((1.0 - t / dur), 0.0, 1.0)
		# sawtooth-ish: mix sine + tiny harmonics
		var s = sin(phase) * 0.7 + sin(phase * 2.0) * 0.3
		var sample = clamp(s * vol * env, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767))
	return _wrap_wav(data)

# Filtered noise — used for grinder, hits, splashes
func _noise(dur: float, vol: float, hpf: float, lpf: float) -> AudioStreamWAV:
	var n = int(SR * dur)
	var data = PackedByteArray()
	data.resize(n * 2)
	# simple one-pole filters
	var hp_state = 0.0
	var lp_state = 0.0
	var hp_alpha = clamp(hpf / SR, 0.0, 1.0)
	var lp_alpha = clamp(lpf / SR, 0.0, 1.0)
	for i in n:
		var t = float(i) / SR
		var env = clamp(1.0 - t / dur, 0.0, 1.0)
		var raw = randf_range(-1.0, 1.0)
		# lowpass
		lp_state = lp_state + lp_alpha * (raw - lp_state)
		# highpass = signal - lowpass-of-signal (cheap)
		hp_state = hp_state + hp_alpha * (lp_state - hp_state)
		var filtered = lp_state - hp_state * 0.5
		var sample = clamp(filtered * vol * env, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767))
	return _wrap_wav(data)

# Layer multiple streams into one (sums samples)
func _layer(streams: Array) -> AudioStreamWAV:
	var max_len = 0
	for s in streams:
		max_len = max(max_len, s.data.size())
	var out = PackedByteArray()
	out.resize(max_len)
	for s in streams:
		for i in range(0, s.data.size(), 2):
			var existing = out.decode_s16(i) if i < out.size() else 0
			var new_sample = s.data.decode_s16(i)
			var summed = clamp(existing + new_sample, -32767, 32767)
			out.encode_s16(i, summed)
	return _wrap_wav(out)

# Sequential notes (arpeggio)
func _arpeggio(freqs: Array, note_dur: float, vol: float, square := false, gap := 0.0) -> AudioStreamWAV:
	var streams = []
	var total = 0
	for f in freqs:
		var s = _tone_decay(f, note_dur, vol, square)
		streams.append(s)
		total += s.data.size()
		if gap > 0:
			# silence
			var sn = int(SR * gap)
			var silence = PackedByteArray()
			silence.resize(sn * 2)
			var sw = AudioStreamWAV.new()
			sw.format = AudioStreamWAV.FORMAT_16_BITS
			sw.mix_rate = SR
			sw.data = silence
			streams.append(sw)
			total += silence.size()
	# concatenate
	var out = PackedByteArray()
	out.resize(total)
	var off = 0
	for s in streams:
		for i in range(0, s.data.size(), 2):
			out.encode_s16(off + i, s.data.decode_s16(i))
		off += s.data.size()
	return _wrap_wav(out)

func _wrap_wav(data: PackedByteArray) -> AudioStreamWAV:
	var w = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = data
	return w
