extends BaseNetworkProvider
class_name ENetNetworkProvider

## ENet-based network provider.
## Uses IP addresses and ports for connections.

var address: String = "127.0.0.1"
var port: int = 7000

func _init(p_address: String = "127.0.0.1", p_port: int = 7000) -> void:
    address = p_address
    port = p_port

func host_game() -> Error:
    super ()
    
    var peer = ENetMultiplayerPeer.new()
    var err = peer.create_server(port)
    if err == OK:
        PeerManager.multiplayer.multiplayer_peer = peer
        # Signal connection established for the host
        PeerManager.connection_established.emit()
    return err

func join_game() -> Error:
    super ()
    
    var peer = ENetMultiplayerPeer.new()
    var err = peer.create_client(address, port)
    if err == OK:
        PeerManager.multiplayer.multiplayer_peer = peer
    return err

func shutdown() -> void:
    var peer = PeerManager.multiplayer.multiplayer_peer
    if peer:
        peer.close()
    PeerManager.multiplayer.multiplayer_peer = null

func get_class_name() -> String:
    return "ENetNetworkProvider"
