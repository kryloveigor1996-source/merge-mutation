extends Control
const W=preload("res://scripts/journey_widgets.gd")
var preferences
var owner_view
var active_id=""
var active_scope=""
var target=Rect2()
var expires=0.0
var cooldown=0.0
var card: Panel
var requests: Array=[]
func setup(view,settings) -> void:
	owner_view=view
	preferences=settings
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	z_index=90
func request(id: String,text: String,highlight: Rect2=Rect2(),scope: String="") -> bool:
	if not preferences.hints or preferences.shown.has(id) or preferences.learned.has(id): return false
	requests=requests.filter(func(item): return item.id!=id)
	requests.append({"id":id,"text":text,"target":highlight,"scope":scope})
	return true
func dismiss() -> void:
	if is_instance_valid(card): card.queue_free()
	card=null
	active_id=""; active_scope=""
	expires=0
	cooldown=3
	queue_redraw()
func _process(delta: float) -> void:
	cooldown=maxf(0,cooldown-delta)
	if not preferences.hints:
		requests.clear()
		if active_id!="": dismiss()
		return
	var blocked: bool=is_instance_valid(owner_view.story_screen) or is_instance_valid(owner_view.overlay)
	visible=not blocked
	if blocked: return
	var scope=owner_view.hint_scope()
	if active_id!="" and active_scope!="" and active_scope!=scope: dismiss()
	if active_id!="":
		expires-=delta
		if expires<=0: dismiss()
		return
	if requests.is_empty() or cooldown>0: return
	var eligible=-1
	for index in range(requests.size()):
		if requests[index].scope=="" or requests[index].scope==scope: eligible=index; break
	if eligible<0: return
	var item: Dictionary=requests.pop_at(eligible)
	if preferences.shown.has(item.id) or preferences.learned.has(item.id): return
	active_id=item.id; active_scope=item.scope
	target=item.target
	preferences.shown[item.id]=true
	preferences.save()
	expires=7
	card=Panel.new()
	card.name="ContextHint"
	card.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var tall: bool=owner_view.portrait_mode
	card.position=Vector2(20,124) if tall else Vector2(280,10)
	card.size=Vector2(500,76) if tall else Vector2(410,66)
	card.add_theme_stylebox_override("panel",W.box(Color("fff0af"),12))
	add_child(card)
	W.label(card,item.text,Rect2(12,6,card.size.x-68,card.size.y-12),16)
	W.button(card,"DismissHint","×",Rect2(card.size.x-50,10,44,44),dismiss)
	queue_redraw()
func _draw() -> void:
	if not active_id.is_empty() and target.size!=Vector2.ZERO: draw_rect(target.grow(3),Color("ffd34d"),false,4)