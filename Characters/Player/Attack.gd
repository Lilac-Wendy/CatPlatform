extends LimboState

@export var animation_player: AnimationPlayer
@export var base_lock_duration := 1.5

@export var combo_sequence: Array[String] = ["SMASH", "THRUST", "SPIN"]

var current_combo_index := 0
var queued_next_attack := false

var lock_timer: Timer
var player: Node

func _enter(msg: Dictionary = {}) -> void:
	if not animation_player:
		push_warning("Attack: animation player not defined.")
		_end_state()
		return

	if not animation_player.is_connected("animation_finished", Callable(self, "_on_finished")):
		animation_player.animation_finished.connect(_on_finished, CONNECT_ONE_SHOT)

	player = get_parent().get_parent()
	if not player:
		push_warning("Attack: player not found")
		_end_state()
		return

	var anim_name: String
	if msg.has("animation"):
		anim_name = msg["animation"]
	elif current_combo_index < combo_sequence.size():
		anim_name = combo_sequence[current_combo_index]
	else:
		anim_name = combo_sequence[0]

	print("[Attack] Combo #%d anim=%s" % [current_combo_index + 1, anim_name])

	if animation_player.has_animation(anim_name):
		var atk_speed = player.attack_speed if "attack_speed" in player else 1.0

		animation_player.seek(0, true)
		animation_player.play(anim_name)
		animation_player.speed_scale = atk_speed

		if player.has_method("play_tail"):
			player.play_tail("ATTACK")

		player.is_transitioning = true

		lock_timer = Timer.new()
		lock_timer.wait_time = base_lock_duration / atk_speed
		lock_timer.one_shot = true
		lock_timer.timeout.connect(_on_attack_finished)
		add_child(lock_timer)
		lock_timer.start()

		queued_next_attack = false
		print("[Attack] atk_speed=%.2f lock_time=%.2f" % [atk_speed, lock_timer.wait_time])
	else:
		push_warning("Attack: animation '%s' not found" % anim_name)
		_end_state()

func _process(_delta: float) -> void:

	if player and Input.is_action_just_pressed("attack") and lock_timer and lock_timer.time_left > 0:
		if not queued_next_attack and current_combo_index < combo_sequence.size() - 1:
			queued_next_attack = true
			print("[Attack] Next chained attack prepared (combo step %d → %d)" %
				[current_combo_index + 1, current_combo_index + 2])

func _on_finished(_anim_name: String) -> void:
	if lock_timer and lock_timer.time_left > 0:
		lock_timer.stop()
	_on_attack_finished()

func _on_attack_finished() -> void:
	if not player:
		return

	player.is_transitioning = false

	if queued_next_attack and current_combo_index < combo_sequence.size() - 1:

		current_combo_index += 1
		print("[Attack] Encadeando para combo #%d" % (current_combo_index + 1))
		_enter({})  
		return
	else:

		current_combo_index = 0
		if not player.is_on_floor():
			player.current_state = player.State.JUMP
			player._play_hsm("jump")
		else:
			player.current_state = player.State.IDLE
			player._play_hsm("idle")

	_end_state()

func _exit() -> void:
	if lock_timer and lock_timer.is_inside_tree():
		lock_timer.queue_free()

func _end_state() -> void:
	if has_method("dispatch"):
		dispatch("finished")
	else:
		emit_signal("event", "finished")
