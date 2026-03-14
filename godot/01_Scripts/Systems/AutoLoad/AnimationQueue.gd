extends Node

# 개별 애니메이션 단위
class AnimUnit:
	var target: Node2D
	var action: String
	var data: Dictionary
	
	func _init(_target: Node2D, _action: String, _data: Dictionary):
		self.target = _target
		self.action = _action
		self.data = _data

# 동시에 실행될 애니메이션들의 묶음 (Batch)
var queue: Array = [] 
const QUEUE_LIMIT = 100
var is_processing: bool = false

var start_tick := 0
var cur_tick := 0


var anim_data: Array = []

func _ready() -> void:
	queue_reset()


func queue_reset():
	queue.resize(QUEUE_LIMIT)
	for i in range(QUEUE_LIMIT):
		queue[i] = [] # 각 칸을 빈 배열로 초기화

## 1. 새로운 애니메이션 스텝(Batch) 추가
# 이 함수를 호출할 때마다 "동시 재생될 그룹"이 하나 생성됩니다.
func add_anim_unit(unit: AnimUnit, tick: int) -> bool:
	if tick >= start_tick + QUEUE_LIMIT:
		return false
	queue[tick - start_tick].append(unit)
	return true

## 2. 큐 실행 및 모든 완료 대기 (await 가능)
func process_queue():
	if is_processing or queue[cur_tick].is_empty():
		return
	
	is_processing = true
	
	while not queue[cur_tick].is_empty():
		var current_batch = queue[cur_tick] # 이번 스텝에 실행할 리스트
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
		
		cur_tick += 1
	start_tick = cur_tick
	queue_reset()
	is_processing = false
	print("모든 큐 재생 완료")
