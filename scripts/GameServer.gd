extends Node


export var max_players :=  4095
export var port := 2090
export var token_timeout := 10

var Room := preload("res://scripts/Room.gd")

var server := NetworkedMultiplayerENet.new()

var awaiting_token_from_client := []
var awaiting_token_from_matchmaker := {}
var tokens := {}
var rooms := {}


func _ready() -> void:
	$MatchmakingServer.connect("new_pair", self, "new_pair")
	$MatchmakingServer.connect("failure", self, "matchmaking_fail")
	
	open_server()



func open_server() -> void:
	server.create_server(port, max_players)
	get_tree().set_network_peer(server)
	
	server.connect("peer_connected", self, "connect_client")



func new_pair(token1: PoolByteArray, token2: PoolByteArray) -> void:
	var room_node := Room.new(server)
	var room_name := String(room_node.get_instance_id()).sha1_text()
	room_node.set_name(room_name)
	add_child(room_node)
	rooms[room_name] = room_node
	
	tokens[token1] = room_name
	tokens[token2] = room_name
	
	for token in [token1, token2]:
		if awaiting_token_from_matchmaker.has(token):
			var id = awaiting_token_from_matchmaker[token]
			send_to_room(id, token)
			awaiting_token_from_matchmaker.erase(token)
	
	yield(get_tree().create_timer(token_timeout), "timeout")
	
	if tokens.has(token1) or tokens.has(token2):
		# .erase returnerer bare false hvis key'en ikke findes
		tokens.erase(token1)
		tokens.erase(token2)
		rooms.erase(room_name)



func connect_client(id: int) -> void:
	awaiting_token_from_client.append(id)
	yield(get_tree().create_timer(token_timeout), "timeout")
	if awaiting_token_from_client.has(id):
		server.disconnect_peer(id, true)
		awaiting_token_from_client.erase(id)


func send_to_room(id: int, token: PoolByteArray) -> void:
	var room_name = tokens[token]
	tokens.erase(token)
	rooms[room_name].add_client(id)
	rpc_id(id, "join_room", room_name)


remote func receive_token(token: PoolByteArray) -> void:
	var id := get_tree().get_rpc_sender_id()
	awaiting_token_from_client.erase(id)
	
	var timestamp := Global.bytes_to_int(token.subarray(Global.token_length, -1))
	var time := OS.get_unix_time()
	
	var exists := tokens.has(token)
	var from_future := timestamp > time
	var expired := timestamp < time - token_timeout
	
	if from_future or expired:
		server.disconnect_peer(id, true)
	elif exists:
		send_to_room(id, token)
	else:
		awaiting_token_from_matchmaker[token] = id
		yield(get_tree().create_timer(token_timeout), "timeout")
		if awaiting_token_from_matchmaker.has(token):
			server.disconnect_peer(id)
			awaiting_token_from_matchmaker.erase(token)
