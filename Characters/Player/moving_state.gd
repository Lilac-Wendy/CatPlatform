extends LimboState
@export var animation_player: AnimationPlayer
@export var walk_east: String = "WALK_EAST"
@export var walk_west: String = "WALK_WEST"

func _enter(_msg := {}) -> void:
	var player = get_parent().get_parent()
	if not player:
		push_warning("MovingState: player não encontrado")
		return

	var anim_name = walk_east if player.last_facing_direction_x > 0 else walk_west

	if animation_player and animation_player.has_animation(anim_name):
		print("[MovingState] play anim=%s" % anim_name)
		animation_player.seek(0, true)
		animation_player.play(anim_name)
		player._play_hsm("move")

	# 🔹 toca a cauda idle junto
	if player.has_method("play_tail"):
		player.play_tail("IDLE")
