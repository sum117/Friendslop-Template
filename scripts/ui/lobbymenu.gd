extends Control

const PLAYER_ITEM_SCENE = preload("res://scenes/ui/LobbyPlayerItem.tscn")
const NAME_CHANGE_POPUP_SCENE = preload("res://scenes/ui/NameChangePopup.tscn")

@onready var player_list = %PlayerList
@onready var start_button = %StartBtn
@onready var status_label = %StatusLabel
@onready var lobby_state_label = %LobbyStateLabel

var _player_items: Dictionary[int, Node] = {}

func _ready() -> void:
	LobbyManager.lobby_updated.connect(_update_lobby_ui)
	LobbyManager.current_lobby.state_changed.connect(func(_new_state): _update_lobby_ui())
	_update_lobby_ui()
	
	# Only host can start
	start_button.visible = multiplayer.is_server()

func _update_lobby_ui() -> void:
	var all_players = LobbyManager.get_all_players()
	
	# 1. Remove items for players who left
	var to_remove: Array[int] = []
	for id in _player_items:
		if LobbyManager.get_player(id) == null:
			to_remove.append(id)
	
	for id in to_remove:
		_player_items[id].queue_free()
		_player_items.erase(id)
	
	# 2. Add or update items for current players
	for p_node in all_players:
		var id = p_node.peer_id
		if not _player_items.has(id):
			# New player
			var item = PLAYER_ITEM_SCENE.instantiate()
			player_list.add_child(item)
			_player_items[id] = item
		
		# Update data (Match/New)
		_player_items[id].listen_for_updates(p_node)
	
	# 3. Update status label
	if all_players.is_empty():
		status_label.text = "Waiting for players..."
	else:
		status_label.text = "Connected: %d players" % all_players.size()
	
	# 4. Update lobby state label
	var current_state = LobbyManager.current_lobby.state
	var state_name = Lobby.State.keys()[current_state]
	lobby_state_label.text = "State: %s" % state_name.capitalize()

func _on_ready_btn_pressed() -> void:
	LobbyManager.toggle_ready()

func _on_change_name_btn_pressed() -> void:
	var local_player = LobbyManager.get_local_player()
	if not local_player: return
	
	var popup = NAME_CHANGE_POPUP_SCENE.instantiate()
	
	# Subscribe to signals BEFORE adding as child
	popup.name_submitted.connect(func(new_name):
		LobbyManager.update_player_name(new_name)
	)
	popup.popup_hide.connect(popup.queue_free)
	
	add_child(popup)
	popup.popup_with_name(local_player.player_name)

func _on_start_btn_pressed() -> void:
	if not multiplayer.is_server():
		return

	# Toggle state between LOBBY and STARTING and etc.	
	var lobby = LobbyManager.current_lobby
	var next_state = (int(lobby.state) + 1) % Lobby.State.size()
	lobby.state = next_state as Lobby.State

func _on_leave_btn_pressed() -> void:
	PeerManager.shutdown()
	get_tree().change_scene_to_file("res://MainMenu.tscn")
