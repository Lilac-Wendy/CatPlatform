extends LimboState
@export var animation_player: AnimationPlayer
@export var jump_east: String = "JUMP_EAST"
@export var jump_west: String = "JUMP_WEST"

var player: Node
var animation_finished := false

func _enter(_msg := {}) -> void:
	player = get_parent().get_parent()
	if not player:
		push_warning("Jumping: player not found")
		return

	animation_finished = false
	
	# Conecta o sinal UMA vez
	if not animation_player.animation_finished.is_connected(_on_finished):
		animation_player.animation_finished.connect(_on_finished)

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

func _process(_delta: float) -> void:
	if not player or animation_finished:
		return
	
	# VERIFICA SE JÁ POUSOU - isso é mais importante que a animação terminar
	if player.is_on_floor():
		print("[Jumping] Player landed - finishing state")
		_end_state()

func _on_finished(anim_name: String) -> void:
	print("[Jumping] Animation finished: %s" % anim_name)
	animation_finished = true
	
	# Não finaliza imediatamente - espera o player pousar
	# A verificação de pouso é feita no _process

func _end_state() -> void:
	
	print("[Estado] Terminando e notificando HSM")
	var hsm = get_parent()
	if hsm and hsm.has_method("on_state_finished"):
		hsm.on_state_finished(name)  # "name" é o nome do nó do estado

	if animation_player.animation_finished.is_connected(_on_finished):
		animation_player.animation_finished.disconnect(_on_finished)
		
	if has_method("dispatch"):
		dispatch("finished")
	else:
		emit_signal("event", "finished")


	# Notifica a HSM que este estado terminou
