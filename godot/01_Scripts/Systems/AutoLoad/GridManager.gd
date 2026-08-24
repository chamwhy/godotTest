# GridManager.gd
# AutoLoad
#
# ─── 역할 ────────────────────────────────────────────────────
# 격자 공간 데이터의 단일 소유자.
#   · tile_map / element_map (위치 인덱스)
#   · all_elements (존재 명단 = 레지스트리)
#   · 진입/통과/이탈/상호작용 처리 + 시그널
#   · 통행/배치 가능 판정
#
# element_map은 인덱스(캐시)일 뿐이다.
# 진실의 원천은 각 Element의 state(cur_position, in_map)이며,
# rebuild_element_map()으로 언제든 재구성 가능하다.
#
# 게임 규칙(HP, 감정, 스테이지 진행 등)은 모른다.
# ─────────────────────────────────────────────────────────────
extends Node

var tile_map: Array = []
var element_map: Array = []
var map_width: int
var map_height: int

# 씬에 존재하는 모든 Element 명단 (맵 소속 여부와 무관)
var all_elements: Array[Element] = []




# ─────────────────────────────────────────────
# 초기화
# ─────────────────────────────────────────────
func init(width: int, height: int) -> void:
	map_width = width
	map_height = height
	tile_map.resize(height)
	element_map.resize(height)
	all_elements.clear()

	for y in range(height):
		tile_map[y] = []
		element_map[y] = []
		for x in range(width):
			tile_map[y].append(0)
			element_map[y].append([])


func clear() -> void:
	map_width = 0
	map_height = 0
	tile_map = []
	element_map = []
	all_elements.clear()


# ─────────────────────────────────────────────
# 좌표/타일 검사
# ─────────────────────────────────────────────
func map_size_in(x: int, y: int) -> bool:
	return 0 <= x and x < map_width and 0 <= y and y < map_height


func has_tile(x: int, y: int) -> bool:
	if not map_size_in(x, y): return false
	return tile_map[y][x] != 0


func register_tile(pos: Position, tile_id: int) -> void:
	if not map_size_in(pos.x, pos.y): return
	tile_map[pos.y][pos.x] = tile_id


# ─────────────────────────────────────────────
# Element 등록/조회
# ─────────────────────────────────────────────

## map enter, pass, exit signal
signal element_entered(pos: Position, elm: Element, tick: int)
signal element_exited(pos: Position, elm: Element, tick: int)
signal element_settled(pos: Position, elm: Element, tick: int)
signal element_interacted(pos: Position, elm: Element, tick: int)


func register_element(pos: Position, elm: Element) -> void:
	if not map_size_in(pos.x, pos.y): return
	elm.cur_position = pos.copy()   # 참조 공유 방지
	elm.in_map = true
	if elm not in all_elements:
		all_elements.append(elm)
	var cell: Array = element_map[pos.y][pos.x]
	if elm not in cell:             # 중복 등록 방지
		cell.append(elm)


func unregister_from_registry(elm: Element) -> void:
	all_elements.erase(elm)


# element_map을 각 Element의 state로부터 재구성
func rebuild_element_map() -> void:
	for y in range(map_height):
		for x in range(map_width):
			element_map[y][x].clear()
	for elm in all_elements:
		if not is_instance_valid(elm): continue
		if not elm.in_map: continue
		element_map[elm.cur_position.y][elm.cur_position.x].append(elm)


# filter - 0: none, 1: hitable
func get_element(pos: Position, filter: int) -> Element:
	if not map_size_in(pos.x, pos.y): return null
	for i in range(element_map[pos.y][pos.x].size()):
		var re = element_map[pos.y][pos.x][i] as Element
		if not re: continue
		if filter == 1 and not re.hitable: continue
		return re
	return null


func get_elements(pos: Position) -> Array[Element]:
	if not map_size_in(pos.x, pos.y): return []
	var answer: Array[Element] = []
	for i in range(element_map[pos.y][pos.x].size()):
		var re = element_map[pos.y][pos.x][i] as Element
		if not re: continue
		answer.append(re)
	return answer


# ─────────────────────────────────────────────
# 진입 / 통과 / 이탈 / 상호작용
# ─────────────────────────────────────────────

func enter_element(elm: Element, pos: Position, tick: int) -> bool:
	if not map_size_in(pos.x, pos.y): return false
	register_element(pos, elm)
	# TODO: detail. 순간순간 emit 하지 말고, queue만들어 두고 ingame play 상황일때 
	# queue 소진하는 방식으로 하면 피격 효과를 시작할 때 줄 수 있어서 현장감 up.
	element_entered.emit(elm.cur_position, elm, tick)
	return true


## 점유 해제는 타일 유무와 무관하다. (구멍 위에 떠 있는 개체도 이탈 가능해야 함)
func exit_element(elm: Element, pos: Position, tick: int) -> Element:
	if not map_size_in(pos.x, pos.y): return null
	var cell: Array = element_map[pos.y][pos.x]
	var idx := cell.find(elm)
	if idx == -1: return null
	cell.remove_at(idx)
	elm.in_map = false
	element_exited.emit(pos, elm, tick)
	return elm

## 한 칸 전진. 이전 칸 이탈 + 새 칸 진입을 한 번에 처리한다.
## 이동 루프는 이 함수만 사용한다 → 어느 시점에도 element_map에서 누락되지 않음.
func step_element(elm: Element, to_pos: Position, tick: int) -> bool:
	if not map_size_in(to_pos.x, to_pos.y): return false
	if elm.in_map:
		exit_element(elm, elm.cur_position, tick)
	return enter_element(elm, to_pos, tick)

## 이동이 끝나 그 칸에 멈췄음을 알린다. 위치는 바꾸지 않는다.
## 쿠키/클리어처럼 "지나가는 건 안 되고 멈춰야 발동"하는 것들이 구독한다.
func settle_element(elm: Element, tick: int) -> bool:
	if not elm.in_map: return false
	element_settled.emit(elm.cur_position, elm, tick)
	return true

func interact_element(elm: Element, pos: Position, tick: int) -> bool:
	if not map_size_in(pos.x, pos.y): return false
	element_interacted.emit(pos, elm, tick)
	return true


# ─────────────────────────────────────────────
# 통행/배치 판정
# ─────────────────────────────────────────────
func can_pass(pos: Position) -> bool:
	return not _is_blocked(pos)


func can_placed(pos: Position) -> bool:
	if not has_tile(pos.x, pos.y): return false
	return not _is_blocked(pos)


func _is_blocked(pos: Position) -> bool:
	if not map_size_in(pos.x, pos.y): return true
	for i in element_map[pos.y][pos.x]:
		var el = i as Element
		if el and el.blocking():
			return true
	return false
