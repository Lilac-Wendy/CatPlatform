extends LimboState
@export var animation_player: AnimationPlayer
@export var base_lock_duration := 1.5

@export var combo_sequence: Array[String] = ["SMASH", "THRUST"]

var queued_next_attack := false
var cooldown_timer: Timer
var player: CharacterBody3D

func _enter(msg: Dictionary = {}) -> void:
	print("--- [AttackState] ENTER ---")
	if not animation_player:
		push_warning("Attack: animation player not defined.")
		_end_state()
		print("[AttackState] EXITING: No animation player.")
		return

	if not animation_player.is_connected("animation_finished", Callable(self, "_on_finished")):
		animation_player.animation_finished.connect(_on_finished, CONNECT_ONE_SHOT)

	player = get_parent().get_parent()
	if "player_ref" in msg:
		player = msg["player_ref"]
	
	if not player or not is_instance_valid(player):
		push_warning("Attack: player not found or invalid.")
		_end_state()
		print("[AttackState] EXITING: Invalid player reference.")
		return
		
	var combo_index = player.current_combo_index
	
	var anim_name: String
	if msg.has("animation"):
		anim_name = msg["animation"]
		print("[AttackState] ANIM LOGIC: IF - Using animation from message.")
	elif combo_index < combo_sequence.size():
		anim_name = combo_sequence[combo_index]
		print("[AttackState] ANIM LOGIC: ELIF - Using combo sequence index %d." % combo_index)
	else:
		player.current_combo_index = 0
		anim_name = combo_sequence[0]
		combo_index = 0
		print("[AttackState] ANIM LOGIC: ELSE - Combo index out of bounds. Resetting index to 0.")
	print("[Attack] Combo #%d anim=%s" % [combo_index + 1, anim_name])
	if animation_player.has_animation(anim_name):
		var atk_speed = player.attack_speed if player.has_method("attack_speed") else 1.0
		animation_player.seek(0, true)
		animation_player.play(anim_name)
		animation_player.speed_scale = atk_speed

		if player.has_method("play_tail"):
			player.play_tail("ATTACK")
		player.is_transitioning = true
		cooldown_timer = Timer.new()
		cooldown_timer.wait_time = base_lock_duration / atk_speed
		cooldown_timer.one_shot = true
		cooldown_timer.timeout.connect(_on_attack_finished)
		add_child(cooldown_timer)
		cooldown_timer.start()

		var combo_timer = player.AttackComboTimer
		if combo_index == 0 and combo_timer and is_instance_valid(combo_timer):
			print("[AttackState] TIMER LOGIC: IF (First Attack) - Starting AttackComboTimer.")
			combo_timer.start()
			print("[Attack] AttackComboTimer started (%.2fs)." % combo_timer.wait_time)
		elif combo_index > 0 and combo_timer and is_instance_valid(combo_timer):
			print("[AttackState] TIMER LOGIC: ELIF (Chaining) - Extending AttackComboTimer.")
			combo_timer.start()
			print("[Attack] AttackComboTimer extended.")
		else:
			print("[AttackState] TIMER LOGIC: ELSE - ComboTimer not valid or not needed yet.")


		queued_next_attack = false
		print("[Attack] atk_speed=%.2f lock_time=%.2f" % [atk_speed, cooldown_timer.wait_time])
	else:
		push_warning("Attack: animation '%s' not found" % anim_name)
		_end_state()

func _process(_delta: float) -> void:
	if player and Input.is_action_just_pressed("attack") and cooldown_timer and cooldown_timer.time_left > 0:
		print("[AttackState] PROCESS LOGIC: Input registered! Cooldown Time Left: %.2f" % cooldown_timer.time_left)
		if not queued_next_attack and player.current_combo_index < combo_sequence.size() - 1:
			queued_next_attack = true
			print("[Attack] Next chained attack prepared (combo step %d → %d)" %
				[player.current_combo_index + 1, player.current_combo_index + 2])
		elif queued_next_attack:
			print("[AttackState] PROCESS LOGIC: Input received, but already queued.")
		else:
			print("[AttackState] PROCESS LOGIC: Input received, but no more combo steps available.")

func _on_finished(_anim_name: String) -> void:
	print("[AttackState] Animation Finished Signal received.")
	if cooldown_timer and cooldown_timer.time_left > 0:
		cooldown_timer.stop()
		print("[AttackState] Stopped cooldown_timer early.")
	_on_attack_finished()

func _on_attack_finished() -> void:
	print("--- [AttackState] ON_ATTACK_FINISHED ---")
	if not player:
		return

	player.is_transitioning = false
	
	if queued_next_attack and player.current_combo_index < combo_sequence.size() - 1:

		player.current_combo_index += 1
		print("[AttackState] CHAINING LOGIC: IF - Chaining internally. New index: %d" % player.current_combo_index)

		_enter({})
		return
	else:
		print("[AttackState] CHAINING LOGIC: ELSE - Combo finished/failed to chain.")
		if not queued_next_attack:
			print("[AttackState] Sub-LOGIC: No input registered in time.")
		
		if not player.is_on_floor():
			player.current_state = player.State.JUMP
			player._play_hsm("jump")
			print("[AttackState] Sub-LOGIC: Transitioning to JUMP.")
		else:
			player.current_state = player.State.IDLE
			player._play_hsm("idle")
			print("[AttackState] Sub-LOGIC: Transitioning to IDLE.")

		_end_state()

func _exit() -> void:
	print("--- [AttackState] EXIT ---")
	if cooldown_timer and cooldown_timer.is_inside_tree():
		cooldown_timer.queue_free()
		print("[AttackState] Cooldown timer freed.")

func _end_state() -> void:
	print("[AttackState] END_STATE called.")
	if has_method("dispatch"):
		dispatch("finished")
	else:
		emit_signal("event", "finished")
