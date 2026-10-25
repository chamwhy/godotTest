extends Node
# 엔진 재생 검증 — 시뮬레이터가 낸 최단 해답을 실제 엔진 턴으로 한 수씩 재생해
# 매 수 체력·위치가 시뮬레이터와 같은지, 마지막 수에 클리어되는지 확인한다.
# run.sh가 임시 프로젝트 사본에 오토로드로 넣는다. 게임 프로젝트에는 넣지 않는다.

var _fails := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _wait(n := 3) -> void:
	for i in n:
		await get_tree().process_frame

func _dir(k: String) -> Position:
	match k:
		"U": return Position.UP()
		"D": return Position.DOWN()
		"L": return Position.LEFT()
	return Position.RIGHT()

func _run() -> void:
	await _wait(30)
	GameManager.set_state(GameManager.GameState.PLAYING)
	var sol: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://replay_solutions.json"))
	var names := sol.keys()
	names.sort()
	for name in names:
		var w := int(name.substr(0, 2))
		var s := int(name.substr(3, 2))
		StageDirector.load_stage(w, s)
		await _wait(8)
		if TipContent.instance: TipContent.instance.close_all_tips()
		await _wait(3)
		var d: Dictionary = sol[name]
		var keys: String = d["keys"]
		var pad := int(StageDirector.mapData.padding)
		var bad := ""
		for i in keys.length():
			if StageDirector.mapData.world != w or StageDirector.mapData.stage != s:
				bad = "left stage early at move %d" % (i + 1)
				break
			await _wait(2)
			InputBuffer.push_action(_dir(keys[i]))
			await ActionManager.turn_finished
			await _wait(3)
			if i == keys.length() - 1:
				break
			var p := PlayerRegistry.get_player()
			var hp := int(d["hp"][i]); var pos: Array = d["pos"][i]
			var px: int = p.cur_position.x - pad; var py: int = p.cur_position.y - pad
			if p.cur_hp != hp or px != int(pos[0]) or py != int(pos[1]):
				bad = "move %d %s: engine hp %d at (%d,%d), sim hp %d at (%d,%d)" % [i + 1, keys[i], p.cur_hp, px, py, hp, pos[0], pos[1]]
				break
		var cleared := false
		if bad == "":
			for t in 120:
				if StageDirector.mapData.world == int(d["to"][0]) and StageDirector.mapData.stage == int(d["to"][1]):
					cleared = true
					break
				await get_tree().process_frame
		if bad == "" and cleared:
			print("REPLAY ok:   %s %d moves -> cleared to %d-%d" % [name, keys.length(), int(d["to"][0]), int(d["to"][1])])
		else:
			_fails += 1
			print("REPLAY FAIL: %s %s" % [name, bad if bad != "" else "no clear after last move (now %d-%d)" % [StageDirector.mapData.world, StageDirector.mapData.stage]])
	print("REPLAY SUMMARY: %d stages, %d failed" % [names.size(), _fails])
	get_tree().quit(1 if _fails > 0 else 0)
