extends Control
## Embedded confirmation follows the same mobile safe-area transform as the room.
signal confirmed
signal canceled
const W=preload("res://scripts/journey_widgets.gd")
var title:=""
var dialog_text:=""
var body: Label
var ok_button: Button
var cancel_button: Button
func _init() -> void:
	size=Vector2(960,540)
	z_index=10
	mouse_filter=Control.MOUSE_FILTER_STOP
	body=W.label(self,"",Rect2(258,198,444,80),16)
	ok_button=W.button(self,"ResetConfirmed","СБРОСИТЬ ДЕМО",Rect2(258,300,214,48),func(): hide(); confirmed.emit())
	cancel_button=W.button(self,"ResetCanceled","ОТМЕНА",Rect2(488,300,214,48),func(): hide(); canceled.emit(),Color("b5e9ee"))
	hide()
func popup_centered() -> void:
	body.text=dialog_text
	show()
	cancel_button.grab_focus()
	queue_redraw()
func get_ok_button() -> Button: return ok_button
func get_cancel_button() -> Button: return cancel_button
func get_label() -> Label: return body
func _draw() -> void:
	draw_rect(Rect2(0,0,960,540),Color(0.04,0.1,0.15,0.7))
	draw_style_box(W.box(Color("fff8de")),Rect2(242,148,476,218))
	draw_string(ThemeDB.fallback_font,Vector2(258,182),title,HORIZONTAL_ALIGNMENT_LEFT,444,19,W.INK)
