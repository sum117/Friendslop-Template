extends BaseNetworkProvider
class_name SteamNetworkProvider

## Steam-based network provider (Skeleton).
## Intended for use with Steamworks/GodotSteam.

var lobby_id: int = 0
var steam_id: int = 0

func _init(p_lobby_id: int = 0) -> void:
	lobby_id = p_lobby_id

func host_game() -> Error:
	super ()
	
	# Logic for creating a Steam lobby and setting up peer would go here.
	return FAILED

func join_game() -> Error:
	super ()
	
	# Logic for joining a Steam lobby would go here.
	return FAILED

func get_class_name() -> String:
	return "SteamNetworkProvider"

func shutdown() -> void:
	# Logic for leaving Steam lobby/closing session would go here.
	pass
