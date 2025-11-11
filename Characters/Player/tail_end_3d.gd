extends AnimatableBody3D

@export var player: Node3D
@export var mesh_path: NodePath = "CollisionShape3D/MeshInstance"
@export var tilt_strength := 0.4        # Intensidade da inclinação (quanto o Y influencia)
@export var max_tilt_angle := 45.0      # Máximo de inclinação (graus)
@export var flip_smoothness := 6.0      # Suavidade da inversão horizontal
@export var tilt_smoothness := 5.0      # Suavidade da rotação

var mesh: MeshInstance3D
var target_flip := 1.0
var current_flip := 1.0
var target_tilt := 0.0

func _ready() -> void:
	mesh = get_node_or_null(mesh_path)
	if not mesh:
		push_warning("MeshInstance não encontrado no caminho: %s" % mesh_path)
		return
	current_flip = sign(mesh.scale.x) if mesh.scale.x != 0 else 1.0

func _process(delta: float) -> void:
	if not player or not mesh:
		return

	# --- FLIP baseado no X ---
	var dir_x := player.global_position.x - global_position.x
	if abs(dir_x) > 0.05:
		target_flip = -1.0 if dir_x < 0.0 else 1.0

	current_flip = lerp(current_flip, target_flip, delta * flip_smoothness)
	mesh.scale.x = abs(mesh.scale.x) * current_flip

	# --- INCLINAÇÃO baseada na diferença de altura ---
	var y_diff := player.global_position.y - global_position.y
	target_tilt = clamp(y_diff * tilt_strength, -max_tilt_angle, max_tilt_angle)

	# Aplica suavemente a rotação — use o eixo correto para o seu modelo!
	var target_rot := deg_to_rad(target_tilt)
	mesh.rotation.x = lerp_angle(mesh.rotation.x, target_rot, delta * tilt_smoothness)
