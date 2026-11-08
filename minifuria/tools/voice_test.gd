extends SceneTree
## godot --headless --path . -s res://tools/voice_test.gd
## Codifica e decodifica um sinal parecido com voz (tons + ruído com envelope) e mede a relação sinal/ruído.
func _init() -> void:
	var v := Voice.new()
	var sig := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in Voice.RATE * 2:
		var t := float(i) / Voice.RATE
		var env := 0.5 + 0.5 * sin(t * TAU * 3.0)
		var s := 0.25 * sin(t * TAU * 180.0) + 0.12 * sin(t * TAU * 720.0 + 1.0) + 0.06 * sin(t * TAU * 2300.0) + rng.randf_range(-0.02, 0.02)
		sig.append(s * env)
	var out := PackedFloat32Array()
	var bytes := 0
	for k in range(0, sig.size() - Voice.FRAME + 1, Voice.FRAME):
		var pkt := v._encode(sig.slice(k, k + Voice.FRAME))
		bytes += pkt.size()
		out.append_array(Voice.decode(pkt))
	var se := 0.0
	var ne := 0.0
	for i in out.size():
		var ref := sig[i] * 1.6
		se += ref * ref
		ne += (out[i] - clampf(ref, -1.0, 1.0)) * (out[i] - clampf(ref, -1.0, 1.0))
	print("VOICETEST pacotes=%d bytes/s=%d SNR=%.1f dB" % [out.size() / Voice.FRAME, int(bytes / 2.0), 10.0 * log(se / maxf(ne, 1e-9)) / log(10.0)])
	v.free()
	quit()
