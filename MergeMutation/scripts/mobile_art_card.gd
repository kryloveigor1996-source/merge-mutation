extends Control
const Art=preload("res://scripts/mutant_art.gd")
var art
var hidden_form=false
func setup(form: Dictionary,known: bool,height: float=180) -> void:
	custom_minimum_size=Vector2(0,height); mouse_filter=Control.MOUSE_FILTER_IGNORE
	art=Art.new(); art.setup_form(form,true); hidden_form=not known
	if hidden_form: art.modulate=Color.BLACK
	add_child(art)
	if hidden_form:
		var question=Label.new(); question.text="?"; question.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; question.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; question.add_theme_font_size_override("font_size",34); question.mouse_filter=Control.MOUSE_FILTER_IGNORE; question.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(question)
	resized.connect(arrange); arrange()
func arrange() -> void:
	if not is_instance_valid(art): return
	art.position=size*.5; art.scale=Vector2.ONE*minf(2.8,maxf(1,minf(size.x-24,size.y-20)/76)); queue_redraw()
