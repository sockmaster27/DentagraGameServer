class_name Room
extends Node

enum Side {left, right}


var not_ready := []
var clients := []

var names := {}

var server: NetworkedMultiplayerENet


func _init(server_peer: NetworkedMultiplayerENet) -> void:
	server = server_peer

# denne method bliver brugt i stedet for _process for at kontrollere hyppigheden
func _physics_process(_delta: float) -> void:
	pass


# For at rpc'en kun bliver sendt til medlemmerne af rummet, og ikke hele serveren
func rpc_both(method: String, args: Array = [], reliable: bool = true) -> void:
	for id in clients:
		var rpc_method := "rpc_id" if reliable else "rpc_unreliable_id"
		# callv bruges for at kunne give indholdet af et array som enkelte argumenter
		callv(rpc_method, [id, method] + args)

func rpc_other(method: String, args: Array = [], reliable: bool = true) -> void:
	var this_id := get_tree().get_rpc_sender_id()
	for id in clients:
		if id != this_id:
			var rpc_method := "rpc_id" if reliable else "rpc_unreliable_id"
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



remote func client_ready() -> void:
	var id := get_tree().get_rpc_sender_id()
	if not_ready.has(id):
		not_ready.erase(id)
		clients.append(id)
		
		if clients.size() == 2:
			start()
	else:
		server.disconnect_peer(id, true)


func start() -> void:
	var player1 := {}
	var player2 := {}
	
	player1.id = clients[0]
	player2.id = clients[1]
	
	player1.name = names[player1.id]
	player2.name = names[player2.id]
	
	player1.side = Side.left
	player2.side = Side.right
	
	player1.pos = Vector2(-200, 0)
	player2.pos = Vector2(200, 0)
	
	rpc_both("start", [player1, player2])


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
