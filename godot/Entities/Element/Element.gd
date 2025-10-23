# Element.gd
# 규칙에 의해 영향을 받고 상호작용하는 모든 개체의 기본 클래스
extends Entity
class_name Element


var is_block: bool = false  # 막힘 판정 여부

# 안정성을 위하여 노드 캐싱
@onready var $
