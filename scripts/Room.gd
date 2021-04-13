extends Node


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
func rpc_both(method: String, args: Array = []) -> void:
	for id in clients:
		# callv bruges for at kunne give indholdet af et array som enkelte argumenter
		callv("rpc_id", [id, method] + args)

func rpc_unreliable_other(method: String, args: Array = []) -> void:
	var this_id := get_tree().get_rpc_sender_id()
	for id in clients:
		if id != this_id:
			callv("rpc_unreliable_id", [id, method] + args) 

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
	
	player1.cam_flipped = false
	player2.cam_flipped = true
	
	player1.pos = Vector2(-200, 0)
	player2.pos = Vector2(200, 0)
	
	rpc_both("start", [player1, player2])



remote func update_transform(position: Vector2, rotation: float) -> void:
	if validate_id():
		rpc_unreliable_other("receive_transform", [position, rotation])
