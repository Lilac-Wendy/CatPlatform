extends Label
@export var limbo_hsn : LimboHSM :
		set(value):
			if limbo_hsn != null:
				limbo_hsn.active_state_changed.disconnect(_on_active_state_changed)
				
				limbo_hsn = value
				if limbo_hsn != null:
					
					var current_state = limbo_hsn.get_active_state()
					if current_state != null:
						text = current_state.name
					limbo_hsn.active_state_changed.connect(_on_active_state_changed)
					
func _on_active_state_changed(current : LimboState, _previous : LimboState):
		text = current.name
