extends Control
const UI=preload("res://scripts/mobile_ui.gd")
const Scroll=preload("res://scripts/mobile_scroll.gd")
const ArtCard=preload("res://scripts/mobile_art_card.gd")
var owner_ui
var data: Dictionary={}
func setup(parent_ui: Control,value: Dictionary) -> void:
	owner_ui=parent_ui; data=value; size=owner_ui.game.view.native_design(); z_index=60; mouse_filter=Control.MOUSE_FILTER_STOP; theme=UI.theme_for(owner_ui.game.view.geometry)
	var card=UI.modal(self,owner_ui.game.view.geometry,"%02d · %s" % [data.number,data.name])
	for pair in [["Цели",data.goals],["Сложность",data.difficulty],["Бустеры",data.boosters],["Лучший результат",data.best_text]]:
		UI.label(card.content,pair[0],25); UI.label(card.content,pair[1])
	if not data.discoveries.is_empty():
		UI.label(card.content,"Возможные новые формы",25)
		var row=UI.row(card.content)
		for form in data.discoveries:
			var art=ArtCard.new(); art.setup(form,false,100); art.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(art)
	UI.button(card.footer,"PreviewClose","Закрыть",owner_ui.close_preview,owner_ui.game.view.geometry.touch)
	UI.button(card.footer,"PreviewPlay","Играть",owner_ui.play_preview,owner_ui.game.view.geometry.touch)
	Scroll.attach(card.scroll,func(): return owner_ui.preview==self)
func _draw() -> void: draw_rect(Rect2(Vector2.ZERO,size),UI.BG)
