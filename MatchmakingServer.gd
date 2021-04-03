extends Node


signal new_pair(token1, token2, timestamp)
signal failure(message)


export var matchmaking_url := "wss://localhost:2094"
var socket_client := WebSocketClient.new()

const token_length := 64



func _ready() -> void:
	socket_client.connect("connection_established", self, "connected")
	socket_client.connect("data_received", self, "receive_package")
	socket_client.connect("connection_error", self, "connection_error")
	socket_client.connect("connection_closed", self, "connection_closed")
	enable_tls(false)
	establish_connection()

func _process(_delta: float) -> void:
	socket_client.poll()



func bytes_to_int(bytes: PoolByteArray) -> int:
	var sp_buffer := StreamPeerBuffer.new()
	sp_buffer.set_data_array(bytes)
	return sp_buffer.get_64()



func enable_tls(verify_with_ca: bool) -> void:
	socket_client.set_verify_ssl_enabled(verify_with_ca)
	var server_certificate := load("res://TLS/matchmaking_cert.crt")
	socket_client.set_trusted_ssl_certificate(server_certificate)
	# TODO: send også denne servers certifikat


func establish_connection() -> void:
	var error := socket_client.connect_to_url(matchmaking_url)
	if error != OK:
		print("failure: Cannot create connection to matchmaking server.")

func connected(_protocol: String) -> void:
	print("Connected to matchmaking server.")


func receive_package() -> void:
	var packet := socket_client.get_peer(1).get_packet()
	
	if packet.size() != token_length * 2 + 4:
		emit_signal("failure", "Received packet is of the wrong size: %s" % packet.size())
		print("fuck")
	else:
		var token1 := packet.subarray(0, token_length - 1)
		var token2 := packet.subarray(token_length, token_length * 2 - 1)
		var timestamp := bytes_to_int(packet.subarray(token_length * 2, -1))
		
		emit_signal("new_pair", token1, token2, timestamp)
		print("token1: %s" % token1.hex_encode())
		print("token2: %s" % token2.hex_encode())
		print("timestamp: %s" % timestamp)



func connection_error() -> void:
	print("failure: Matchmaking server could not be reached.")

func connection_closed(clean_close: bool) -> void:
	if not clean_close:
		print("failure: Connection to matchmaking server ended abruptly.")
