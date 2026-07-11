# Tile.gd
# 움직이거나 규칙에 영향을 받지 않는 고정된 배경 요소 (선택 사항)
extends Entity
class_name Tile

const ShowRatio := 0.5

@export var dust: Sprite2D
@export var up_left: Sprite2D
@export var up_right: Sprite2D
@export var down_left: Sprite2D
@export var down_right: Sprite2D

@export var dust_texture: Array[Texture2D]
@export var up_left_texture: Array[Texture2D]
@export var up_right_texture: Array[Texture2D]
@export var down_left_texture: Array[Texture2D]
@export var down_right_texture: Array[Texture2D]

var tile_id: int	# 해당 타일 id
var preset: TilePreset  # 해당 타일 프리셋
var surround: Array

func set_surround(tile_data: Array) -> void:
	surround = tile_data
	update_tile_sprites()
	set_random_dust()
	
func update_tile_sprites() -> void:
	# 배치 규칙.
	# 시계방향 기준으로 오름차순 순서. 
	# 세자리 이진배열로 진행.
	# 예) 좌상: 시계방향으로 유무 판단 = 왼쪽 -> 왼쪽상단 -> 상단 으로 판단.
	# 따라서 [상][좌상][좌] -> 010 이진 코드 -> 10진수로 변환으로 해서 순서 정하기
	
	# 좌상
	var ul_index = \
		surround[0][1] * 4 + \
		surround[0][0] * 2 + \
		surround[1][0]
	up_left.texture = up_left_texture[ul_index]
	
	# 우상
	var ur_index = \
		surround[1][2] * 4 + \
		surround[0][2] * 2 + \
		surround[0][1]
	up_right.texture = up_right_texture[ur_index]
	
	# 좌하
	var dl_index = \
		surround[1][0] * 4 + \
		surround[2][0] * 2 + \
		surround[2][1]
	down_left.texture = down_left_texture[dl_index]
	
	# 우하
	var dr_index = \
		surround[2][1] * 4 + \
		surround[2][2] * 2 + \
		surround[1][2]
	down_right.texture = down_right_texture[dr_index]
	
func set_random_dust() -> void:
	if randf() < ShowRatio:
		var random_texture: Texture2D = dust_texture[randi() % dust_texture.size()]
		dust.texture = random_texture

func apply_data(data: Dictionary):
	super.apply_data(data)
	z_index = ZIndexer.calc(cur_position.y, ZIndexer.ZID_TILE)
	tile_id = data.get("id", 1)	# tile id는 기본이 1, 0은 없음을 나타냄.
	InGameManager.register_tile(cur_position, tile_id)
	# TODO: id에 따라 preset 가져오기 + preset에 따라 타일 리셋
	
