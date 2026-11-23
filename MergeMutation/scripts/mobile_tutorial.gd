extends "res://scripts/contextual_tutorial.gd"
func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(card):
		card.hide()
		for child in card.get_children():
			if child is Label: owner_view.show_context_hint(child.text); break
func _draw() -> void: pass # Inline hints never cover the board or primary controls.
