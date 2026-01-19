extends Control

@onready var join_ip_input: LineEdit = %JoinIP

func _ready() -> void:
	PeerManager.shutdown()
	
	if LobbyManager.disconnection_reason != "":
		var dialog = AcceptDialog.new()
		dialog.dialog_text = LobbyManager.disconnection_reason
		dialog.title = "Disconnected"
		add_child(dialog)
		dialog.popup_centered()
		LobbyManager.disconnection_reason = ""
	
	LobbyManager.cleanup_session()
	%StartGame.grab_focus()

func _on_start_game_pressed() -> void:
	PeerManager.set_provider(ENetNetworkProvider.new())
	var err = PeerManager.host_game()
	if err == OK:
		LobbyManager.initialize_lobby_as_host()
		get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _on_join_game_pressed() -> void:
	var ip = join_ip_input.text
	if ip.is_empty():
		ip = "127.0.0.1"
	
	PeerManager.set_provider(ENetNetworkProvider.new(ip))
	var err = PeerManager.join_game()
	if err == OK:
		get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
