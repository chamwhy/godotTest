# AutoLoad - Config.gd
extends Node

# === 게임 전역 상수 ===
const START_MAP_ID := 1			# 시작 맵 id
const DEFALT_UNIT_MAX_HP := 1	# 유닛 기본 최대체력

# 1. 원본 리소스 로드
# preload가 아니라 load다. preload는 이 스크립트를 "컴파일할 때" 리소스를 읽는데,
# 그 안의 엔티티 씬 스크립트들(Unit, WorldPortal → StageDirector → EntitySpawner)이
# 다시 Config를 참조한다. Config는 가장 먼저 컴파일되는 오토로드라 아직 반쯤 만들어진
# 상태이고, 내보낸 빌드에선 이 순환 때문에 EntitySpawner 컴파일이 실패해
# spawn_all이 없는 상태로 실행됐다 → 인게임 보드가 하나도 안 그려졌다.
# (에디터에서 실행하면 증상이 드러나지 않는다)
var EXP_RES: ResourceExporter = load("uid://bivlth267c0h3")
