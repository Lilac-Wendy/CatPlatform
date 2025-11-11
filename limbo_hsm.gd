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

func _ready() -> void:
	set_initial_state(idle_state)

	add_transition(idle_state, moving_state, "move")
	add_transition(moving_state, idle_state, "idle")

	add_transition(idle_state, jumping_state, "jump")
	add_transition(moving_state, jumping_state, "jump")
	add_transition(jumping_state, idle_state, "finished")

	add_transition(idle_state, attack_state, "attack")
	add_transition(moving_state, attack_state, "attack")
	add_transition(jumping_state, attack_state, "attack")
	add_transition(attack_state, idle_state, "finished")

	add_transition(idle_state, platform_state, "platform_switch")
	add_transition(platform_state, idle_state, "finished")

	initialize(get_parent())
	set_active(true)
	print("[HSM] Ready and active.")

func trigger_event(event_name: String, cargo: Dictionary = {}) -> void:
	if event_name == "":
		return

	var event_priority = state_priority.get(event_name, 0)

	if event_priority < current_priority:
		print("[HSM] Ignoring event '%s' (lower priority: %d < %d)" %
			[event_name, event_priority, current_priority])
		return

	current_priority = event_priority
	dispatch(event_name, cargo)
func on_state_finished(state_name: String) -> void:
	current_priority = 0
	print("[HSM] State '%s' finished — priority reset." % state_name)
