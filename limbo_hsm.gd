extends LimboHSM

@onready var idle_state: LimboState = $IdleState
@onready var moving_state: LimboState = $MovingState
@onready var jumping_state: LimboState = $Jumping
@onready var attack_state: LimboState = $Attack
@onready var platform_state: LimboState = $PlatformSwitch

var state_priority := {
	"idle": 1,
	"move": 2, 
	"jump": 3,
	"platform_switch": 4,
	"attack": 5
}

var current_priority := 0
var current_state_name := ""

func _ready() -> void:
	set_initial_state(idle_state)
	current_state_name = "idle"
	
	# Transições básicas
	add_transition(idle_state, moving_state, "move")
	add_transition(moving_state, idle_state, "idle")
	
	add_transition(idle_state, jumping_state, "jump")
	add_transition(moving_state, jumping_state, "jump")
	add_transition(jumping_state, idle_state, "finished")
	add_transition(jumping_state, moving_state, "move")
	
	# Ataque pode vir de qualquer estado
	add_transition(idle_state, attack_state, "attack")
	add_transition(moving_state, attack_state, "attack") 
	add_transition(jumping_state, attack_state, "attack")
	
	# Ataque pode voltar para QUALQUER estado baseado na situação
	add_transition(attack_state, idle_state, "finished")
	add_transition(attack_state, moving_state, "move")
	add_transition(attack_state, jumping_state, "jump")
	add_transition(attack_state, idle_state, "fall")
	
	# Plataforma
	add_transition(idle_state, platform_state, "platform_switch")
	add_transition(moving_state, platform_state, "platform_switch")
	add_transition(platform_state, idle_state, "finished")
	add_transition(platform_state, moving_state, "move")
	
	initialize(get_parent())
	set_active(true)
	print("[HSM] Ready and active.")

func trigger_event(event_name: String, cargo: Dictionary = {}) -> void:
	if event_name == "":
		return

	var event_priority = state_priority.get(event_name, 0)
	
	print("[HSM] Event: '%s' (prio: %d, current: %d, state: %s)" % 
		  [event_name, event_priority, current_priority, current_state_name])
	
	# PERMITE eventos de menor prioridade se o estado atual terminou
	if event_priority < current_priority and current_priority > 0:
		print("[HSM] Ignoring event '%s' (lower priority: %d < %d)" %
			[event_name, event_priority, current_priority])
		return

	current_priority = event_priority
	current_state_name = event_name
	dispatch(event_name, cargo)

# CHAMAR ESTE MÉTODO QUANDO UM ESTADO TERMINAR
func on_state_finished(state_name: String) -> void:
	print("[HSM] State '%s' finished — priority reset to 0" % state_name)
	current_priority = 0
	current_state_name = "finished"
	
	# DISPARA evento especial para voltar ao idle
	get_tree().create_timer(0.01).timeout.connect(_return_to_idle, CONNECT_ONE_SHOT)

func _return_to_idle() -> void:
	# Força voltar para idle quando qualquer estado termina
	print("[HSM] Auto-returning to idle")
	current_priority = 1
	current_state_name = "idle"
	dispatch("idle")
