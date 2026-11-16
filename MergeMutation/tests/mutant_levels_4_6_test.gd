extends "res://tests/mutant_sprites_test.gd"

func _initialize() -> void:
	levels=[4,5,6]
	save_filename="mutant_levels_4_6_test_save.json"
	suite_label="Level 4/5/6 sprite checks"
	super._initialize()
