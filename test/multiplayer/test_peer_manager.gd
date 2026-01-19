extends "res://addons/gut/test.gd"

var MockProvider = load("res://scripts/multiplayer/providers/base_network_provider.gd")

class TestProvider extends BaseNetworkProvider:
	var shutdown_called = false
	func get_class_name(): return "TestProvider"
	func shutdown():
		shutdown_called = true
		super ()

func test_set_provider_calls_shutdown_on_old_provider():
	var provider1 = TestProvider.new()
	var provider2 = TestProvider.new()
	
	PeerManager.set_provider(provider1)
	assert_eq(PeerManager._provider, provider1, "Initial provider should be set")
	
	PeerManager.set_provider(provider2)
	assert_true(provider1.shutdown_called, "Shutdown should be called on the old provider via PeerManager.shutdown")
	assert_eq(PeerManager._provider, provider2, "New provider should be set")

func test_set_provider_ignores_same_provider():
	var provider1 = TestProvider.new()
	provider1.shutdown_called = false
	
	PeerManager.set_provider(provider1)
	provider1.shutdown_called = false # Reset after first set
	
	PeerManager.set_provider(provider1)
	assert_false(provider1.shutdown_called, "Shutdown should NOT be called if provider is the same")

func test_peermanager_shutdown_clears_peer_and_calls_provider_shutdown():
	var provider = TestProvider.new()
	PeerManager.set_provider(provider)
	PeerManager.multiplayer.multiplayer_peer = ENetMultiplayerPeer.new()
	
	PeerManager.shutdown()
	assert_true(provider.shutdown_called, "Provider shutdown should be called")
	assert_null(PeerManager.multiplayer.multiplayer_peer, "Multiplayer peer should be cleared")
