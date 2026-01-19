extends Node

## Manages the multiplayer lobby session life-cycle.
## Handles player connections, information syncing, and game transitions.

# --- Signals ---
signal lobby_updated
signal player_joined(peer_id: int)
signal player_left(peer_id: int)

var current_lobby: Lobby
var _spawner: MultiplayerSpawner
var _players_container: Node
var disconnection_reason: String = ""

## --- Singleton Setup ---

func _enter_tree() -> void:
	_setup_lobby_node()
	_setup_spawner()
	
	# Listen to PeerManager's abstracted signals
	PeerManager.peer_connected.connect(_on_peer_connected)
	PeerManager.peer_disconnected.connect(_on_peer_disconnected)
	PeerManager.server_disconnected.connect(_on_server_disconnected)
	PeerManager.connection_failed.connect(_on_connection_failed)

func _setup_lobby_node() -> void:
	current_lobby = Lobby.new()
	current_lobby.name = "CurrentLobby"
	add_child(current_lobby)

func _setup_spawner() -> void:
	_players_container = Node.new()
	_players_container.name = "LobbyPlayers"
	# Automatically handle registration/unregistration via node signals
	_players_container.child_entered_tree.connect(_on_player_added)
	_players_container.child_exiting_tree.connect(_on_player_removed)
	add_child(_players_container)
	
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "LobbyPlayerSpawner"
	_spawner.spawn_path = _players_container.get_path()
	_spawner.spawn_function = _spawn_player
	add_child(_spawner)
	
func _spawn_player(data: int) -> Node:
	var new_player: LobbyPlayer = LobbyPlayer.new()
	new_player.peer_id = data
	new_player.player_name = "Player %d" % data
	return new_player

## Returns the player node for a given peer ID.
func get_player(peer_id: int) -> LobbyPlayer:
	return _players_container.get_node_or_null(str(peer_id)) as LobbyPlayer

## Returns the local player node.
func get_local_player() -> LobbyPlayer:
	return get_player(multiplayer.get_unique_id())

## Returns an array of all active lobby player nodes.
func get_all_players() -> Array[LobbyPlayer]:
	var list: Array[LobbyPlayer] = []
	for child in _players_container.get_children():
		if child is LobbyPlayer:
			list.append(child)
	return list

# --- Public API ---

## Initializes the lobby session for the host.
func initialize_lobby_as_host() -> void:
	if not multiplayer.is_server():
		return
	
	cleanup_session()

	current_lobby.state = Lobby.State.LOBBY
	current_lobby.host_id = multiplayer.get_unique_id()
	_add_player(current_lobby.host_id)

## Toggles the ready state of the local player.
func toggle_ready() -> void:
	var player_node = get_local_player()
	if player_node:
		player_node.is_ready = !player_node.is_ready

## Requests a name update. Server will validate and sync via RPC.
func update_player_name(new_name: String) -> void:
	var player_node = get_local_player()
	if player_node:
		player_node.player_name = new_name

# --- Player Registration (Internal) ---

func _on_player_added(node: Node) -> void:
	var player_node = node as LobbyPlayer
	if not player_node:
		return
		
	player_joined.emit(player_node.peer_id)
	lobby_updated.emit()

func _on_player_removed(node: Node) -> void:
	var player_node = node as LobbyPlayer
	if not player_node:
		return
		
	player_left.emit(player_node.peer_id)
	# Defer emission so the node is fully removed from the tree 
	# before the UI tries to refresh the player list.
	lobby_updated.emit.call_deferred()

# --- Internal Networking Helpers ---

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_add_player(peer_id)

func _add_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	
	_spawner.spawn(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		var player_node = get_player(peer_id)
		if player_node:
			player_node.queue_free()

func _on_server_disconnected(reason: String) -> void:
	cleanup_session()
	disconnection_reason = reason
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func _on_connection_failed() -> void:
	cleanup_session()
	disconnection_reason = "Connection failed."
	get_tree().change_scene_to_file("res://MainMenu.tscn")

## Cleans up the current session data.
func cleanup_session() -> void:
	for child in _players_container.get_children():
		child.queue_free()
	
	current_lobby.state = Lobby.State.NOT_CONNECTED
	current_lobby.host_id = 1
	current_lobby.active_map_path = ""
	lobby_updated.emit()
