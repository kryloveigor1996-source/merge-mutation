extends Control
const UI=preload("res://scripts/mobile_ui.gd")
const TouchScroll=preload("res://scripts/mobile_scroll.gd")
var game
func setup(value) -> void:
	game=value; size=game.view.native_design(); mouse_filter=Control.MOUSE_FILTER_STOP; theme=UI.theme_for(game.view.geometry)
	var won: bool=game.campaign.status=="won"
	var card=UI.modal(self,game.view.geometry,"Эксперимент удался" if won else "Новая попытка впереди")
	UI.label(card.content,"Уровень %d · %s" % [game.campaign.config.number,game.campaign.config.name],26)
	var reward: Dictionary=game.last_reward
	if game.reward_pending:
		UI.label(card.content,reward.get("error","Результат ожидает сохранения"))
		UI.button(card.footer,"RetrySave","Повторить сохранение",func(): game.settle_campaign_action(),game.view.geometry.touch); return
	UI.label(card.content,"+%d монет · +%d биокапсул" % [reward.get("coins",0),reward.get("bio_capsules",0)] if won else "Наград за эту попытку нет",24)
	if won and not reward.get("first",false): UI.label(card.content,"Одноразовая награда уже получена")
	for id in reward.get("species",[]): UI.label(card.content,"Новый обитатель: "+game.Catalog.species(id).name)
	if won and int(game.campaign.config.number)==10: UI.label(card.content,"Доступна карта Токсичных болот")
	if not won: UI.label(card.content,game.campaign.reason)
	if won and int(game.campaign.config.number)<10: UI.button(card.content,"ContinueExpedition","Продолжить экспедицию",func(): game.start_level(int(game.campaign.config.number)+1,false),game.view.geometry.touch)
	UI.button(card.content,"RetryLevel","Повторить уровень",func(): game.start_level(int(game.campaign.config.number),false),game.view.geometry.touch)
	UI.button(card.footer,"ReturnComplex","В комплекс",func(): game.leave_campaign(); game.view.open_complex(),game.view.geometry.touch)
	TouchScroll.attach(card.scroll,func(): return game.view.overlay==self)
func _draw() -> void: draw_rect(Rect2(Vector2.ZERO,size),UI.BG)
