extends Node


export var max_players :=  4095
export var port := 2090
export var token_timeout := 10

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
	server.connect("peer_disconnected", self, "disconnect_client")



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
			var id = awaiting_token_from_matchmaker[token][0]
			var display_name = awaiting_token_from_matchmaker[token][1]
			send_to_room(id, display_name, token)
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

func disconnect_client(id: int) -> void:
	if id in awaiting_token_from_client:
		awaiting_token_from_client.erase(id)
	elif id in awaiting_token_from_matchmaker:
		awaiting_token_from_matchmaker.erase(id)
	else:
		for room_name in rooms.keys():
			var room: Room = rooms.get(room_name) 
			if id in room.not_ready or id in room.clients:
				room.disconnect_client(id)
				rooms.erase(room_name)
				return


func send_to_room(id: int, display_name: String, token: PoolByteArray) -> void:
	var room_name = tokens[token]
	tokens.erase(token)
	rooms[room_name].add_client(id, display_name)
	rpc_id(id, "join_room", room_name)


remote func register_player(display_name: String, token: PoolByteArray) -> void:
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
		send_to_room(id, display_name, token)
	else:
		awaiting_token_from_matchmaker[token] = [id, display_name]
		yield(get_tree().create_timer(token_timeout), "timeout")
		if awaiting_token_from_matchmaker.has(token):
			server.disconnect_peer(id)
			awaiting_token_from_matchmaker.erase(token)
