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


func queue_reset() -> void:
	print("AnimQ - 리셋")
	cur_tick = 0
	queue.resize(QUEUE_LIMIT)
	for i in range(QUEUE_LIMIT):
		queue[i] = []


func add_anim_unit(unit: AnimUnit, tick: int) -> bool:
	if tick >= start_tick + QUEUE_LIMIT:
		return false
	print("AnimQ - 유닛 추가 - ",
		unit.target.get_script().get_global_name(),
		" : ", tick, "틱(", tick - start_tick, "개)")
	queue[tick - start_tick].append(unit)
	return true


# ─────────────────────────────────────────────
# 정방향 큐 실행
# ─────────────────────────────────────────────
func process_queue() -> void:
	for i in range(QUEUE_LIMIT):
		if queue[i].size() > 0:
			print("    ", i, "틱 - ", queue[i].size(), "개")
	print("AnimQ - 프로세싱 시작")
	if is_processing or queue[cur_tick].is_empty():
		print("    ====> 실패")
		return
	
	is_processing = true

	_turn_log.clear()

	while not queue[cur_tick].is_empty():
		print("AnimQ: ", start_tick + cur_tick, "틱 - ", queue[cur_tick].size(), "개")
		var current_batch: Array = queue[cur_tick]

		# 이번 배치를 턴 로그에 기록
		_turn_log.append(current_batch.duplicate())

		var tweens: Array[Tween] = []

		for unit in current_batch:
			if is_instance_valid(unit.target) and unit.target.has_method("on_animate"):
				var tw = unit.target.on_animate(unit.action, unit.data)
				if tw is Tween:
					tweens.append(tw)

		for tw in tweens:
			await tw.finished

		await get_tree().process_frame
		cur_tick += 1

	queue_reset()
	is_processing = false
	print("AnimQ - 모든 큐 재생 완료")
	
	_flush_pending_map_change()   # ← 추가


# ─────────────────────────────────────────────
# 역방향 큐 실행 (UndoManager 전용)
# batches: [ [AnimUnit,...], ... ]  tick 오름차순 → 역순으로 처리
# ─────────────────────────────────────────────
func process_undo_queue(batches: Array) -> void:
	if is_processing:
		return
	if batches.is_empty():
		return

	is_processing = true
	
	
	print("Undo 애니메이션 역재생 시작")

	# tick 역순으로 배치를 순회
	for i in range(batches.size() - 1, -1, -1):
		var batch: Array = batches[i]
		var tweens: Array[Tween] = []
		print("UndoQ: ", i, "틱 - ", batch.size(), "개")
		for unit in batch:
			# undo_action 이 비어 있으면 역산 애니메이션 없음
			if unit.undo_action == "":
				continue
			if not is_instance_valid(unit.target):
				continue
			if not unit.target.has_method("on_animate"):
				continue

			var tw = unit.target.on_animate(unit.undo_action, unit.undo_data)
			if tw is Tween:
				tweens.append(tw)

		for tw in tweens:
			await tw.finished

		await get_tree().process_frame

	is_processing = false
	print("Undo 애니메이션 역재생 완료")




func _flush_pending_map_change() -> void:
	if InGameManager.has_pending_map_change():
		var mc = InGameManager.consume_map_change()
		print("AnimQ - 맵 전환 실행: ", mc.world, "-", mc.stage)
		MapDrawer.draw_map(mc.world, mc.stage)
		UndoManager.clear_history()
