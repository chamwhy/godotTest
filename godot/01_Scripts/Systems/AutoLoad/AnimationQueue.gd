extends Node

# 개별 애니메이션 단위
class AnimUnit:
	var target: Node2D
	var action: String
	var data: Dictionary
	
	func _init(_target, _action, _data):
		self.target = _target
		self.action = _action
		self.data = _data

# 동시에 실행될 애니메이션들의 묶음 (Batch)
var queue: Array[Array] = [] 
const QUEUE_LIMIT = 100
var is_processing: bool = false

## 1. 새로운 애니메이션 스텝(Batch) 추가
# 이 함수를 호출할 때마다 "동시 재생될 그룹"이 하나 생성됩니다.
func add_batch(tasks: Array[AnimUnit]) -> bool:
	if queue.size() >= QUEUE_LIMIT:
		return false
	queue.append(tasks)
	return true

## 2. 큐 실행 및 모든 완료 대기 (await 가능)
func process_queue():
	if is_processing or queue.is_empty():
		return
	
	is_processing = true
	
	while not queue.is_empty():
		var current_batch = queue.pop_front() # 이번 스텝에 실행할 리스트
		var tweens: Array[Signal] = []
		
		# 이번 배치에 있는 모든 애니메이션을 '동시에' 실행
		for unit in current_batch:
			if is_instance_valid(unit.target) and unit.target.has_method("on_animate"):
				# on_animate는 애니메이션이 끝날 때 신호(Signal)나 await를 반환해야 함
				var task_finished = unit.target.on_animate(unit.action, unit.data)
				if task_finished is Signal:
					tweens.append(task_finished)
		
		# 이번 배치의 모든 애니메이션이 끝날 때까지 대기
		for finished_signal in tweens:
			await finished_signal
			
		# 딜레이가 다른 경우를 대비해, 가장 긴 애니메이션이 끝날 때까지 
		# 혹은 추가적인 안전 딜레이를 넣고 싶다면 여기에 추가 가능
		await get_tree().process_frame 

	is_processing = false
	print("모든 큐 재생 완료")
