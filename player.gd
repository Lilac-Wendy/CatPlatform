extends CharacterBody3D

# ==========================
# === CONFIGURAÇÕES GERAIS
# ==========================
@export var move_speed: float = 8.0
@export var jump_force: float = 4.5
@export var gravity: float = 10.0
@export var move_threshold: float = 0.1

# Novos parâmetros
@export var jump_buffer_time: float = 0.15
@export var coyote_time: float = 0.1
@export var air_control: float = 0.6

# ==========================
# === ATRIBUTOS DO PLAYER
# ==========================
@export var attack_speed: float = 1.0
@export var allow_gravity_during_attack := true
@export_enum("normal", "float", "stall", "suspend") var air_attack_mode: String = "stall"
@export var air_attack_gravity_scale := 0.4
@export var stall_duration_base := 0.35
@export var stall_horizontal_damp := 0.2

# ==========================
# === REFERÊNCIAS DE NÓS
# ==========================
@onready var sprite_animation_player: AnimationPlayer = $SpriteSheetPlayer
@onready var platform_animation_player: AnimationPlayer = $PlatformSwitchPlayer
@onready var anim_hsm: Node = $AnimationHSM
@onready var tail_container: Node3D = $TailContainer
@onready var tail_animation_player: AnimationPlayer = $TailPlayer

# ==========================
# === ESTADOS / PLATAFORMAS
# ==========================
enum State { IDLE, WALK, JUMP, FALL, Z_TRANSITION, ATTACK }
var current_state: State = State.IDLE

enum Platform { A, B, C }
const PLATFORM_DISTANCE = 30.0
const Z_MIDDLEGROUND = 0.0
const Z_FOREGROUND = -PLATFORM_DISTANCE
const Z_BACKGROUND = PLATFORM_DISTANCE

var current_platform: Platform = Platform.B
var current_platform_z: float = Z_MIDDLEGROUND

# ==========================
# === VARIÁVEIS INTERNAS
# ==========================
var is_transitioning := false
var was_in_air := false
var last_input_dir := Vector2.ZERO
var last_facing_direction_x := 1.0
var stall_timer: Timer = null
var stall_active := false

# Novas variáveis para pulo e queda
var jump_buffer_timer: float = 0.0
var coyote_timer: float = 0.0
var just_jumped := false

# ==========================
# === READY
# ==========================
func _ready() -> void:
	global_position.z = Z_MIDDLEGROUND
	current_platform_z = Z_MIDDLEGROUND
	platform_animation_player.animation_finished.connect(_on_platform_animation_finished)

# ==========================
# === INPUT
# ==========================
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = jump_buffer_time

# ==========================
# === PHYSICS PROCESS
# ==========================
func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	var in_attack := current_state == State.ATTACK

	# Atualização de timers
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	if coyote_timer > 0:
		coyote_timer -= delta

	# Detectar se acabou de cair ou pousar
	var just_landed := was_in_air and on_floor
	was_in_air = not on_floor
	if on_floor:
		coyote_timer = coyote_time

	# =====================
	# === MOVIMENTO HORIZONTAL
	# =====================
	var input_dir: Vector2 = Input.get_vector("left", "right", "up", "down")
	var is_moving: bool = input_dir.length() > move_threshold
	handle_tail_flip(input_dir, is_moving)
	update_facing(input_dir)

	if not is_transitioning:
		if current_state != State.ATTACK:
			var target_speed := input_dir.x * move_speed
			if not on_floor:
				# controle aéreo limitado
				velocity.x = lerp(velocity.x, target_speed, air_control)
			else:
				velocity.x = target_speed

			if is_moving and on_floor:
				if current_state != State.WALK:
					current_state = State.WALK
					_play_hsm("move")
			elif on_floor:
				if current_state != State.IDLE:
					current_state = State.IDLE
					_play_hsm("idle")
		else:
			# Em ataque, reduzir controle
			if not on_floor:
				velocity.x = move_toward(velocity.x, 0, move_speed * 0.2)
			else:
				velocity.x = 0

	# =====================
	# === GRAVIDADE E PULO
	# =====================
	if not on_floor:
		velocity.y -= gravity * delta
	else:
		velocity.y = max(velocity.y, 0)

	# Jump buffer + coyote time
	if jump_buffer_timer > 0 and coyote_timer > 0 and not is_transitioning and current_state != State.ATTACK:
		velocity.y = jump_force
		current_state = State.JUMP
		_play_hsm("jump")
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		was_in_air = true
		just_jumped = true

	# =====================
	# === MOVIMENTO FINAL
	# =====================
	velocity.z = 0
	move_and_slide()

	# =====================
	# === TRANSIÇÕES DE ESTADO
	# =====================
	if not on_floor and velocity.y < 0 and current_state != State.FALL and not in_attack:
		current_state = State.FALL
		_play_hsm("fall")

	if just_landed and not is_transitioning and current_state != State.ATTACK:
		current_state = State.IDLE
		_play_hsm("idle")

	# =====================
	# === ATAQUE
	# =====================
	if Input.is_action_just_pressed("attack") and not is_transitioning:
		current_state = State.ATTACK
		if not on_floor:
			if velocity.y > 0.0:
				velocity.y *= 0.3
				velocity.x *= 0.1
		_play_hsm("attack")

	# =====================
	# === TROCA DE PLATAFORMA
	# =====================
	if Input.is_action_just_pressed("ui_up") and not is_transitioning:
		_play_hsm("platform_switch_up")
	elif Input.is_action_just_pressed("ui_down") and not is_transitioning:
		_play_hsm("platform_switch_down")

# ==========================
# === CALLBACKS / AUXILIARES
# ==========================
func _on_stall_end() -> void:
	stall_active = false
	if stall_timer:
		stall_timer.queue_free()
		stall_timer = null

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

func _play_hsm(event_name: String) -> void:
	if not anim_hsm:
		push_warning("AnimationHSM node não encontrado")
		return
	if anim_hsm.has_method("dispatch"):
		anim_hsm.dispatch(event_name, {"player_ref": self})
	elif anim_hsm.has_method("trigger_event"):
		anim_hsm.trigger_event(event_name, {"player_ref": self})

func _on_platform_animation_finished(anim_name: String) -> void:
	is_transitioning = false
	if current_state != State.ATTACK:
		current_state = State.IDLE
		_play_hsm("idle")
