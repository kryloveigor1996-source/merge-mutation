extends Control
const W=preload("res://scripts/journey_widgets.gd")
const C=preload("res://scripts/mutant_catalog.gd")
const Art=preload("res://scripts/mutant_art.gd")
var game
func setup(value) -> void:
	game=value
	size=Vector2(960,540)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var won: bool=game.campaign.status=="won"
	W.label(self,"ЭКСПЕРИМЕНТ УДАЛСЯ!" if won else "НОВАЯ ПОПЫТКА ВПЕРЕДИ",Rect2(70,38,820,50),30,W.INK,true)
	W.label(self,"Уровень %d · %s" % [game.campaign.config.number,game.campaign.config.name],Rect2(70,92,820,42),20,W.INK,true)
	var reward: Dictionary=game.last_reward
	if game.reward_pending:
		W.label(self,reward.get("error","Результат ожидает сохранения"),Rect2(100,180,760,100),22,W.INK,true)
		W.button(self,"RetrySave","ПОВТОРИТЬ СОХРАНЕНИЕ",Rect2(280,330,400,58),func(): game.settle_campaign_action())
		return
	W.label(self,"+%d монет   ·   +%d биокапсул" % [reward.get("coins",0),reward.get("bio_capsules",0)] if won else "Наград за эту попытку нет",Rect2(100,146,760,52),25,W.INK,true)
	var opened: Array=reward.get("species",[])
	if won and not reward.get("first",false): W.label(self,"Одноразовая награда уже получена",Rect2(110,201,740,32),16,W.INK,true)
	if not opened.is_empty():
		var id: String=opened[0]
		var art:=Art.new()
		art.setup_form(C.make(id),true)
		art.position=Vector2(195,304)
		art.scale=Vector2.ONE*2
		add_child(art)
		W.label(self,"НОВЫЙ ОБИТАТЕЛЬ · "+C.species(id).name,Rect2(290,240,550,50),23)
		W.label(self,"Открыт вольер. Изучите обитателя в бестиарии." if game.habitat_for_species(id)!="" else "Вольер на подготовке. Досье доступно в бестиарии.",Rect2(290,292,550,70),18)
	elif won:
		W.label(self,"Развивайте вольеры и открывайте новые наблюдения.",Rect2(140,250,680,70),21,W.INK,true)
	else:
		W.label(self,game.campaign.reason+". Попробуйте другой подход.",Rect2(140,245,680,90),21,W.INK,true)
	if won and int(game.campaign.config.number)==10:
		W.label(self,"Доступна карта Токсичных болот",Rect2(160,357,640,34),18,W.INK,true)
	if won and int(game.campaign.config.number)<10:
		W.button(self,"ContinueExpedition","ПРОДОЛЖИТЬ ЭКСПЕДИЦИЮ",Rect2(80,420,390,60),func(): game.start_level(int(game.campaign.config.number)+1,false))
	else:
		W.button(self,"RetryLevel","ПОВТОРИТЬ",Rect2(80,420,390,60),func(): game.start_level(int(game.campaign.config.number),false))
	W.button(self,"ReturnComplex","В КОМПЛЕКС",Rect2(490,420,390,60),func(): game.leave_campaign(); game.view.open_complex(),Color("c4e4d9"))
func _draw() -> void:
	draw_rect(Rect2(0,0,960,540),Color("c9e4dc"))
	draw_style_box(W.box(Color("fff4d8"),24),Rect2(46,22,868,490))
