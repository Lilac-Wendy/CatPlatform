extends LimboState
@export var animation_player: AnimationPlayer
@export var idle_east: String = "IDLE_EAST"
@export var idle_west: String = "IDLE_WEST"

func _enter(_msg := {}) -> void:
	var player = get_parent().get_parent()
	if not player:
		push_warning("IdleState: player not found")
		return

	var anim_name = idle_east if player.last_facing_direction_x > 0 else idle_west

	if animation_player and animation_player.has_animation(anim_name):
		print("[IdleState] play anim=%s" % anim_name)
		animation_player.seek(0, true)
		animation_player.play(anim_name)
		player._play_hsm("idle")

	if player.has_method("play_tail"):
		player.play_tail("IDLE")
		
func _end_state() -> void:
	print("[Estado] Terminando e notificando HSM")
	
	# Notifica a HSM que este estado terminou
	var hsm = get_parent()
	if hsm and hsm.has_method("on_state_finished"):
		hsm.on_state_finished(name)  # "name" é o nome do nó do estado
	
	if has_method("dispatch"):
		dispatch("finished")
	else:
		emit_signal("event", "finished")
