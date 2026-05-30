# AutoLoad - Config.gd
extends Node

# === 게임 전역 상수 ===
const START_MAP_ID := 1			# 시작 맵 id
const DEFALT_UNIT_MAX_HP := 1	# 유닛 기본 최대체력

# 1. 원본 리소스 로드
var EXP_RES = preload("uid://bivlth267c0h3")
