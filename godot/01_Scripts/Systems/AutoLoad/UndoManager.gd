# UndoManager.gd
# AutoLoad
#
# ─── 동작 원리 ───────────────────────────────────────────────
# [입력]
#   ① pre_action()          : element_map 구조 + 각 Element 상태 스냅샷
#   ② action_dir()          : 게임 로직 실행 (AnimUnit 등록)
#   ③ await process_queue() : 정방향 애니메이션 재생 + 턴 로그 기록
#   ④ commit_turn()         : 로그를 히스토리에 적재
#
# [back 입력]
#   ① _restore_logic()      : element_map + 각 Element 상태 복원
#   ② process_undo_queue()  : tick 역순으로 undo_action 애니메이션 재생
#
# ─── Element 확장 계약 ───────────────────────────────────────
# 각 서브클래스는 아래 두 메서드를 override한다.
#
#   func save_undo_state() -> Dictionary
#       super 결과에 자신의 필드를 merge해서 반환
#
#   func apply_undo(state: Dictionary) -> void
#       super.apply_undo(state) 먼저 호출 후 추가 처리
#
# ─── AnimUnit undo 계약 ──────────────────────────────────────
#   undo_action == ""  → Undo 시 역산 애니메이션 없음
#   undo_action 있음   → on_animate(undo_action, undo_data) 호출
#
# ─── 소멸 처리 ───────────────────────────────────────────────
#   스테이지 원래 Element : hide_for_undo() → Undo 시 show() + apply_undo()
#   동적 생성 Element     : Undo 시 queue_free() (스냅샷에 없으므로)
# ─────────────────────────────────────────────────────────────

extends Node

const MAX_HISTORY := 30


# ─────────────────────────────────────────────
# 한 턴의 기록
# ─────────────────────────────────────────────
class TurnRecord:
	# AnimationQueue가 실행한 배치 목록 (tick 오름차순)
	# [ [AnimUnit, ...], [AnimUnit, ...], ... ]
	var anim_batches: Array = []

	# 턴 시작 시점의 element_map 구조 스냅샷 (위치별 순서 보존)
	# [y][x] = Array[Element]
	var element_map_snapshot: Array = []

	# 각 Element의 논리 상태 스냅샷
	# { Element → Dictionary }
	var state_before: Dictionary = {}


var _history: Array[TurnRecord] = []


# ─────────────────────────────────────────────
# 스테이지 초기화 시 호출
# ─────────────────────────────────────────────
func clear_history() -> void:
	_history.clear()
	print("UndoManager: 히스토리 초기화")


# ─────────────────────────────────────────────
# ① 입력 직전 호출 → 스냅샷 준비
# ─────────────────────────────────────────────
func pre_action() -> TurnRecord:
	var record := TurnRecord.new()

	# element_map 구조를 그대로 복사 (위치별 순서 보존)
	record.element_map_snapshot.resize(InGameManager.map_height)
	for y in range(InGameManager.map_height):
		record.element_map_snapshot[y] = []
		for x in range(InGameManager.map_width):
			# 내부 배열 shallow copy → Element 레퍼런스와 순서 보존
			record.element_map_snapshot[y].append(
				InGameManager.element_map[y][x].duplicate()
			)

	# 스냅샷에 담긴 Element들의 상태 저장
	for y in range(InGameManager.map_height):
		for x in range(InGameManager.map_width):
			for elm: Element in record.element_map_snapshot[y][x]:
				if elm.has_method("save_undo_state"):
					record.state_before[elm] = elm.save_undo_state()

	return record


# ─────────────────────────────────────────────
# ④ process_queue() 완료 후 호출 → 히스토리 적재
# ─────────────────────────────────────────────
func commit_turn(record: TurnRecord) -> void:
	record.anim_batches = AnimationQueue.get_and_clear_turn_log()

	if record.anim_batches.is_empty():
		print("UndoManager: 애니메이션 없음, 히스토리 저장 건너뜀")
		return

	_history.push_back(record)
	if _history.size() > MAX_HISTORY:
		_history.pop_front()

	print("UndoManager: 턴 기록 완료 (총 %d개)" % _history.size())


# ─────────────────────────────────────────────
# Undo 실행
# ─────────────────────────────────────────────
func undo() -> void:
	if AnimationQueue.is_processing:
		return
	if _history.is_empty():
		print("UndoManager: 되돌릴 기록이 없습니다.")
		return

	var record: TurnRecord = _history.pop_back()
	print("UndoManager: Undo 실행 (남은 기록: %d개)" % _history.size())

	# 논리 상태 먼저 복원
	_restore_logic(record)

	# 역산 애니메이션 재생
	await AnimationQueue.process_undo_queue(record.anim_batches)

	print("UndoManager: Undo 완료")


# ─────────────────────────────────────────────
# 논리 상태 복원
# ─────────────────────────────────────────────
func _restore_logic(record: TurnRecord) -> void:
	# ── 동적 생성 Element 제거 ──────────────────────────────
	# 현재 element_map을 순회해서 스냅샷에 없는 Element는 실제 제거
	for y in range(InGameManager.map_height):
		for x in range(InGameManager.map_width):
			for elm: Element in InGameManager.element_map[y][x]:
				if elm not in record.state_before:
					elm.queue_free()

	# ── element_map을 스냅샷으로 복원 (위치·순서 완전 복원) ──
	for y in range(InGameManager.map_height):
		for x in range(InGameManager.map_width):
			InGameManager.element_map[y][x] = \
				record.element_map_snapshot[y][x].duplicate()

	# ── 각 Element 논리 상태 복원 ───────────────────────────
	for elm: Element in record.state_before:
		if not is_instance_valid(elm):
			continue
		elm.apply_undo(record.state_before[elm])
