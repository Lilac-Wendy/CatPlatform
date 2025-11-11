extends MeshInstance3D

@export var player: Node3D
@export var tilt_strength := 10.0   # graus por unidade de diferença Y
@export var use_collision_tilt := false
@export var collision_name := "PlayerCollision"

var initial_rotation_z: float = 0.0
var initial_scale_x: float = 1.0
var player_collision: CollisionShape3D = null

func _ready() -> void:
	# guarda offsets iniciais para compensação
	initial_rotation_z = rotation_degrees.z
	initial_scale_x = scale.x

	if not player:
		player = get_tree().get_first_node_in_group("player") # tenta auto achar
	if player and player.has_node(collision_name):
		player_collision = player.get_node(collision_name) as CollisionShape3D

	set_process(true)

func _process(delta: float) -> void:
	if not player:
		return

	# --- Flip horizontal (forçado) ---
	if player.global_position.x > global_position.x:
		scale.x = abs(initial_scale_x)
	else:
		scale.x = -abs(initial_scale_x)

	# --- calcula tilt alvo ---
	var tilt_angle := 0.0
	if use_collision_tilt and player_collision:
		var up_vec := player_collision.global_transform.basis.y.normalized()
		tilt_angle = rad_to_deg(atan2(up_vec.x, up_vec.y))
	else:
		var y_diff := player.global_position.y - global_position.y
		tilt_angle = clamp(y_diff * tilt_strength, -45.0, 45.0)

	# aplica compensação do Z que já existe no mesh no editor
	var target_z := initial_rotation_z + tilt_angle

	# suaviza
	rotation_degrees.z = lerp_angle(rotation_degrees.z, target_z, clamp(delta * 8.0, 0.05, 1.0))
