extends Node

## Abstracted manager for network peer creation and destruction.
## Supports ENet initially, but structured to allow other providers (Steam, etc).

# --- Signals ---
signal connection_established
signal connection_failed
signal server_disconnected(reason: String)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)

var _provider: BaseNetworkProvider

func _ready() -> void:
	# Encapsulate low-level signals
	multiplayer.peer_connected.connect(func(id): peer_connected.emit(id))
	multiplayer.peer_disconnected.connect(func(id): peer_disconnected.emit(id))
	multiplayer.connected_to_server.connect(func(): connection_established.emit())
	multiplayer.connection_failed.connect(func(): connection_failed.emit())
	multiplayer.server_disconnected.connect(func(): server_disconnected.emit("The host has disconnected."))

## Sets the active network provider.
func set_provider(provider: BaseNetworkProvider) -> void:
	if _provider == provider:
		return
		
	if _provider:
		shutdown()
		
	_provider = provider

## Starts a server using the active provider.
func host_game() -> Error:
	if not _provider:
		push_error("PeerManager: No provider set.")
		return ERR_UNCONFIGURED
	return _provider.host_game()

## Connects to a server using the active provider.
func join_game() -> Error:
	if not _provider:
		push_error("PeerManager: No provider set.")
		return ERR_UNCONFIGURED
	return _provider.join_game()

## Destroys the current multiplayer peer and cleans up.
func shutdown() -> void:
	if _provider:
		_provider.shutdown()
		
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
