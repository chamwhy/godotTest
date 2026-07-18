extends Node

const MAX_HISTORY := 30


# ─────────────────────────────────────────────
# 한 턴의 기록
# ─────────────────────────────────────────────
class TurnRecord:
	var anim_batches: Array = []
	# { Element → state Dictionary }  ← 이게 전부. map 스냅샷 없음.
	var state_before: Dictionary = {}


var _history: Array[TurnRecord] = []


# ─────────────────────────────────────────────
# 스테이지 초기화 시 호출
# ─────────────────────────────────────────────
func clear_history() -> void:
	_history.clear()
	print("UndoManager: 히스토리 초기화")


# ─────────────────────────────────────────────
# ① 입력 직전: 모든 Element의 state만 저장
# ─────────────────────────────────────────────
func pre_action() -> TurnRecord:
	var record := TurnRecord.new()
	for elm in InGameManager.all_elements:
		if not is_instance_valid(elm): continue
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

	# ① undo 정보 수행 로직 (논리 복원)
	_restore_logic(record)

	# ② 되돌리기에 필요한 애니메이션을 "정방향 유닛"으로 큐에 등록
	_enqueue_undo_anims(record)

	# ③ 정방향과 동일한 파이프라인으로 재생
	await AnimationQueue.process_queue(true)

	# ④ 안전망: 애니메이션이 스킵됐어도 시각 상태를 논리 상태에 강제 동기화
	_sync_visuals(record)

	print("UndoManager: Undo 완료")


# ─────────────────────────────────────────────
# 정방향 로그의 undo_action들을 tick 역산해서 큐에 등록
#   정방향 tick i  →  undo tick (n-1-i)
#   같은 틱에 있던 유닛들은 undo에서도 같은 틱 = 병렬성 보존
# ─────────────────────────────────────────────
func _enqueue_undo_anims(record: TurnRecord) -> void:
	var n := record.anim_batches.size()
	for i in range(n):
		var undo_tick := n - 1 - i
		for unit in record.anim_batches[i]:
			if unit.undo_action == "": continue
			if not is_instance_valid(unit.target): continue
			if unit.target.is_queued_for_deletion(): continue

			AnimationQueue.add_anim_unit(AnimationQueue.AnimUnit.new(
				unit.target,
				unit.undo_action,   # undo 액션이 이번엔 "정방향 액션"이 됨
				unit.undo_data
			), undo_tick)


# ─────────────────────────────────────────────
# 최종 시각 동기화 (안전망)
# undo_action=="" 이라 애니메이션이 없던 요소도
# 논리 상태와 화면이 반드시 일치하도록 보정
# ─────────────────────────────────────────────
func _sync_visuals(record: TurnRecord) -> void:
	for elm in record.state_before:
		if not is_instance_valid(elm): continue
		var st: Dictionary = record.state_before[elm]
		elm.visible = st.get("visible", true)
		elm.modulate.a = 1.0
		elm.position = Position.position_to_world(elm.cur_position)
		elm.z_index = ZIndexer.calc(elm.cur_position.y, ZIndexer.ZID_ELEMENT)

# ─────────────────────────────────────────────
# 논리 복원: state 복원 → map은 state로부터 재구성
# ─────────────────────────────────────────────
func _restore_logic(record: TurnRecord) -> void:
	# ── 턴 도중 동적 생성된 Element 제거 ──
	# (턴 시작 시점 명단 = state_before의 key. 거기 없으면 이번 턴에 생긴 것)
	var to_remove: Array[Element] = []
	for elm in InGameManager.all_elements:
		if elm not in record.state_before:
			to_remove.append(elm)
	for elm in to_remove:
		InGameManager._registry_remove(elm)
		elm.queue_free()

	# ── 각 Element state 복원 ──
	for elm in record.state_before:
		if not is_instance_valid(elm): continue
		elm.apply_undo(record.state_before[elm])

	# ── element_map은 저장본이 아니라 "복원된 state"에서 재구성 ──
	InGameManager.rebuild_element_map()

#
#func undo() -> void:
	#if AnimationQueue.is_processing:
		#return
	#if _history.is_empty():
		#print("UndoManager: 되돌릴 기록이 없습니다.")
		#return
#
	#var record: TurnRecord = _history.pop_back()
	#print("UndoManager: Undo 실행 (남은 기록: %d개)" % _history.size())
#
	## 논리 상태 먼저 복원
	#_restore_logic(record)
#
	## 역산 애니메이션 재생
	#await AnimationQueue.process_undo_queue(record.anim_batches)
#
	#print("UndoManager: Undo 완료")
#
#
