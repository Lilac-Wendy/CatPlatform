extends CharacterBody3D

# ==========================
# === CONFIGURAÇÕES GERAIS
# ==========================
@export var move_speed: float = 8.0
@export var jump_force: float = 4.5
@export var gravity: float = 10.0
@export var move_threshold: float = 0.1
@export var attack_speed: float = 1.0 

# ==========================
# === REFERÊNCIAS DE NÓS
# ==========================
@onready var sprite_animation_player: AnimationPlayer = $SpriteSheetPlayer
@onready var platform_animation_player: AnimationPlayer = $PlatformSwitchPlayer
@onready var anim_hsm: Node = $AnimationHSM
@onready var tail_container: Node3D = $TailContainer
@onready var tail_animation_player: AnimationPlayer = $TailPlayer

# === TIMERS DO COMBO (Referenciados) ===
@onready var AttackComboTimer: Timer = $AttackComboTimer
@onready var AttackCooldownTimer: Timer = $AttackCooldownTimer 

# ==========================
# === ESTADOS / PLATAFORMAS
# ==========================
enum State { IDLE, WALK, JUMP, FALL, ATTACK }
var current_state: State = State.IDLE

enum Platform { A, B, C }
const PLATFORM_DISTANCE = 30.0
const Z_MIDDLEGROUND = 0.0
const Z_FOREGROUND = -PLATFORM_DISTANCE
const Z_BACKGROUND = PLATFORM_DISTANCE

var current_platform: Platform = Platform.B
var current_platform_z: float = Z_MIDDLEGROUND

var is_transitioning := false
var last_facing_direction_x := 1.0
var current_combo_index := 0

func _ready() -> void:
	global_position.z = Z_MIDDLEGROUND
	current_platform_z = Z_MIDDLEGROUND
	platform_animation_player.animation_finished.connect(_on_platform_animation_finished)
	
	_setup_timers()

func _setup_timers() -> void:
	if AttackComboTimer:
		AttackComboTimer.one_shot = true
		if not AttackComboTimer.is_connected("timeout", Callable(self, "_on_combo_timeout")):
			AttackComboTimer.timeout.connect(_on_combo_timeout)
	
	if AttackCooldownTimer:
		AttackCooldownTimer.one_shot = true

func _on_combo_timeout() -> void:
	# Reseta o combo quando o timer longo expira
	if current_combo_index > 0:
		print("[Player] Combo timeout - resetando índice %d para 0." % (current_combo_index + 1))
		current_combo_index = 0

# ==========================
# === PHYSICS PROCESS
# ==========================
func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	
	# === INPUT E MOVIMENTO (Mantido) ===
	var input_dir: Vector2 = Input.get_vector("left", "right", "up", "down")
	var is_moving: bool = input_dir.length() > move_threshold
	
	handle_tail_flip(input_dir, is_moving)
	update_facing(input_dir)
	
	var target_speed := input_dir.x * move_speed
	if not on_floor:
		velocity.x = lerp(velocity.x, target_speed, 0.1)
	else:
		velocity.x = target_speed

	# === GRAVIDADE (Mantido) ===
	if not on_floor:
		velocity.y -= gravity * delta
	else:
		velocity.y = max(velocity.y, 0)

	# === CONTROLE DE ESTADO PRINCIPAL (Mantido) ===
	if not is_transitioning:
		match current_state:
			State.IDLE, State.WALK:
				if Input.is_action_just_pressed("ui_accept") and on_floor:
					_jump()
				elif Input.is_action_just_pressed("attack"):
					_attack()
				elif is_moving and on_floor:
					if current_state != State.WALK:
						current_state = State.WALK
						_play_hsm("move")
				elif not is_moving and on_floor:
					if current_state != State.IDLE:
						current_state = State.IDLE
						_play_hsm("idle")
				elif not on_floor:
					current_state = State.JUMP if velocity.y > 0 else State.FALL
					_play_hsm("jump" if velocity.y > 0 else "fall")
					
			State.JUMP, State.FALL:
				if Input.is_action_just_pressed("attack"):
					_attack()
				elif on_floor:
					current_state = State.WALK if is_moving else State.IDLE
					_play_hsm("move" if is_moving else "idle")
					
			State.ATTACK:
				if Input.is_action_just_pressed("ui_accept") and on_floor:
					_jump()

	if Input.is_action_just_pressed("up") and not is_transitioning and current_state != State.ATTACK:
		_play_hsm("platform_switch_up")
	elif Input.is_action_just_pressed("down") and not is_transitioning and current_state != State.ATTACK:
		_play_hsm("platform_switch_down")

	velocity.z = 0
	move_and_slide()

