# AnimationQueue.gd
extends Node

# ─────────────────────────────────────────────
# AnimUnit: 개별 애니메이션 단위
# ─────────────────────────────────────────────
class AnimUnit:
	var target: Node2D
	var action: String
	var data: Dictionary

	# Undo 시 재생할 역산 정보
	# undo_action == "" 이면 역산 애니메이션 없음 (피격 이펙트 등)
	var undo_action: String
	var undo_data: Dictionary

	func _init(
		_target: Node2D,
		_action: String,
		_data: Dictionary,
		_undo_action: String = "",
		_undo_data: Dictionary = {}
	) -> void:
		target      = _target
		action      = _action
		data        = _data
		undo_action = _undo_action
		undo_data   = _undo_data


# ─────────────────────────────────────────────
# 큐
# ─────────────────────────────────────────────
var queue: Array = []
const QUEUE_LIMIT = 100
var is_processing: bool = false

var start_tick := 0
var cur_tick   := 0


# ─────────────────────────────────────────────
# 턴 로그 (UndoManager가 읽어감)
# 한 턴에 실행된 AnimUnit 배치 목록을 tick 순서대로 보관
# 구조: [ [AnimUnit, ...], [AnimUnit, ...], ... ]  (tick 오름차순)
# ─────────────────────────────────────────────
var _turn_log: Array = []

func get_and_clear_turn_log() -> Array:
	var log = _turn_log.duplicate()
	_turn_log.clear()
	return log


func _ready() -> void:
	queue_reset()

# AnimationQueue.gd
var max_used_tick := -1   # ← 추가: 실제로 사용된 최대 틱


func queue_reset() -> void:
	print("AnimQ - 리셋")
	cur_tick = 0
	max_used_tick = -1
	queue.resize(QUEUE_LIMIT)
	for i in range(QUEUE_LIMIT):
		queue[i] = []


func add_anim_unit(unit: AnimUnit, tick: int) -> bool:
	if tick >= start_tick + QUEUE_LIMIT:
		return false
	queue[tick - start_tick].append(unit)
	max_used_tick = max(max_used_tick, tick - start_tick)  # ← 추가
	return true


# ─────────────────────────────────────────────
# 통합 큐 실행 (정방향 / Undo 공용)
#   is_undo == true 이면:
#     · 턴 로그를 기록하지 않음 (undo가 또 undo되면 안 되니까)
#     · 맵 전환 flush를 하지 않음
# ─────────────────────────────────────────────
func process_queue(is_undo := false) -> void:
	if is_processing or max_used_tick < 0:
		return

	is_processing = true
	if not is_undo:
		_turn_log.clear()

	while cur_tick <= max_used_tick:
		var batch: Array = queue[cur_tick]

		# 빈 틱은 건너뜀 (undo 역산 시 gap 발생 가능)
		if batch.is_empty():
			cur_tick += 1
			continue

		print("AnimQ%s: %d틱 - %d개" % [" (undo)" if is_undo else "", cur_tick, batch.size()])

		if not is_undo:
			_turn_log.append(batch.duplicate())

		var tweens: Array[Tween] = []
		for unit in batch:
			if not is_instance_valid(unit.target): continue
			if unit.target.is_queued_for_deletion(): continue
			if not unit.target.has_method("on_animate"): continue
			var tw = unit.target.on_animate(unit.action, unit.data)
			if tw is Tween:
				tweens.append(tw)

		for tw in tweens:
			await tw.finished
		await get_tree().process_frame
		cur_tick += 1

	queue_reset()
	is_processing = false

	if not is_undo:
		InGameManager.flush_pending_map_change()
