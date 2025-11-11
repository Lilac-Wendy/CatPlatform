extends CharacterBody3D

# ==========================
# === CONFIGURAÇÕES GERAIS
# ==========================
const SPEED = 8.0
const JUMP_VELOCITY = 4.5
const GRAVITY = 10.0
const MOVE_THRESHOLD = 0.1

# ==========================
# === ATRIBUTOS DO PLAYER
# ==========================
@export var attack_speed: float = 1.0  # 1.0 = normal, >1 = mais rápido, <1 = mais lento
@export var allow_gravity_during_attack := true

# --- Configuração do comportamento aéreo durante ataque ---
@export_enum("normal", "float", "stall", "suspend") var air_attack_mode: String = "stall"

@export var air_attack_gravity_scale := 0.4  # gravidade reduzida (modo float)
@export var stall_duration_base := 0.35      # duração base do stall em segundos
@export var stall_horizontal_damp := 0.2     # quanto reduz horizontalmente no stall

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
enum State { IDLE, WALK, JUMP, Z_TRANSITION, ATTACK }
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

# ==========================
# === READY
# ==========================
func _ready() -> void:
	global_position.z = Z_MIDDLEGROUND
	current_platform_z = Z_MIDDLEGROUND
	platform_animation_player.animation_finished.connect(_on_platform_animation_finished)

# ==========================
# === PHYSICS PROCESS
# ==========================
func _physics_process(delta: float) -> void:
	var just_landed := was_in_air and is_on_floor()
	was_in_air = not is_on_floor()
	var in_attack := current_state == State.ATTACK

	# =====================
	# === GRAVIDADE
	# =====================
	if not is_on_floor():
		var gravity_force := GRAVITY

		if in_attack:
			match air_attack_mode:
				"float":
					# reduz um pouco a gravidade (sustentação de golpe aéreo)
					gravity_force *= 0.6
				"stall":
					# pausa a gravidade por um curto período
					if not stall_active:
						stall_active = true
						var stall_time: float = clamp(stall_duration_base / attack_speed, 0.1, 0.6)
						var t := get_tree().create_timer(stall_time)
						t.timeout.connect(func(): stall_active = false)
					if stall_active:
						gravity_force = 0
				"suspend":
					# totalmente parado no ar (raramente usado, tipo “skill cutscene”)
					gravity_force = 0

		velocity.y -= gravity_force * delta

	# =====================
	# === MOVIMENTO HORIZONTAL
	# =====================
	var input_dir: Vector2 = Input.get_vector("left", "right", "up", "down")
	var is_moving: bool = input_dir.length() > MOVE_THRESHOLD
	handle_tail_flip(input_dir, is_moving)
	update_facing(input_dir)

	if not is_transitioning:
		if current_state != State.ATTACK:
			if is_moving:
				velocity.x = input_dir.x * SPEED
				if current_state != State.WALK:
					current_state = State.WALK
					_play_hsm("move")
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)
				if current_state != State.IDLE:
					current_state = State.IDLE
					_play_hsm("idle")
		else:
			# Movimento durante ataque (no ar)
			if not is_on_floor():
				# mantém momentum, mas amortece levemente
				velocity.x = move_toward(velocity.x, 0, SPEED * 0.2)
			else:
				# ataque no chão trava movimento
				velocity.x = 0

	velocity.z = 0
	move_and_slide()

	# =====================
	# === PÓS-ATUALIZAÇÃO
	# =====================
	if just_landed and not is_transitioning and current_state != State.ATTACK:
		current_state = State.IDLE
		_play_hsm("idle")

	# =====================
	# === INPUTS
	# =====================
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_transitioning:
		velocity.y = JUMP_VELOCITY
		was_in_air = true
		current_state = State.JUMP
		_play_hsm("jump")

	if Input.is_action_just_pressed("attack") and not is_transitioning:
		current_state = State.ATTACK
		if not is_on_floor():
			if velocity.y > 0.0:
				velocity.y *= 0.3
				velocity.x *= 0.1
				
		_play_hsm("attack")

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
	if abs(input_dir.x) > MOVE_THRESHOLD:
		last_facing_direction_x = sign(input_dir.x)

func handle_tail_flip(input_dir: Vector2, is_moving: bool) -> void:
	if is_moving and abs(input_dir.x) > MOVE_THRESHOLD:
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
