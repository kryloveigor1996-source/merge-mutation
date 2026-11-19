extends RefCounted
## Same primitive campaign transfers; a long command pays for every visited cell.
static func apply(session,source: int,destination: int,commit: bool=true) -> Dictionary:
	if source<0 or destination<0 or source>=30 or destination>=30 or session.cells[source]==null: return {"ok":false,"reason":"Выберите мутанта и клетку"}
	if session.can_transfer(source,destination):
		return session.transfer(source,destination) if commit else {"ok":true,"cost":1}
	var dx=destination%5-source%5
	var dy=floori(destination/5.0)-floori(source/5.0)
	if dx!=0 and dy!=0 or source==destination: return {"ok":false,"reason":"Нужна свободная прямая траектория"}
	var distance=absi(dx)+absi(dy)
	if session.moves_left()>=0 and session.moves_left()<distance: return {"ok":false,"reason":"Не хватает ходов на весь путь"}
	var trial=session.fork()
	var previous=source
	var step=signi(dx) if dy==0 else signi(dy)*5
	for offset in range(1,distance+1):
		var index=source+step*offset
		if trial.status!="active" or trial.cells[index]!=null or not trial.transfer(previous,index).ok: return {"ok":false,"reason":"Путь перекрыт или уровень завершается раньше цели"}
		previous=index
	if commit:
		session.cells.assign(trial.cells)
		session.goals.produced=trial.goals.produced.duplicate(true)
		session.goals.merges=trial.goals.merges
		session.moves_used=trial.moves_used
		session.status=trial.status
		session.reason=trial.reason
	return {"ok":true,"kind":"move","source":source,"index":destination,"form":trial.cells[destination],"cost":distance}