extends "res://tests/capture_mutants.gd"

func configuration() -> Dictionary:
	return {"levels":[1,2,3,4,5,6,7,8,9,10],"output_prefix":"progressive-all-levels","save_filename":"progressive_all_capture.json","tile_size":128,"dense":true,"capture_collection":true}
