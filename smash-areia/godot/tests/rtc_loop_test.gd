extends SceneTree
## Teste: dois WebRTCPeerConnection no mesmo processo (sem tracker).
## godot --headless --path godot -s tests/rtc_loop_test.gd
var a := WebRTCPeerConnection.new()
var b := WebRTCPeerConnection.new()
var ca: WebRTCDataChannel
var cb: WebRTCDataChannel
var t := 0.0
func _init():
	print("init a=", a.initialize({"iceServers": []}), " b=", b.initialize({"iceServers": []}))
	ca = a.create_data_channel("x", {"id": 1, "negotiated": true})
	cb = b.create_data_channel("x", {"id": 1, "negotiated": true})
	a.session_description_created.connect(func(ty, sdp): a.set_local_description(ty, sdp); b.set_remote_description(ty, sdp))
	b.session_description_created.connect(func(ty, sdp): b.set_local_description(ty, sdp); a.set_remote_description(ty, sdp))
	a.ice_candidate_created.connect(func(m, i, n): print("cand a ", n); b.add_ice_candidate(m, i, n))
	b.ice_candidate_created.connect(func(m, i, n): print("cand b ", n); a.add_ice_candidate(m, i, n))
	a.create_offer()
func _process(dt):
	t += dt
	a.poll(); b.poll()
	if ca.get_ready_state() == WebRTCDataChannel.STATE_OPEN and t > 0.5:
		ca.put_packet("oi".to_utf8_buffer())
	while cb.get_available_packet_count() > 0:
		print("RECEBEU: ", cb.get_packet().get_string_from_utf8(), " em ", t); quit(); return false
	if t > 15.0:
		print("TIMEOUT states ", a.get_connection_state(), " ", b.get_connection_state()); quit()
	return false
