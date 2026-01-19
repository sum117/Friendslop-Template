class_name Lobby
extends Node

## Data structure representing a multiplayer lobby's state.
## This node is automatically created by [LobbyManager] and synchronized via [MultiplayerSynchronizer].

enum State {
	NOT_CONNECTED, ## Default state before joining any session
	LOBBY, ## Players are joining and selecting options
	GAME_LOADING, ## Server is switching to the map, clients are loading
	IN_GAME, ## Gameplay is active
	POST_GAME ## Game has ended, viewing results
}

signal state_changed(new_state: State)

@export var state: State = State.NOT_CONNECTED:
	set(value):
		if state == value: return
		state = value
		state_changed.emit(state)

@export var max_players: int = 4
@export var host_id: int = 1
@export var active_map_path: String = ""

var _synchronizer: MultiplayerSynchronizer

func _enter_tree() -> void:
	_setup_synchronizer()

## Programmatically creates a MultiplayerSynchronizer.
func _setup_synchronizer() -> void:
	_synchronizer = MultiplayerSynchronizer.new()
	_synchronizer.name = "MultiplayerSynchronizer"
	
	var config := SceneReplicationConfig.new()
	
	# Properties that should be synced from the server to others
	config.add_property(NodePath(":state"))
	config.add_property(NodePath(":max_players"))
	config.add_property(NodePath(":host_id"))
	config.add_property(NodePath(":active_map_path"))
	
	_synchronizer.replication_config = config
	add_child(_synchronizer)
