extends LimboState
@export var animation_player: AnimationPlayer
@export var jump_east: String = "JUMP_EAST"
@export var jump_west: String = "JUMP_WEST"

func _enter(_msg := {}) -> void:
	var player = get_parent().get_parent()
	if not player:
		push_warning("Jumping: player not found")
		_end_state()
		return

	if not animation_player.is_connected("animation_finished", Callable(self, "_on_finished")):
		animation_player.animation_finished.connect(_on_finished, CONNECT_ONE_SHOT)

	var anim_name = jump_east if player.last_facing_direction_x > 0 else jump_west

	if animation_player.has_animation(anim_name):
		print("[Jumping] play anim=%s" % anim_name)
		animation_player.seek(0, true)
		animation_player.play(anim_name)

		if player.has_method("play_tail"):
			player.play_tail("IDLE")
	else:
		push_warning("Jumping: animation '%s' not found" % anim_name)
		_end_state()

func _on_finished(anim_name: String) -> void:
	var player = get_parent().get_parent()
	if not player:
		_end_state()
		return

	if player.current_state == player.State.ATTACK:
		print("[Jumping] Ignoring finished — attack in progress.")
		return

	print("[Jumping] finished animation=%s" % anim_name)
	_end_state()

func _end_state() -> void:
	if has_method("dispatch"):
		dispatch("finished")
	else:
		emit_signal("event", "finished")
