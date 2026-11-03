extends SceneTree
## Teste do codec de voz (μ-law): godot --headless --path godot -s tests/voice_codec_test.gd
func _init():
	var worst := 0.0
	for i in 2001:
		var x := -1.0 + i * 0.001
		var y := VoiceChat._mulaw_dec(VoiceChat._mulaw_enc(x))
		worst = maxf(worst, absf(y - x) / maxf(absf(x), 0.02))
	print("VOICE_CODEC erro relativo máximo = %.3f" % worst)
	quit()
