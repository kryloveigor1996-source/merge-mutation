extends "res://scripts/core_result.gd"
func setup(value) -> void:
	super.setup(value)
	var tall: bool=game.view.portrait_mode
	size=Vector2(540,960) if tall else Vector2(960,540)
	if tall:
		var row=0
		for child in get_children():
			if child is Label:
				var rect: Rect2=[Rect2(24,84,492,100),Rect2(24,194,492,70),Rect2(24,276,492,60),Rect2(24,354,492,60),Rect2(24,520,492,70),Rect2(24,600,492,90)][mini(row,5)]
				if child.text.begins_with("НОВЫЙ ОБИТАТЕЛЬ"): rect=Rect2(24,540,492,70)
				elif child.text.begins_with("Развивайте"): rect=Rect2(24,470,492,90)
				elif child.text.begins_with("Доступна карта"): rect=Rect2(24,610,492,54)
				elif "вольер" in child.text or "Вольер" in child.text: rect=Rect2(24,610,492,80)
				child.custom_minimum_size=Vector2.ZERO; child.position=rect.position; child.size=rect.size; row+=1
			elif child is Node2D: child.position=Vector2(270,440); child.scale=Vector2.ONE*2.4
		for id in ["ContinueExpedition","RetrySave"]:
			if has_node(id): get_node(id).custom_minimum_size=Vector2.ZERO; get_node(id).position=Vector2(24,734); get_node(id).size=Vector2(492,60)
		if has_node("ReturnComplex"): get_node("ReturnComplex").position=Vector2(24,814); get_node("ReturnComplex").size=Vector2(492,60)
	if has_node("RetryLevel"):
		var retry: Button=get_node("RetryLevel")
		retry.custom_minimum_size=Vector2.ZERO
		retry.text="Повторить"
		retry.add_theme_font_size_override("font_size",15)
		retry.position=Vector2(346,720) if tall else Vector2(706,358)
		retry.size=Vector2(170,44)
		retry.add_theme_stylebox_override("normal",W.box(Color("e2eae1")))
		if game.campaign.status=="won" and int(game.campaign.config.number)==10:
			var home: Button=get_node("ReturnComplex")
			home.add_theme_stylebox_override("normal",W.box(Color("ffda69")))
			if not tall: home.position=Vector2(150,420); home.size=Vector2(660,60)
func _draw() -> void:
	if not game.view.portrait_mode: super._draw(); return
	draw_rect(Rect2(0,0,540,960),Color("c9e4dc"))
	draw_style_box(W.box(Color("fff4d8"),24),Rect2(12,48,516,856))