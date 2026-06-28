# AutoLoad - IngameManager.gd
extends Node

const MOVE_DELAY := 0.8

#region player
var _player: Player = null

# 플레이어가 없을 때 들어온 요청들을 저장할 배열 (함수 담기)
var _pending_callbacks: Array[Callable] = []

# 외부에서 "플레이어 생기면 이 함수 실행해줘"라고 요청할 때 쓰는 함수
func run_when_player_ready(callback: Callable):
	if _player:
		# 이미 플레이어가 있다면 즉시 실행
		print("이미 있")
		callback.call(_player)
	else:
		# 아직 없다면 대기열에 추가
		_pending_callbacks.append(callback)

signal player_registered(player: Player)

# 플레이어가 생성된 직후 매니저에게 자신을 등록할 때 호출
func register_player(player_node: Player):
	_player = player_node
	print("플레이어 등록")
	# 대기 중이던 모든 함수 실행
	for callback in _pending_callbacks:
		print("callback")
		callback.call(_player)
	
	# 실행 완료 후 대기열 비우기
	_pending_callbacks.clear()
	player_registered.emit(player_node)
#endregion

func _ready() -> void:
	InputManager.action_input.connect(_action_inputed)
	InputManager.back_input.connect(_back_inputed)   # ← 추가
	
func _action_inputed(dir: Position) -> void:
	print("실행 check: \n	aq ispocessing = ", AnimationQueue.is_processing, \
		"\n    player = ", _player, \
		"\n    죽음? = ", _player.is_dead, \
		"\n    떨어짐? = ", _player.is_fallen)
	if AnimationQueue.is_processing or _player == null: return
	if _player.is_dead or _player.is_fallen: return
 
	# ① 입력 직전 상태 스냅샷 준비
	var record = UndoManager.pre_action()
 
	# ② 게임 로직 실행 (AnimUnit 들이 AnimationQueue 에 등록됨)
	_player.action_dir(dir, 0)
 
	# ③ 애니메이션 재생 — await 로 완료까지 대기
	await AnimationQueue.process_queue()
 
	# ④ 완료 후 턴 로그를 히스토리에 적재
	UndoManager.commit_turn(record)

func _back_inputed() -> void:
	if AnimationQueue.is_processing or _player == null: return
	await UndoManager.undo()

#region Map
#region Mapping
var tile_map: Array = []
var element_map: Array = []
var map_width: int
var map_height: int

func init(width, height):
	map_width = width
	map_height = height
	tile_map.resize(height)
	element_map.resize(height)
	
	for y in range(height):
		tile_map[y] = []
		element_map[y] = []
		for x in range(width):
			tile_map[y].append(0)
			element_map[y].append([])


func clear():
	map_width = 0
	map_height = 0
	tile_map = []
	element_map = []

# 큐가 끝난 뒤 처리할 맵 전환 예약 (비어있으면 없음)
var _pending_map_change: Dictionary = {}

func request_map_change(world: int, stage: int) -> void:
	_pending_map_change = {"world": world, "stage": stage}

func has_pending_map_change() -> bool:
	return not _pending_map_change.is_empty()

func consume_map_change() -> Dictionary:
	var mc = _pending_map_change
	_pending_map_change = {}
	return mc
	

func map_size_in(x:int, y:int) -> bool:
	return 0 <= x and x < map_width and 0 <= y and y < map_height

func has_tile(x:int, y:int) -> bool:
	if not map_size_in(x, y): return false
	return tile_map[y][x] != 0

func register_tile(pos: Position, tile_id: int) -> void:
	if not map_size_in(pos.x, pos.y): return
	tile_map[pos.y][pos.x] = tile_id
	
func register_element(pos: Position, elm: Element) -> void:
	if not map_size_in(pos.x, pos.y): return
	elm.cur_position = pos
	if element_map[pos.y][pos.x] == null:
		element_map[pos.y][pos.x] = [elm]
	else:
		element_map[pos.y][pos.x].append(elm)

# filter - 0: none, 1: hitable
# TODO: 이거 솔직히 filter 무시해도 됨.
# 로직 자체가 거기에 존재하는 object 전부 때리는 판정이라 어차피 다 가져와야 함.
func get_element(pos: Position, filter: int) -> Element:
	if not has_tile(pos.x, pos.y): return null
	if element_map[pos.y][pos.x] == null: return null
	
	for i in range(element_map[pos.y][pos.x].size()):
		var re = element_map[pos.y][pos.x][i] as Element
		if not re: continue
		if filter == 1:
			if not re.hitable: continue
		return re
	return null

func get_elements(pos: Position) -> Array[Element]:
	if not has_tile(pos.x, pos.y): return []
	if element_map[pos.y][pos.x] == null: return []
	
	var answer: Array[Element] = []
	for i in range(element_map[pos.y][pos.x].size()):
		var re = element_map[pos.y][pos.x][i] as Element
		if not re: continue
		answer.append(re)
	return answer


## map enter, pass, exit signal
signal element_entered(pos: Position, elm: Element, tick: int)
signal element_passed(pos: Position, elm: Element, tick: int)
signal element_exited(pos: Position, elm: Element, tick: int)
signal element_interacted(pos: Position, elm: Element, tick: int)

# Element 넣기(register는 등록만, 해당 함수는 외부 처리까지 동시에 진행)
func enter_element(elm: Element, pos: Position, tick: int) -> bool:
	if not map_size_in(pos.x, pos.y): return false
	
	register_element(pos, elm)
	element_entered.emit(pos, elm, tick)
	
	return true


func pass_element(elm: Element, pos: Position, tick: int) -> bool:
	if not map_size_in(pos.x, pos.y): return false
	elm.cur_position = pos
	element_passed.emit(pos, elm, tick)
	
	return true

# 일치하는 Element 꺼내기
func exit_element(elm: Element, pos: Position, tick: int) -> Element:
	if not has_tile(pos.x, pos.y): return null
	if element_map[pos.y][pos.x] == null: return null
	for i in range(element_map[pos.y][pos.x].size()):
		var re = element_map[pos.y][pos.x][i]
		if not re is Element: continue
		if re != elm: continue
		element_map[pos.y][pos.x].remove_at(i)
		element_exited.emit(pos, elm, tick)
		return re
	return null

func interact_element(elm: Element, pos: Position, tick: int) -> bool:
	if not map_size_in(pos.x, pos.y): return false
	element_interacted.emit(pos, elm, tick)
	return true


#endregion


var world := 0
var stage := 0
var map_name := ""


func complete_stage():
	StageManager.clear_stage(world, stage)

# 지나갈 수 있는 지 여부
func can_pass(pos: Position) -> bool:
	return is_blocked(pos)

# 놓일 수 있는 지 여부
func can_placed(pos: Position) -> bool:
	if not has_tile(pos.x, pos.y): return false
	return is_blocked(pos)
	

func is_blocked(pos: Position) -> bool:
	if not map_size_in(pos.x, pos.y): return false
	for i in element_map[pos.y][pos.x]:
		var el = i as Element
		if el:
			if el.is_block:
				return false
		else:
			continue
	return true

#endregion

#region MapPosition
#func position_to_world(pos: Position) -> Vector2:
	## TODO: 나중에 카메라 관련 기획짜서 고치기?
	#return Position.to_vector2f(pos.x + 0.5, pos.y + 0.5) * MapDrawer.tile_size

#endregion
