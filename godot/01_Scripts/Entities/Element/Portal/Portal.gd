extends Element
class_name Portal

#region element 별 특성
#@export var is_block: bool = false  # 막힘 판정 여부
#@export var hitable: bool = true
var to_world := 0
var to_stage := 0
#endregion


func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	is_block = false
	hitable = false
	to_world = data.get("to_w", 0)
	to_stage = data.get("to_s", 0)
	
	_connect_check_pos()
	# TODO: 상태에 따른 이미지 업데이트

func _connect_check_pos():
	GridManager.element_settled.connect(_check_pos)


func _check_pos(pos: Position, elm: Element, tick: int) -> void:
	if not in_map: return   # 맵에서 빠진(해제 대기 중인) 개체는 반응하지 않는다
	# 포탈은 플레이어만 발동시킨다.
	# 예전엔 종류를 가리지 않아 상자가 목표 포탈에 멈춰도 클리어됐다.
	# 배치로 피해 왔지만 3월드의 고블린은 매 턴 저절로 움직이므로 피할 수 없다.
	if not (elm is Player): return
	if pos.equals(cur_position):
		print("portal 발동.", cur_position.to_str(), pos.to_str())
		move_map(tick)

func move_map(tick: int) -> void:
	StageContext.request_map_change(
		{
			"world": to_world,
			"stage": to_stage
		})
	ActionManager.record_new(self, tick,"move_map", {})
	


#region animation

func _register_animations() -> void:
	super._register_animations()          # 부모 것 먼저 등록
	_anim_handlers["move_map"] = _anim_move_map

func _anim_move_map(tween: Tween, data: Dictionary) -> void:
	tween.tween_interval(0.0)
	# 실제 동작이 아닌 액션적인 무빙만 보여주는 섹션. 말그대로 애니메이션

#endregion
