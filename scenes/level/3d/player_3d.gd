class_name Player3D
extends CharacterBody3D

## First-person 3D player controller.
## The owning client sends inputs via RPC, the server applies physics,
## and the synchronizer replicates state to all clients.
##
## Each instance determines its role(s) in _ready:
##   - LOCAL:  this peer owns the player — reads input, drives first-person view.
##   - SERVER: the server — applies physics, computes animation blend.
##   - REMOTE: any non-owning client — just renders replicated state.
## A host player is both LOCAL and SERVER simultaneously.

# -- Exports -------------------------------------------------------------------

@export_group("Movement")
@export var base_speed: float = 3.5
@export var sprint_speed: float = 6.0
@export var jump_velocity: float = 4.5

@export_group("Multiplayer")
@export var peer_id: int = -1:
	set(value):
		peer_id = value

## Replicated by the synchronizer.
@export var look_rotation: Vector2 = Vector2.ZERO
@export var anim_blend_position: Vector2 = Vector2.ZERO

# -- Node refs -----------------------------------------------------------------

@onready var animation_tree: AnimationTree = $"Third Person Container/AnimationTree"
@onready var first_person_animation_tree: AnimationTree = $"Head/Camera3D/SubViewportContainer/SubViewport/First Person Camera/First Person Container/FirstPersonAnimationTree"
@onready var player_sync: HandshakeSynchronizer = $Player3DSync
@onready var action_router: GameActionRouter3D = $Player3DActions
@onready var head: Node3D = $Head
@onready var third_person_container: Node3D = $"Third Person Container"
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var third_person_camera: Camera3D = $SpringArm3D/ThirdPersonCamera
@onready var first_person_camera: Camera3D = $Head/Camera3D
@onready var fp_viewport_container: SubViewportContainer = $Head/Camera3D/SubViewportContainer
@onready var fp_container: Node3D = $"Head/Camera3D/SubViewportContainer/SubViewport/First Person Camera/First Person Container"

# -- State ---------------------------------------------------------------------

## Server-side input received from the owning client.
var input: Vector2 = Vector2.ZERO
var _wants_jump: bool = false
var _wants_sprint: bool = false

## Role flags — set once in _ready, never changed.
var _is_local: bool = false
var _is_server: bool = false

## Camera mode: true = first person, false = third person.
var _first_person: bool = true

const ANIM_BLEND_SPEED := 10.0

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	assert(peer_id != -1, "Player3D must have a peer_id")
	assert(player_sync is HandshakeSynchronizer, "Player3D must have a HandshakeSynchronizer")

	_is_local = peer_id == multiplayer.get_unique_id()
	_is_server = multiplayer.is_server()

	if _is_local:
		_setup_local()
	else:
		_setup_remote()

func _unhandled_input(event: InputEvent) -> void:
	if _is_local and event.is_action_pressed("toggle_camera"):
		_set_camera_mode(not _first_person)

func _process(delta: float) -> void:
	if _is_local and _has_connection():
		_send_inputs()

	if _is_server:
		_server_apply_movement(delta)
		_server_update_animation_blend()

	_apply_look()
	_apply_third_person_animation()

	if _is_local and _first_person:
		_update_first_person_animation()

func get_spawn_params() -> Dictionary:
	return {
		"peer_id": peer_id,
		"position": global_position,
	}

# -- Role Setup ----------------------------------------------------------------

func _setup_local() -> void:
	_set_camera_mode(true)  # Start in first person.

func _setup_remote() -> void:
	first_person_animation_tree.active = false
	fp_viewport_container.visible = false
	fp_container.visible = false

## Switches between first-person and third-person camera.
func _set_camera_mode(first_person: bool) -> void:
	_first_person = first_person

	# First-person elements
	first_person_animation_tree.active = _first_person
	fp_viewport_container.visible = _first_person
	fp_container.visible = _first_person

	# Third-person elements
	third_person_container.visible = not _first_person

	# Camera
	if _first_person:
		first_person_camera.make_current()
	else:
		third_person_camera.make_current()

# -- Input (Local) -------------------------------------------------------------

func _has_connection() -> bool:
	var peer = multiplayer.multiplayer_peer
	return peer and peer.get_connection_status() == MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTED

func _send_inputs() -> void:
	var move_dir := action_router.get_move_direction()
	_rpc_set_input.rpc_id(1, move_dir)

	var look_input := action_router.get_look_input()
	if look_input != Vector2.ZERO:
		var new_look := look_rotation
		new_look.y -= look_input.x
		new_look.x -= look_input.y
		new_look.x = clamp(new_look.x, -action_router.get_max_pitch_rad(), action_router.get_max_pitch_rad())
		_rpc_set_look_rotation.rpc_id(1, new_look)
		look_rotation = new_look
	action_router.consume_look_input()

	_rpc_set_flags.rpc_id(1, action_router.is_jump_just_pressed(), action_router.is_sprint_pressed())

# -- Physics (Server) ---------------------------------------------------------

func _server_apply_movement(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if _wants_jump and is_on_floor():
		velocity.y = jump_velocity
		_wants_jump = false

	var speed := sprint_speed if _wants_sprint else base_speed
	var move_dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	if move_dir:
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

# -- Visuals (All peers) ------------------------------------------------------

func _apply_look() -> void:
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)
	spring_arm.transform.basis = Basis()
	spring_arm.rotate_x(look_rotation.x)

func _apply_third_person_animation() -> void:
	animation_tree.set("parameters/Locomotion/blend_position", anim_blend_position)

func _server_update_animation_blend() -> void:
	var target := Vector2(input.x, -input.y)
	anim_blend_position = anim_blend_position.lerp(target, 1.0 - exp(-ANIM_BLEND_SPEED * get_process_delta_time()))

func _update_first_person_animation() -> void:
	var is_moving := action_router.get_move_direction().length() > 0.1
	var is_sprinting := action_router.is_sprint_pressed()

	first_person_animation_tree.set("parameters/StateMachine/conditions/idle", !is_moving)
	first_person_animation_tree.set("parameters/StateMachine/conditions/run", is_moving and is_sprinting)
	first_person_animation_tree.set("parameters/StateMachine/conditions/walk", is_moving and not is_sprinting)

# -- RPCs (Client -> Server) ---------------------------------------------------

func _is_valid_owner_rpc() -> bool:
	return _is_server and peer_id == multiplayer.get_remote_sender_id()

@rpc("any_peer", "call_local", "unreliable")
func _rpc_set_input(new_input: Vector2) -> void:
	if not _is_valid_owner_rpc():
		return
	input = new_input

@rpc("any_peer", "call_local", "unreliable")
func _rpc_set_look_rotation(new_look: Vector2) -> void:
	if not _is_valid_owner_rpc():
		return
	look_rotation = new_look

@rpc("any_peer", "call_local", "unreliable")
func _rpc_set_flags(jump: bool, sprint: bool) -> void:
	if not _is_valid_owner_rpc():
		return
	if jump:
		_wants_jump = true
	_wants_sprint = sprint
	
