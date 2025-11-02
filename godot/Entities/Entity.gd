# Entity.gd
extends Node2D
class_name Entity

## --- Private Variables ---
var cur_position: Position = Position.ZERO()  # 현재 위치


## --- Initialization ---
#func _ready():
	# 모든 엔티티는 준비될 때 씬 트리에 따라 자신의 격자 위치를 시각적 위치로 설정합니다.
	#update_visual_position()
