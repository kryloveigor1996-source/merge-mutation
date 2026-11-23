extends RefCounted
const BG=Color("11191d")
const PANEL=Color("1d292e")
const LINE=Color("35474e")
const INK=Color("eff5ee")
const MUTED=Color("a7babd")
const BIO=Color("a6d78b")
const PURPLE=Color("b99add")
static func box(color: Color=PANEL,border: Color=LINE) -> StyleBoxFlat:
	var style=StyleBoxFlat.new(); style.bg_color=color; style.border_color=border
	style.set_border_width_all(1); style.set_corner_radius_all(14)
	style.content_margin_left=16; style.content_margin_right=16; style.content_margin_top=12; style.content_margin_bottom=12
	return style
static func theme_for(layout) -> Theme:
	var result=Theme.new(); result.default_font_size=roundi(22*layout.text_scale)
	for type in ["Label","Button","LineEdit","OptionButton","CheckButton"]: result.set_color("font_color",type,INK)
	result.set_color("font_disabled_color","Button",Color("7c9295"))
	result.set_stylebox("normal","Button",box())
	result.set_stylebox("hover","Button",box(Color("2e4540"),BIO))
	result.set_stylebox("pressed","Button",box(Color("354d3f"),BIO))
	result.set_stylebox("disabled","Button",box(Color("19252a")))
	result.set_stylebox("focus","Button",box(Color(0,0,0,0),Color.WHITE))
	result.set_stylebox("normal","LineEdit",box())
	result.set_constant("v_separation","PopupMenu",roundi(layout.touch-28))
	result.set_stylebox("panel","PanelContainer",box()); result.set_stylebox("panel","Panel",box())
	return result
static func fill(control: Control) -> void: control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
static func label(parent: Node,text: String,font_size: int=22) -> Label:
	var item=Label.new(); item.text=text; item.add_theme_font_size_override("font_size",roundi(font_size*maxf(1,parent.get_theme_default_font_size()/22.0)) if parent is Control else font_size)
	item.add_theme_color_override("font_color",INK); item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	item.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(item); return item
static func button(parent: Node,id: String,text: String,callback: Callable,minimum: float=84) -> Button:
	var item=Button.new(); item.name=id; item.text=text; item.custom_minimum_size=Vector2(minimum,minimum)
	item.size_flags_horizontal=Control.SIZE_EXPAND_FILL; item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	item.pressed.connect(callback); parent.add_child(item); return item
static func row(parent: Node) -> HBoxContainer:
	var item=HBoxContainer.new(); item.add_theme_constant_override("separation",12); parent.add_child(item); return item
static func column(parent: Node) -> VBoxContainer:
	var item=VBoxContainer.new(); item.add_theme_constant_override("separation",12); parent.add_child(item); return item
static func shell(parent: Control,layout,title: String,back: Callable,settings: Callable=Callable(),footer: bool=false) -> Dictionary:
	var background=ColorRect.new(); background.color=BG; fill(background); background.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(background)
	var margin=MarginContainer.new(); fill(margin)
	for key in ["margin_left","margin_right","margin_top","margin_bottom"]: margin.add_theme_constant_override(key,16)
	margin.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(margin)
	var stack=column(margin); stack.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var head=row(stack); head.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var exit=button(head,"MobileBack","‹",back,layout.touch); exit.size_flags_horizontal=0
	var caption=label(head,title,26); caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if settings.is_valid():
		var gear=button(head,"MobileSettings","⚙",settings,layout.touch); gear.size_flags_horizontal=0
	var body=Control.new(); body.name="MobileContent"; body.size_flags_vertical=Control.SIZE_EXPAND_FILL; body.mouse_filter=Control.MOUSE_FILTER_IGNORE; stack.add_child(body)
	var dock=row(stack) if footer else null
	return {"root":margin,"stack":stack,"head":head,"body":body,"dock":dock}
static func modal(parent: Control,layout,title: String) -> Dictionary:
	var overlay=Control.new(); overlay.name="MobileModal"; overlay.z_index=80; overlay.mouse_filter=Control.MOUSE_FILTER_STOP; fill(overlay); parent.add_child(overlay)
	var shade=ColorRect.new(); shade.color=BG; fill(shade); overlay.add_child(shade)
	var outer=MarginContainer.new(); fill(outer)
	for key in ["margin_left","margin_right","margin_top","margin_bottom"]: outer.add_theme_constant_override(key,20)
	overlay.add_child(outer)
	var stack=column(outer); label(stack,title,28)
	var scroll=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; stack.add_child(scroll)
	var content=column(scroll); content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return {"overlay":overlay,"content":content,"footer":row(stack),"scroll":scroll}
static func clear(node: Node) -> void:
	for child in node.get_children(): node.remove_child(child); child.queue_free()
