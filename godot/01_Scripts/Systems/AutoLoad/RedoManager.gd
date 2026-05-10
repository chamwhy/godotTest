# RedoManager.gd
# AutoLoad
# 입력 직전 상태를 스냅샷으로 저장하고, "back" 입력 시 역방향 애니메이션과 함께 되돌립니다.
extends Node

# ─────────────────────────────────────────────
# 설정값
# ─────────────────────────────────────────────
const MAX_HISTORY := 30  # 최대 되돌리기 횟수

# ─────────────────────────────────────────────
# 내부 클래스: 단일 Element 의 스냅샷
# ─────────────────────────────────────────────
class ElementSnapshot:
	var element: Element        # 실제 노드 참조
	var position: Position      # 논리 위치
	var cur_hp: int             # 현재 HP (Unit 한정)
	var is_dead: bool           # 사망 여부
	var is_fallen: bool         # 추락 여부
	var is_alive: bool          # queue_free 됐는지 여부 (스냅샷 당시)

	func _init(elm: Element) -> void:
		element  = elm
		position = elm.cur_position.copy()
		is_alive = is_instance_valid(elm)

		# Unit 하위 클래스라면 HP·상태도 저장
		if elm is Unit:
			var u := elm as Unit
			cur_hp    = u.cur_hp
			is_dead   = u.is_dead
			is_fallen = u.is_fallen
		else:
			cur_hp    = 0
			is_dead   = false
			is_fallen = false


# ─────────────────────────────────────────────
# 내부 클래스: 한 턴 전체의 스냅샷
# ─────────────────────────────────────────────
class TurnSnapshot:
	# element → 스냅샷 사전
	var snapshots: Array[ElementSnapshot] = []
	# element_map 복사본 [y][x] = Array[Element]
	var element_map_copy: Array = []

	func _init(elements: Array, emap: Array) -> void:
		for elm in elements:
			if is_instance_valid(elm):
				snapshots.append(ElementSnapshot.new(elm))

		# element_map 을 깊은 복사 (참조 배열이므로 행·열 단위로 복사)
		element_map_copy.resize(emap.size())
		for y in range(emap.size()):
			element_map_copy[y] = []
			element_map_copy[y].resize(emap[y].size())
			for x in range(emap[y].size()):
				# 내부 배열의 얕은 복사만으로 충분
				# (Element 노드 자체는 불변 레퍼런스)
				element_map_copy[y][x] = emap[y][x].duplicate()


# ─────────────────────────────────────────────
# 스택
# ─────────────────────────────────────────────
var _history: Array[TurnSnapshot] = []


# ─────────────────────────────────────────────
# 외부 API
# ─────────────────────────────────────────────

## 입력 처리 직전에 호출 → 현재 상태를 스택에 쌓습니다.
func push_snapshot() -> void:
	if AnimationQueue.is_processing:
		return

	var all_elements: Array = _collect_all_elements()
	var snap := TurnSnapshot.new(all_elements, InGameManager.element_map)

	_history.push_back(snap)
	if _history.size() > MAX_HISTORY:
		_history.pop_front()

	print("RedoManager: 스냅샷 저장 (총 %d개)" % _history.size())


## "back" 입력 시 호출 → 한 턴 전 상태로 애니메이션과 함께 복원합니다.
func undo() -> void:
	if AnimationQueue.is_processing:
		return
	if _history.is_empty():
		print("RedoManager: 되돌릴 기록이 없습니다.")
		return

	var snap: TurnSnapshot = _history.pop_back()
	print("RedoManager: 되돌리기 실행 (남은 기록: %d개)" % _history.size())

	_restore_snapshot(snap)


## 히스토리 전체 초기화 (맵 이동·게임 오버 시 호출)
func clear_history() -> void:
	_history.clear()
	print("RedoManager: 히스토리 초기화")


# ─────────────────────────────────────────────
# 내부 복원 로직
# ─────────────────────────────────────────────

func _restore_snapshot(snap: TurnSnapshot) -> void:
	# 1) element_map 복원
	_restore_element_map(snap.element_map_copy)

	# 2) 각 Element 상태 복원 + 역방향 애니메이션 큐에 등록
	for es in snap.snapshots:
		if not is_instance_valid(es.element):
			continue

		var elm: Element = es.element
		var prev_pos: Position = es.position
		var cur_pos: Position  = elm.cur_position  # 현재(되돌리기 전) 위치

		# ── HP / 상태 복원 (Unit) ──────────────────
		if elm is Unit:
			var u := elm as Unit
			# HP 신호가 과도하게 발생하지 않도록 내부 변수 직접 세팅
			u._cur_hp    = es.cur_hp
			u.is_dead    = es.is_dead
			u.is_fallen  = es.is_fallen

		# ── 논리 위치 복원 ─────────────────────────
		elm.cur_position = prev_pos

		# ── 역방향 애니메이션 등록 ─────────────────
		# 현재 위치 → 이전 위치 로 역재생
		if not cur_pos.equals(prev_pos):
			var unit = AnimationQueue.AnimUnit.new(elm, "move_reverse", {
				"from": cur_pos,   # 역재생: 현재 위치에서
				"to":   prev_pos   # 이전 위치로
			})
			AnimationQueue.add_anim_unit(unit, 0)

	# 3) 애니메이션 큐 실행
	AnimationQueue.process_queue()


func _restore_element_map(map_copy: Array) -> void:
	# InGameManager 의 element_map 을 복원된 복사본으로 교체
	InGameManager.element_map.resize(map_copy.size())
	for y in range(map_copy.size()):
		InGameManager.element_map[y] = []
		InGameManager.element_map[y].resize(map_copy[y].size())
		for x in range(map_copy[y].size()):
			InGameManager.element_map[y][x] = map_copy[y][x].duplicate()


## 맵에 등록된 모든 Element 를 1차원 배열로 반환
func _collect_all_elements() -> Array:
	var result: Array = []
	for row in InGameManager.element_map:
		for cell in row:
			for elm in cell:
				if is_instance_valid(elm) and elm is Element:
					result.append(elm)
	return result
