# MapData.gd
# 맵 JSON을 파싱한 결과를 담는 순수 데이터 객체.
# 로직 없음. MapLoader가 만들고, StageDirector/EntitySpawner가 읽는다.
class_name MapData
extends RefCounted

var world: int
var stage: int
var map_name: String

var tile_size_x: int
var tile_size_y: int
var padding: int
var map_width: int      # padding 포함된 최종 크기
var map_height: int
var zoom: float

var tile_rows: Array = []      # 원본 2차원 타일 배열 (padding 미포함 좌표계)
var entities: Array = []       # 엔티티 Dictionary 목록 (x/y는 padding 보정 완료)


func is_valid() -> bool:
	return map_width > 0 and map_height > 0
