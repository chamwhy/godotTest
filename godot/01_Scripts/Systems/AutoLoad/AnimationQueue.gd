# AnimationQueue.gd
# AutoLoad
#
# ─── 역할 ────────────────────────────────────────────────────
# tick별 배치 애니메이션 재생. 그게 전부다.
# 게임 로직, 턴 로그, undo — 아무것도 모른다.
# ─────────────────────────────────────────────────────────────
extends Node

const QUEUE_LIMIT := 100

var _queue: Array = []
var _max_used_tick := -1
var is_playing := false


func _ready() -> void:
	_reset()


func _reset() -> void:
	_max_used_tick = -1
	_queue.resize(QUEUE_LIMIT)
	for i in range(QUEUE_LIMIT):
		_queue[i] = []


# ─────────────────────────────────────────────
# 등록
# ─────────────────────────────────────────────
func enqueue(target: Node2D, action: String, data: Dictionary, tick: int) -> bool:
	if tick < 0 or tick >= QUEUE_LIMIT:
		push_warning("AnimQ: tick 범위 초과 → %d" % tick)
		return false
	_queue[tick].append({ "target": target, "action": action, "data": data })
	_max_used_tick = max(_max_used_tick, tick)
	return true


# ─────────────────────────────────────────────
# 재생: 0틱부터 max_used_tick까지, 빈 틱은 건너뜀
# ─────────────────────────────────────────────
func play_all() -> void:
	if is_playing:
		return
	if _max_used_tick < 0:
		return

	is_playing = true

	var tick := 0
	while tick <= _max_used_tick:
		var batch: Array = _queue[tick]
		if batch.is_empty():
			tick += 1
			continue

		print("AnimQ: %d틱 - %d개" % [tick, batch.size()])
		var tweens: Array[Tween] = []

		for item in batch:
			var target = item.target
			if not is_instance_valid(target): continue
			if target.is_queued_for_deletion(): continue
			if not target.has_method("on_animate"): continue
			var tw = target.on_animate(item.action, item.data)
			if tw is Tween:
				tweens.append(tw)

		for tw in tweens:
			await tw.finished
		await get_tree().process_frame
		tick += 1

	_reset()
	is_playing = false
	print("AnimQ: 재생 완료")
