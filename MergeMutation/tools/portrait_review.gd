extends SceneTree
## Isolated composition study. Never mounted by main.tscn and never writes a player profile.
const OUT="res://.godot/portrait-review/"
class Study extends Control:
	const BG=Color("11191d")
	const PANEL=Color("1d292e")
	const LINE=Color("35474e")
	const INK=Color("eff5ee")
	const MUTED=Color("99afb3")
	const BIO=Color("a6d78b")
	const PORTAL=Color("b99add")
	var page="complex"
	var height=960.0
	var hitboxes: Array=[]
	var slime=load("res://assets/mutants/slime_lv1.png")
	var horn=load("res://assets/mutants/mutant_lv3.png")
	var unknown=load("res://assets/mutants/mutant_lv2.png")
	var session
	func panel(r: Rect2,color: Color=PANEL,radius: int=16,border: Color=LINE) -> void:
		var box=StyleBoxFlat.new()
		box.bg_color=color; box.border_color=border
		box.set_border_width_all(1); box.set_corner_radius_all(radius)
		draw_style_box(box,r)
	func text(value: String,p: Vector2,font_size: int=20,color: Color=INK) -> void:
		draw_string(ThemeDB.fallback_font,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
	func center_text(value: String,r: Rect2,font_size: int=20,color: Color=INK) -> void:
		var width=ThemeDB.fallback_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		text(value,Vector2(r.get_center().x-width*.5,r.get_center().y+font_size*.35),font_size,color)
	func button(id: String,value: String,r: Rect2,accent: bool=false) -> void:
		hitboxes.append({"id":id,"rect":[r.position.x,r.position.y,r.size.x,r.size.y]})
		panel(r,Color("253b32") if accent else PANEL,14,BIO if accent else LINE)
		center_text(value,r,22,BIO if accent else INK)
	func art(texture: Texture2D,p: Vector2,width: float=116) -> void:
		oval(p+Vector2(0,width*.34),Vector2(width*.36,width*.10),Color(0,0,0,.35))
		draw_texture_rect(texture,Rect2(p-Vector2.ONE*width*.5,Vector2.ONE*width),false)
	func oval(p: Vector2,r: Vector2,c: Color) -> void:
		var pts=PackedVector2Array()
		for i in range(40): pts.append(p+Vector2(cos(i*TAU/40)*r.x,sin(i*TAU/40)*r.y))
		draw_colored_polygon(pts,c)
	func header(title: String,subtitle: String="") -> void:
		button("back","‹",Rect2(16,24,84,84))
		text(title,Vector2(116,61),25)
		text(subtitle,Vector2(116,89),16,MUTED)
		button("settings","⚙",Rect2(440,24,84,84))
	func nav(active: int) -> void:
		var y=height-116
		panel(Rect2(8,y-8,524,100),BG,16)
		for i in range(3):
			button("nav_"+str(i),["Комплекс","Порталы","Бестиарий"][i],Rect2(16+i*172,y,164,84),i==active)
	func track(r: Rect2,fraction: float) -> void:
		panel(r,Color("101c20"),4)
		draw_style_box(bar(BIO),Rect2(r.position,Vector2(r.size.x*fraction,r.size.y)))
	func bar(color: Color) -> StyleBoxFlat:
		var box=StyleBoxFlat.new(); box.bg_color=color; box.set_corner_radius_all(4); return box
	func resources() -> void:
		text("КОМПЛЕКС",Vector2(20,53),23)
		text("◈ 13   ·   100 монет",Vector2(20,87),18,BIO)
		button("lift","Лифт ↕",Rect2(324,24,200,84))
	func room(r: Rect2,title: String,texture: Texture2D,green: bool,count_text: String) -> void:
		panel(r,Color("22352f") if green else Color("34302d"),4)
		# Cross-section: visible wall fittings, floor slab and exposed lift shaft.
		draw_rect(Rect2(r.position+Vector2(6,7),Vector2(r.size.x-12,28)),Color("344b44") if green else Color("4b4640"))
		for y in range(int(r.position.y+80),int(r.end.y-50),48): draw_line(Vector2(r.position.x+12,y),Vector2(r.end.x-12,y),Color(1,1,1,.035),1)
		draw_line(r.position+Vector2(16,56),Vector2(r.position.x+16,r.end.y-50),BIO if green else Color("d3b687"),3)
		panel(Rect2(r.end.x-62,r.position.y+75,44,110),Color("304b3c") if green else Color("595952"),5)
		for i in range(3): draw_circle(Vector2(r.end.x-40,r.position.y+94+i*30),4,BIO if green else Color("b1aaa0"))
		text(title,r.position+Vector2(18,63),23)
		art(texture,r.get_center()+Vector2(-4,15),146)
		draw_rect(Rect2(r.position.x,r.end.y-46,r.size.x,46),Color("162421"))
		text(count_text,Vector2(r.position.x+16,r.end.y-17),18,MUTED)
		draw_line(Vector2(r.position.x,r.end.y+4),Vector2(r.end.x,r.end.y+4),Color("68776e"),8)
		hitboxes.append({"id":"room_"+title,"rect":[r.position.x,r.position.y,r.size.x,r.size.y]})
	func complex_view() -> void:
		resources()
		text("−1 / Малые вольеры",Vector2(58,151),18,MUTED)
		panel(Rect2(12,138,32,height-280),Color("17252b"),0)
		for x in [20,36]: draw_line(Vector2(x,138),Vector2(x,height-150),Color("6a7b7e"),2)
		for y in range(175,int(height-150),80): draw_line(Vector2(20,y),Vector2(36,y),Color("61777c"),2)
		room(Rect2(54,170,226,320),"Слизик",slime,true,"2 / 6 объектов")
		room(Rect2(294,170,226,320),"Рогач",horn,false,"3 / 10 объектов")
		text("−2 / Воздушный вольер",Vector2(58,540),18,MUTED)
		panel(Rect2(54,560,466,260),Color("1a242a"),4)
		draw_rect(Rect2(54,560,466,28),Color("344148"))
		for x in [110,210,310,410]:
			draw_line(Vector2(x,600),Vector2(x,790),LINE,2)
		draw_line(Vector2(54,820),Vector2(520,820),Color("566771"),10)
		center_text("?",Rect2(205,608,140,115),58,Color("63757c"))
		text("Неизученный обитатель",Vector2(98,752),22,MUTED)
		text("Обзор · локация готовится",Vector2(98,785),17,MUTED)
		if height>1000:
			text("−3 / Секретная камера",Vector2(58,870),18,MUTED)
			panel(Rect2(54,888,466,140),Color("172125"),4)
			for x in range(70,510,32): draw_line(Vector2(x,902),Vector2(x,1014),LINE,2)
			panel(Rect2(150,930,270,62),BG,6)
			text("Архив закрыт",Vector2(193,970),20,MUTED)
		nav(0)
	func puzzle_view() -> void:
		header("09 · Нестабильность","Tactical Evolution")
		var extra=height-960
		var goal_h=84.0 if extra<100 else 136.0
		button("goal_details","",Rect2(20,112,500,goal_h))
		text("○ Создать Слизика II",Vector2(38,143),20)
		text("0 / 1",Vector2(445,143),19,BIO)
		text("Ещё 2 цели · раскрыть ↓",Vector2(38,176),17,MUTED)
		if goal_h>100: text("Активировать генератор · 0 / 1",Vector2(38,216),18,MUTED)
		var y=124+goal_h
		var board=Rect2(20,y,500,600)
		var Preview=load("res://scripts/evolution_session.gd")
		session=Preview.new()
		session.start(JSON.parse_string(FileAccess.get_file_as_string("res://evolution/levels/level_09.json")))
		for index in range(30):
			var r=Rect2(20+index%5*100,y+floori(index/5.0)*100,100,100).grow(-4)
			if index in session.config.blocked_cells:
				panel(r,Color("141e22"),12,Color("1e2c31"))
				draw_line(r.get_center()-Vector2(7,7),r.get_center()+Vector2(7,7),Color("2b3b40"),2)
				continue
			panel(r,Color("26393b"),12)
			var object: Dictionary=session.object_at(index)
			if object.get("type")=="equipment": center_text("⚙",r,36,PORTAL)
			if object.get("type")=="anomaly":
				for j in range(5): draw_circle(r.get_center()+Vector2.from_angle(j*TAU/5)*15,17,Color("865b79"))
			if object.get("type")=="portal":
				for radius in [20,30]: draw_arc(r.get_center(),radius,0,TAU,48,PORTAL,3,true)
			if session.cells[index]!=null: art(slime,r.get_center(),86)
		for index in session.preview_actions(10):
			var r=Rect2(20+index%5*100,y+floori(index/5.0)*100,100,100).grow(-5)
			var action: Dictionary=session.preview_actions(10)[index]
			draw_rect(r,BIO,false,2)
			text("+" if action.kind=="merge" else "→",r.position+Vector2(7,23),20,BIO)
			text(str(action.cost),Vector2(r.end.x-22,r.position.y+23),18,BIO)
		var selected=Rect2(25,y+205,90,90)
		for d in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			var corner=selected.get_center()+d*45
			draw_line(corner,corner-Vector2(d.x*16,0),INK,4)
			draw_line(corner,corner-Vector2(0,d.y*16),INK,4)
		if extra>100:
			panel(Rect2(20,board.end.y+16,500,126))
			text("СЛИЗИК / I",Vector2(40,board.end.y+49),18,BIO)
			text("Проходит кислоту. Выберите клетку",Vector2(40,board.end.y+80),19)
			text("с обозначением действия и цены.",Vector2(40,board.end.y+108),19)
		var footer=height-152
		text("ХОДЫ   11",Vector2(22,footer+27),20,BIO)
		text("Выбран Слизик I",Vector2(270,footer+27),18,MUTED)
		button("undo","↶ Отменить · 2",Rect2(20,footer+40,244,84),true)
		button("restart","Заново",Rect2(276,footer+40,244,84))
		hitboxes.append({"id":"board","rect":[20,y,500,600],"non_button":true})
	func habitat_view(is_horn: bool) -> void:
		header("Рогач" if is_horn else "Слизик","Вольер · 3 / 10" if is_horn else "Вольер · 2 / 6")
		var bottom=height-304
		var room_rect=Rect2(16,124,508,bottom-136)
		panel(room_rect,Color("282c2c") if is_horn else Color("20362f"),20)
		# Temporary presentation arrangement, no change to the authoritative room model.
		var left=room_rect.position.x; var right=room_rect.end.x
		for x in [left+36,right-52]:
			draw_line(Vector2(x,154),Vector2(x,bottom-70),Color("4d5f5b"),14)
			draw_line(Vector2(x-3,154),Vector2(x-3,bottom-70),Color("81918a"),2)
		for y in range(182,int(bottom-60),90): draw_line(Vector2(left+12,y),Vector2(right-12,y),Color(1,1,1,.035),1)
		panel(Rect2(40,bottom-210,150,112),Color("363e39") if is_horn else Color("2a5441"),24)
		if is_horn:
			draw_colored_polygon(PackedVector2Array([Vector2(380,bottom-210),Vector2(450,bottom-190),Vector2(475,bottom-105),Vector2(360,bottom-105),Vector2(344,bottom-156)]),Color("65716b"))
			text("Тренировка",Vector2(352,bottom-26),16,MUTED)
		else:
			oval(Vector2(114,bottom-116),Vector2(68,22),Color("699c63"))
			oval(Vector2(114,bottom-122),Vector2(58,14),BIO)
			panel(Rect2(400,bottom-246,50,144),Color("304b3c"),12)
			for i in range(4): draw_circle(Vector2(425,bottom-225+i*29),5,BIO)
			text("Источник плазмы",Vector2(318,bottom-26),16,MUTED)
		for i in range(7):
			var x=52+i*68
			draw_line(Vector2(x,bottom-46),Vector2(x+12,bottom-12),Color("34463d"),2)
		art(horn if is_horn else slime,Vector2(274,bottom-146),172)
		button("find","◎ Найти",Rect2(324,140,184,84))
		# Existing room objects are rearranged only for composition study.
		var tank=Rect2(72,238,150,156)
		panel(tank,Color("4e5146") if is_horn else Color("315443"),12)
		for i in range(4):
			if is_horn:
				draw_line(Vector2(84,265+i*34),Vector2(208,265+i*34),Color("8e9685"),3)
			else:
				oval(Vector2(146,267+i*31),Vector2(56,9),Color("6b9e69"))
		text("Шкафы" if is_horn else "Резервуар",Vector2(72,420),16,MUTED)
		var plant=Vector2(423,room_rect.position.y+room_rect.size.y*.55)
		for i in range(5):
			var end=plant+Vector2(-36+i*17,-25-absf(i-2)*20)
			draw_line(plant,end,Color("789d78"),5)
			oval(end,Vector2(16,8),Color("719869"))
		panel(Rect2(plant-Vector2(25,3),Vector2(50,30)),Color("5d695c"),5)
		draw_line(Vector2(260,160),Vector2(260,205),LINE,5)
		panel(Rect2(209,200,102,18),Color("9aaf8d"),5)
		hitboxes.append({"id":"cabinets" if is_horn else "reservoir","rect":[tank.position.x,tank.position.y,tank.size.x,tank.size.y]})
		hitboxes.append({"id":"plants","rect":[plant.x-44,plant.y-65,88,100]})
		var y=bottom+4
		panel(Rect2(16,y,508,100))
		text("ОБЗОР КОМНАТЫ",Vector2(32,y+27),14,MUTED)
		var mini=Rect2(32,y+42,476,38)
		panel(mini,Color("121d21"),6)
		panel(Rect2(mini.position,Vector2(mini.size.x*(.38 if is_horn else .80),mini.size.y)),Color("536d5a"),6,BIO)
		hitboxes.append({"id":"zone_overview","rect":[16,y,508,100]})
		var sheet_y=height-172
		panel(Rect2(0,sheet_y-20,540,180),Color("1c282b"),24)
		draw_line(Vector2(244,sheet_y-8),Vector2(296,sheet_y-8),MUTED,4)
		text("Тренировочный камень" if is_horn else "Кислотная купель",Vector2(20,sheet_y+27),22)
		text("Предпросмотр · установка необязательна",Vector2(20,sheet_y+55),16,MUTED)
		button("install","Установить · ◈ "+("4" if is_horn else "3"),Rect2(20,sheet_y+64,324,84),true)
		button("cancel","Отмена",Rect2(356,sheet_y+64,164,84))
	func bestiary_view() -> void:
		header("Бестиарий","Исследовательский архив")
		button("search","⌕  Поиск по известным видам",Rect2(20,124,500,84))
		button("filter","Все  ↓",Rect2(20,220,164,84))
		text("Изучено 2 / 10 видов",Vector2(202,270),19,MUTED)
		for i in range(2):
			var r=Rect2(20+i*256,324,244,300)
			panel(r)
			art(slime if i==0 else horn,r.position+Vector2(122,100),150)
			text("Слизик" if i==0 else "Рогач",r.position+Vector2(20,197),23)
			text("Аморфный организм" if i==0 else "Минералофаг",r.position+Vector2(20,226),16,MUTED)
			track(Rect2(r.position+Vector2(20,247),Vector2(204,6)),.2)
			text("1 / 5 стадий",r.position+Vector2(20,282),16,BIO)
			hitboxes.append({"id":"dossier_"+str(i),"rect":[r.position.x,r.position.y,r.size.x,r.size.y]})
		var available=height-116-646
		panel(Rect2(20,640,500,minf(150,available-12)))
		draw_texture_rect(unknown,Rect2(36,652,88,88),false,Color(0,0,0,.8))
		text("?",Vector2(65,713),36,MUTED)
		text("Неизученные виды",Vector2(136,682),22)
		text("Имена и свойства скрыты",Vector2(136,713),17,MUTED)
		if height>1000:
			panel(Rect2(20,806,500,190))
			text("АРХИВ НАБЛЮДЕНИЙ",Vector2(40,843),17,BIO)
			text("Карточка вида откроет способности,",Vector2(40,879),19)
			text("пять стадий и научные заметки.",Vector2(40,908),19)
			text("Подробности — в прокручиваемом досье.",Vector2(40,957),17,MUTED)
		nav(2)
	func portal_view() -> void:
		header("Портальный зал","Экспедиции и эксперименты")
		var card_h=240
		var extension=height-960
		panel(Rect2(20,124,500,card_h),Color("252230"),22,Color("50435f"))
		text("ЭКСПЕДИЦИИ",Vector2(42,163),16,PORTAL)
		text("Лаборатория",Vector2(42,197),27)
		var r=Rect2(52,218,210,card_h-114)
		panel(r,Color("444137"),10)
		for i in range(4):
			var paper=Rect2(r.position+Vector2(16+(i%2)*90,16+floori(i/2.0)*64),Vector2(76,50))
			panel(paper,Color("a8b29c"),2)
			draw_line(paper.position+Vector2(9,13),paper.end-Vector2(9,20),Color("485d53"),2)
		text("Карта уровней",Vector2(286,238),21)
		text("Основная кампания",Vector2(286,264),16,MUTED)
		button("lab_map","Открыть →",Rect2(286,card_h+32,210,84),true)
		var y=140+card_h
		if extension>0:
			var world=Rect2(20,y,500,84+extension)
			panel(world,Color("252230"),20,Color("59486c"))
			for radius in [45,57,69]: draw_arc(Vector2(114,y+world.size.y*.5),radius,0,TAU,64,PORTAL,3,true)
			text("Другие миры →",Vector2(218,y+82),24)
			text("Токсичные болота",Vector2(218,y+126),20,PORTAL)
			text("Доступность по прогрессу",Vector2(218,y+160),16,MUTED)
			hitboxes.append({"id":"worlds","rect":[20,y,500,84+extension]})
		else: button("worlds","Другие миры  →",Rect2(20,y,500,84))
		y+=extension
		text("Порталы · прежние условия открытия",Vector2(24,y+115),16,MUTED)
		text("ЭКСПЕРИМЕНТАЛЬНЫЕ РЕЖИМЫ",Vector2(24,y+162),16,PORTAL)
		button("evolution","Tactical Evolution  ·  10",Rect2(20,y+181,500,84))
		button("legacy","Тактические испытания  ·  10",Rect2(20,y+277,500,84))
		button("sandbox","Песочница  →",Rect2(20,y+373,500,84))
		nav(1)
	func _draw() -> void:
		hitboxes.clear(); draw_rect(Rect2(0,0,540,height),BG)
		match page:
			"complex": complex_view()
			"puzzle": puzzle_view()
			"slime": habitat_view(false)
			"horn": habitat_view(true)
			"bestiary": bestiary_view()
			"portals": portal_view()
		# Explicit illustrative safe-area strips, not a claim about a particular device.
		draw_line(Vector2(0,0),Vector2(540,0),LINE,2)
		draw_line(Vector2(228,height-11),Vector2(312,height-11),MUTED,4)
var failures=0
var checks=0
func verify(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var report=[]
	for h in [960,1170]:
		root.size=Vector2i(540,h); root.content_scale_size=Vector2i(540,h)
		for page in ["complex","puzzle","slime","horn","bestiary","portals"]:
			var study=Study.new(); study.page=page; study.height=h; study.size=Vector2(540,h); root.add_child(study)
			await process_frame
			await RenderingServer.frame_post_draw
			var regions=study.hitboxes.duplicate(true)
			for region in regions:
				var rect=Rect2(region.rect[0],region.rect[1],region.rect[2],region.rect[3])
				verify(Rect2(0,24,540,h-48).encloses(rect),"safe bounds "+page+" "+region.id)
				if not region.get("non_button",false): verify(rect.size.x>=84 and rect.size.y>=84,"84-unit target "+page+" "+region.id)
			for a in range(regions.size()):
				for b in range(a+1,regions.size()):
					if regions[a].get("non_button",false) or regions[b].get("non_button",false): continue
					var first=regions[a].rect; var second=regions[b].rect
					verify(not Rect2(first[0],first[1],first[2],first[3]).intersects(Rect2(second[0],second[1],second[2],second[3])),"independent targets do not overlap "+page)
			verify(root.get_texture().get_image().save_png(OUT+page+"-"+str(h)+".png")==OK,"save "+page)
			report.append({"page":page,"width":540,"height":h,"safe_top":24,"safe_bottom":24,"hitboxes":regions})
			root.remove_child(study); study.free()
	var file=FileAccess.open(OUT+"regions.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"	")); file.close()
	print("Portrait composition checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
