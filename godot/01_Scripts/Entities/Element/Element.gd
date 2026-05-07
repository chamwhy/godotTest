# Element.gd
# 규칙에 의해 영향을 받고 상호작용하는 모든 개체의 기본 클래스
extends Entity
class_name Element

#region element 별 특성
@export var is_block: bool = false  # 막힘 판정 여부
@export var hitable: bool = true

#endregion


func on_hit(atk_data: AtkData) -> bool:
	return false



func apply_data(data: Dictionary):
	super.apply_data(data)
	_set_z_index(SortLayer.Element)
	print("apply data")
	InGameManager.register_element(cur_position, self)
