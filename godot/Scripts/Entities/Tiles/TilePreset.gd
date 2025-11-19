# TilePreset.gd (Resource 스크립트)
extends Resource
class_name TilePreset

# @export를 사용하여 에디터에서 값을 쉽게 편집할 수 있습니다.
@export var tile_name: String = ""
@export var sprite_path: String = "res://assets/sprites/default_tile.png"
@export var is_blocking: bool = false # 막힘 판정 여부 (벽)
@export var has_friction: bool = false # 마찰력 존재 여부
@export var is_deadly: bool = false # 죽음 판정 여부
@export var move_sound_path: String = "" # 사운드 리소스 주소
