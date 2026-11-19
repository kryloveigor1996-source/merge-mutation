extends "res://scripts/ecosystem_habitat.gd"
func setup(parent_screen: Control,value,room: Dictionary,floor: Dictionary) -> void:
	super.setup(parent_screen,value,room,floor)
	get_node("HabitatTest").hide()
	reset_confirmation.hide()
	update_controls()
func update_controls() -> void:
	super.update_controls()
	if room_state==null or not is_instance_valid(status): return
	if is_instance_valid(progress_label): progress_label.text="%d/%d · %d%% · Капсулы: %d" % [room_state.installed.size(),room_state.catalog.slots.size(),room_state.progress(),room_state.points]
	if is_instance_valid(confirm_button):
		var amount: int=0 if room_state.installed.has(chosen_slot) else int(room_state.catalog.slots[chosen_slot].cost)
		panel_cost.text="Смена бесплатно" if amount==0 else "Цена: %d · Баланс: %d" % [amount,room_state.points]
		confirm_button.disabled=room_state.read_only or room_state.points<amount
		if room_state.points<amount: panel_feedback.text="Биокапсулы дают в экспедициях"
func toggle_test_menu() -> void: pass
func toggle_stages() -> void: toggle_repair()
