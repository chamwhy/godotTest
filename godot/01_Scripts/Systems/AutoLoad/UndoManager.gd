# UndoManager.gd
# AutoLoad
#
# ─── 역할 ────────────────────────────────────────────────────
# 턴 히스토리 저장/꺼내기 + state 복원 + 시각 동기화.
# 파이프라인 진행은 ActionManager가 담당한다.
#
# ─── Element 확장 계약 ───────────────────────────────────────
#   save_undo_state() -> Dictionary : super 결과에 자기 필드 merge
#   apply_undo(state) -> void       : super 먼저 호출 후 추가 처리
# ─────────────────────────────────────────────────────────────
extends Node

const MAX_HISTORY := 30


class TurnRecord:
	# { Element → state Dictionary } — undo의 진실의 원천
	var state_before: Dictionary = {}
	# 이번 턴의 ActionUnit 목록 — undo 애니메이션 연출용
	var actions: Array = []


var _history: Array[TurnRecord] = []


func clear_history() -> void:
	_history.clear()
	print("UndoManager: 히스토리 초기화")


# ─────────────────────────────────────────────
# 턴 시작: 모든 Element의 state 스냅샷
# ─────────────────────────────────────────────
func pre_action() -> TurnRecord:
	var record := TurnRecord.new()
	for elm in GridManager.all_elements:
		if not is_instance_valid(elm): continue
		record.state_before[elm] = elm.save_undo_state()
	return record


# ─────────────────────────────────────────────
# 턴 종료: 히스토리 적재
# ─────────────────────────────────────────────
func commit_turn(record: TurnRecord) -> void:
	if record.actions.is_empty():
		print("UndoManager: 액션 없음, 저장 건너뜀")
		return
	_history.push_back(record)
	if _history.size() > MAX_HISTORY:
		_history.pop_front()
	print("UndoManager: 턴 기록 완료 (총 %d개)" % _history.size())


func pop_record() -> TurnRecord:
	if _history.is_empty():
		return null
	return _history.pop_back()


# ─────────────────────────────────────────────
# 논리 복원: state 복원 → element_map 재구성
# ─────────────────────────────────────────────
func restore_states(record: TurnRecord) -> void:
	# 턴 도중 동적 생성된 Element 제거 (턴 시작 명단에 없는 것)
	var to_remove: Array[Element] = []
	for elm in InGameManager.all_elements:
		if elm not in record.state_before:
			to_remove.append(elm)
	for elm in to_remove:
		GridManager.unregister_from_registry(elm)
		elm.queue_free()

	# 각 Element state 복원
	for elm in record.state_before:
		if not is_instance_valid(elm): continue
		elm.apply_undo(record.state_before[elm])

	# element_map은 복원된 state로부터 재구성
	GridManager.rebuild_element_map()


# ─────────────────────────────────────────────
# 시각 동기화 안전망
# ─────────────────────────────────────────────
func sync_visuals(record: TurnRecord) -> void:
	for elm in record.state_before:
		if not is_instance_valid(elm): continue
		var st: Dictionary = record.state_before[elm]
		elm.visible = st.get("visible", true)
		elm.modulate.a = 1.0
		elm.position = Position.position_to_world(elm.cur_position)
		elm.z_index = ZIndexer.calc(elm.cur_position.y, ZIndexer.ZID_ELEMENT)
