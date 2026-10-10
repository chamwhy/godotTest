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

		var pending := [0]
		for tw in tweens:
			if not tw.is_valid():
				continue
			pending[0] += 1
			tw.finished.connect(func(): pending[0] -= 1, CONNECT_ONE_SHOT)
		
		while pending[0] > 0:
			await get_tree().process_frame
			# 안전밸브.
			# 트윈의 소유 노드가 해제되면 트윈도 kill되고 finished가 영원히 오지
			# 않는다. 그러면 pending이 0이 되지 못해 이 루프에서 못 빠져나오고,
			# is_playing이 true로 굳어 게임 전체가 입력을 받지 않는다.
			# (애니메이션 재생 중 리셋·홈을 누르면 닿는 경로다)
			#
			# is_running()이 아니라 is_valid()로 판정한다.
			# 설정창은 get_tree().paused = true로 트리를 멈추는데, 멈춘 트윈은
			# 'running이 아니지만 valid'다. is_running()을 보면 메뉴를 여는
			# 순간 연출을 끊어버려 논리와 화면이 어긋난다.
			if not _any_tween_alive(tweens):
				print("AnimQ: 트윈 소유 노드가 모두 해제됨 → %d틱 대기 중단" % tick)
				break
		
		await get_tree().process_frame
		tick += 1

	_reset()
	is_playing = false
	print("AnimQ: 재생 완료")


## 아직 살아 있는(= 씬 트리에 속한) 트윈이 하나라도 있는가.
## 정상 종료한 트윈도 invalid가 되므로, 전부 invalid라는 것은
## "모두 끝났거나 모두 kill됐다" 즉 더 기다릴 이유가 없다는 뜻이다.
func _any_tween_alive(tweens: Array[Tween]) -> bool:
	for tw in tweens:
		if tw.is_valid():
			return true
	return false