func _jump() -> void:
	velocity.y = jump_force
	current_state = State.JUMP
	_play_hsm("jump")

func _attack() -> void:

	var is_combo_active = not AttackComboTimer.is_stopped() if AttackComboTimer else false
	
	var time_left = AttackComboTimer.time_left if AttackComboTimer else 0.0
	
	print("[Player] --- Attack Input Received ---")
	print("[Player] Combo Index before logic: %d. ComboTimer Active: %s (Time Left: %.2f)" % [current_combo_index, is_combo_active, time_left])

	if current_state == State.ATTACK and is_transitioning:
		print("[Player] LOGIC: ELIF - Currently in ATTACK state and transitioning. Input deferred to AttackState's _process.")
		return 
		
	if is_combo_active:

		current_combo_index += 1
		print("[Player] LOGIC: IF - Combo window is active. Index incremented to %d." % current_combo_index)

		if current_combo_index >= 2: 
			current_combo_index = 0
			print("[Player] LOGIC: SUB-LOGIC - Combo finished cycle. Resetting index to 0.")
			
	else:
		current_combo_index = 0
		print("[Player] LOGIC: ELSE - Timer inactive or first attack. Starting combo from 0.")
		
	current_state = State.ATTACK
	_play_hsm("attack", {"combo_start_index": current_combo_index})


func play_tail(anim_name: String, event_name: String = "") -> void:
	if tail_animation_player and tail_animation_player.has_animation(anim_name):
		tail_animation_player.seek(0, true)
		tail_animation_player.play(anim_name)
	if event_name != "":
		_play_hsm(event_name)

func update_facing(input_dir: Vector2) -> void:
	if abs(input_dir.x) > move_threshold:
		last_facing_direction_x = sign(input_dir.x)

func handle_tail_flip(input_dir: Vector2, is_moving: bool) -> void:
	if is_moving and abs(input_dir.x) > move_threshold:
		var new_facing: float = sign(input_dir.x)
		if new_facing != sign(tail_container.scale.x):
			tail_container.scale.x = new_facing
			var offset_x: float = 0.02 * new_facing
			tail_container.position.x += offset_x

func _play_hsm(event_name: String, cargo: Dictionary = {}) -> void:
	if not anim_hsm:
		push_warning("AnimationHSM node não encontrado")
		return
	
	var final_cargo = cargo.duplicate()
	final_cargo["player_ref"] = self
	
	if event_name == "platform_switch_up":
		event_name = "platform_switch"
		final_cargo["target"] = Platform.A
	elif event_name == "platform_switch_down":
		event_name = "platform_switch"
		final_cargo["target"] = Platform.C
	
	print("[Player] Sending to HSM: '%s'" % event_name)
	
	if anim_hsm.has_method("dispatch"):
		anim_hsm.dispatch(event_name, final_cargo)
	elif anim_hsm.has_method("trigger_event"):
		anim_hsm.trigger_event(event_name, final_cargo)

func _on_platform_animation_finished(anim_name: String) -> void:
	is_transitioning = false
	current_state = State.IDLE
	_play_hsm("idle")

func on_animation_state_finished() -> void:
	is_transitioning = false
	print("[Player] Animation state finished - can accept new inputs")
