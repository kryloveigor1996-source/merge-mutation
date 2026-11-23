extends "res://scripts/evolution_preferences.gd"
func setup(value: String) -> void:
	super.setup(value)
	var file=ConfigFile.new()
	if file.load(value)!=OK or not file.has_section_key("presentation","portrait"): portrait=true
