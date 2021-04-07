extends Node


var not_ready := []
var clients := []

var server: NetworkedMultiplayerENet


func _init(server_peer: NetworkedMultiplayerENet) -> void:
	server = server_peer

# For at rpc'en kun bliver sendt til medlemmerne af rummet, og ikke hele serveren
func rpc_both(method: String) -> void:
	for id in clients:
		rpc_id(id, method)

func rpc_other(method: String) -> void:
	var this_id := get_tree().get_rpc_sender_id()
	for id in clients:
		if id != this_id:
			rpc_id(id, method) 

func add_client(id: int) -> void:
	not_ready.append(id)

func validate_id() -> bool:
	var id := get_tree().get_rpc_sender_id()
	if clients.has(id):
		return true
	else:
		server.disconnect_peer(id, true)
		return false



remote func client_ready() -> void:
	var id := get_tree().get_rpc_sender_id()
	if not_ready.has(id):
		not_ready.erase(id)
		clients.append(id)
		
		if clients.size() == 2:
			rpc_both("start")
	else:
		server.disconnect_peer(id, true)


remote func server_bruh() -> void:
	if validate_id():
		rpc_other("bruh")
