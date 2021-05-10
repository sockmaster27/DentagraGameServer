class_name Room
extends Node

enum Side {left, right}


var not_ready := []
var clients := []

var names := {}
var bases := {}

var server: NetworkedMultiplayerENet


func _init(server_peer: NetworkedMultiplayerENet) -> void:
	server = server_peer


func rpc_other(method: String, args: Array = [], reliable: bool = true) -> void:
	var this_id := get_tree().get_rpc_sender_id()
	for id in clients:
		if id != this_id:
			var rpc_method := "rpc_id" if reliable else "rpc_unreliable_id"
			# callv bruges for at kunne give indholdet af et array som enkelte argumenter
			callv(rpc_method, [id, method] + args)
			return


func add_client(id: int, display_name: String) -> void:
	not_ready.append(id)
	names[id] = display_name

func validate_id() -> bool:
	var id := get_tree().get_rpc_sender_id()
	if clients.has(id):
		return true
	else:
		server.disconnect_peer(id, true)
		return false



remote func client_ready(base: Array) -> void:
	var id := get_tree().get_rpc_sender_id()
	if not_ready.has(id):
		not_ready.erase(id)
		clients.append(id)
		bases[id] = base
		print(base)
		if clients.size() == 2:
			start()
	else:
		server.disconnect_peer(id, true)


func start() -> void:
	var id1 = clients[0]
	var id2 = clients[1]
	print(bases)
	rpc_id(id1, "start", Side.left, Vector2(-200, 0), Vector2(200, 0), names[id2], bases[id2])
	rpc_id(id2, "start", Side.right, Vector2(200, 0), Vector2(-200, 0), names[id1], bases[id1])
	
	bases.clear()


func disconnect_client(id: int) -> void:
	not_ready.erase(id)
	clients.erase(id)
	
	for other_id in not_ready + clients:
		rpc_id(other_id, "enemy_disconnected")
		server.disconnect_peer(other_id)
	
	queue_free()



remote func update_transform(position: Vector2, rotation: float) -> void:
	if validate_id():
		rpc_other("receive_transform", [position, rotation], false)

remote func hit() -> void:
	if validate_id():
		rpc_other("receive_hit")


remote func player_base_damaged(x: int, y: int, damage: int) -> void:
	if validate_id():
		rpc_other("receive_enemy_base_damaged", [x, y, damage])

remote func enemy_base_damaged(x: int, y: int, damage: int) -> void:
	if validate_id():
		rpc_other("receive_player_base_damaged", [x, y, damage])
