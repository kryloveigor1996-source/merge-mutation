extends "res://tests/capture_mutants.gd"

func _initialize() -> void:
	captured_levels=[1,2,3,4,5,6]
	output_prefix="mutants-levels-1-6"
	save_filename="mutants_1_6_capture_save.json"
	super._initialize()
