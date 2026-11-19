extends "res://scripts/ecosystem_complex.gd"
const PermanentDetail=preload("res://scripts/core_habitat.gd")
func make_living_detail(): return PermanentDetail.new()
func create_living_models() -> void:
	living_models=Factory.create(registry,game.save_path,"",game)
func decorate_rooms(rooms: Array) -> void:
	super.decorate_rooms(rooms)
	for room in rooms:
		room["permanent_room"]=true
		if not game.species_known(room.get("species_id","")):
			room.preview_accessible=false
			room.name="Неизвестный обитатель"
			room["archive_name"]=room.name
			room.description="Откройте обитателя в экспедициях."
		else:
			room.description="Дом обитателя комплекса."
func setup(value: Control,model=null) -> void:
	game=value
	super.setup(value,model)
	if game.campaign_progress.completed.is_empty():
		notify("Начните экспедицию в зале порталов")
		toast.position=Vector2(30,435)
