class_name CharacterState
extends LimboState

@export var animation_name : StringName
@export var animation_player: AnimationPlayer
func _enter() -> void:
	agent.sprite.play(animation_name)
	
