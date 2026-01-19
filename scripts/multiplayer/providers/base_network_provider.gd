extends RefCounted
class_name BaseNetworkProvider

## Abstract base class for network providers (ENet, Steam, etc).
## Handles high-level connection initialization and teardown.

## Called when the provider is initialized with its specific settings.
func _init() -> void:
	pass

## Starts hosting a game.
## Should call super() to ensure any existing peer is cleared via PeerManager.
func host_game() -> Error:
	PeerManager.shutdown()
	return OK

## Joins a game.
## Should call super() to ensure any existing peer is cleared via PeerManager.
func join_game() -> Error:
	PeerManager.shutdown()
	return OK

## Returns the name of the provider class for debugging.
func get_class_name() -> String:
	assert(false, "BaseNetworkProvider is an abstract class and should not be used directly.")
	return "BaseNetworkProvider"

## Shuts down the provider and cleans up resources.
## Override this to provide specific cleanup logic (e.g., closing Steam lobbies).
func shutdown() -> void:
	assert(false, "BaseNetworkProvider is an abstract class and should not be used directly.")
