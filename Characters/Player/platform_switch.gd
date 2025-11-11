extends LimboState
@export var animation_player: AnimationPlayer

enum Platform { A, B, C }

@export var player_ref: Node = null

func _enter(msg: Dictionary = {}) -> void:
	if not player_ref:
		push_warning("PlatformSwitch: player_ref não definido.")
		_end_state()
		return

	if not animation_player:
		push_warning("PlatformSwitch: animation_player não definido.")
		_end_state()
		return

	if not animation_player.is_connected("animation_finished", Callable(self, "_on_finished")):
		animation_player.animation_finished.connect(_on_finished)

	var target_platform: Platform = msg.get("target", Platform.B)
	var anim_name: String = "Jump_" + str(target_platform)
	print("[PlatformSwitch] enter anim=%s" % anim_name)

	if animation_player.has_animation(anim_name):
		player_ref.is_transitioning = true
		animation_player.seek(0, true)
		animation_player.play(anim_name)
		player_ref.current_platform = target_platform
		# Atualiza Z
		match target_platform:
			Platform.A: player_ref.current_platform_z = player_ref.Z_FOREGROUND
			Platform.B: player_ref.current_platform_z = player_ref.Z_MIDDLEGROUND
			Platform.C: player_ref.current_platform_z = player_ref.Z_BACKGROUND
	else:
		push_warning("PlatformSwitch: animação '%s' não encontrada" % anim_name)
		_end_state()

func _on_finished(anim_name: String) -> void:
	print("[PlatformSwitch] finished anim=%s" % anim_name)
	if player_ref:
		player_ref.is_transitioning = false
		player_ref.current_state = player_ref.State.IDLE
		player_ref._play_hsm("idle")
	_end_state()

func _end_state() -> void:
	if has_method("dispatch"):
		dispatch("finished")
	else:
		emit_signal("event", "finished")
