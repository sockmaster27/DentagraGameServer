extends Node


signal new_pair(token1, token2, timestamp)
signal failure(message)


export var matchmaking_url := "wss://localhost:2094"
var socket_client := WebSocketClient.new()



func _ready() -> void:
	socket_client.connect("connection_established", self, "connected")
	socket_client.connect("data_received", self, "receive_packet")
	socket_client.connect("connection_error", self, "connection_error")
	socket_client.connect("connection_closed", self, "connection_closed")
	enable_tls(false)
	establish_connection()

func _process(_delta: float) -> void:
	socket_client.poll()



func enable_tls(verify_with_ca: bool) -> void:
	socket_client.set_verify_ssl_enabled(verify_with_ca)
	var server_certificate := load("res://TLS/matchmaking_cert.crt")
	socket_client.set_trusted_ssl_certificate(server_certificate)
	# TODO: send også denne servers certifikat


func establish_connection() -> void:
	var error := socket_client.connect_to_url(matchmaking_url)
	if error != OK:
		emit_signal("failure", "Cannot create connection to matchmaking server.")

func connected(_protocol: String) -> void:
	print("Connected to matchmaking server.")


func receive_packet() -> void:
	var packet := socket_client.get_peer(1).get_packet()
	
	if packet.size() != Global.token_length * 2 + 4:
		emit_signal("failure", "Received packet is of the wrong size: %s" % packet.size())
	else:
		var timestamp_bytes := packet.subarray(Global.token_length * 2, -1)
		
		var token1_bytes := packet.subarray(0, Global.token_length - 1)
		token1_bytes.append_array(timestamp_bytes)
		var token1 := token1_bytes
#		var token1 := token1_bytes.hex_encode()
		
		var token2_bytes :=  packet.subarray(Global.token_length, Global.token_length * 2 - 1)
		token2_bytes.append_array(timestamp_bytes)
		var token2 := token2_bytes
#		var token2 := token2_bytes.hex_encode()
		
		emit_signal("new_pair", token1, token2)
#		print("token1: %s" % token1)
#		print("token2: %s" % token2)
#		print("timestamp: %s" % timestamp)



func connection_error() -> void:
	emit_signal("failure", "Matchmaking server could not be reached.")

func connection_closed(clean_close: bool) -> void:
	if not clean_close:
		emit_signal("failure", "Connection to matchmaking server ended abruptly.")
