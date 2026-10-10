# EmotionTint.gd
## 감정(= 체력)에 따라 화면 배경색에 붉은 색조를 섞는다.
##
## 감정은 이 게임의 심장인데 지금까지 HP바 하트와 프로필 교체로만 드러났다.
## 배경색은 플레이어가 맵을 볼 때 항상 시야에 들어오므로, 아주 옅게 깔아도
## "지금 내가 어떤 상태인지"가 계속 느껴진다. 그래서 세게 넣지 않는다.
##
## ─── 왜 폴링인가 ─────────────────────────────────────────────
## player_emotion_changed를 구독하면 스테이지마다 새 플레이어에 다시 연결해야
## 하고, 리셋·되돌리기로 감정이 되돌아갈 때의 초기 동기화도 따로 챙겨야 한다.
## 어차피 매 프레임 보간하는 연출이므로 매 프레임 목표색을 다시 계산하는 쪽이
## 연결 수명 관리가 없어 더 안전하다.
## ─────────────────────────────────────────────────────────────
extends Node

## 평온 = 손대지 않은 원래 배경색. project.godot의 default_clear_color와 같아야 한다.
const CALM_COLOR := Color(0.91, 0.91, 0.91)
## 화남 — 아주 옅게
const ANGRY_COLOR := Color(0.93, 0.85, 0.83)
## 격노 — 그래도 "살짝"의 범위를 넘지 않는다
const RAGE_COLOR := Color(0.95, 0.76, 0.72)

## 1초에 목표색까지 남은 거리의 몇 배를 좁히는가.
## 지수 보간이라 프레임레이트와 무관하게 같은 속도로 보인다.
const LERP_SPEED := 4.0

var _current := CALM_COLOR


func _ready() -> void:
	_current = CALM_COLOR
	RenderingServer.set_default_clear_color(_current)


func _process(delta: float) -> void:
	var target := _target_color()
	if _current.is_equal_approx(target):
		return
	# 1 - exp(-k*dt): 프레임 간격이 흔들려도 수렴 속도가 같다
	_current = _current.lerp(target, 1.0 - exp(-LERP_SPEED * delta))
	RenderingServer.set_default_clear_color(_current)


func _target_color() -> Color:
	var player: Player = PlayerRegistry.get_player()
	if player == null or not is_instance_valid(player):
		return CALM_COLOR
	# 죽었으면 감정이랄 게 없다. 원래 색으로 돌린다.
	if player.is_dead or player.is_fallen:
		return CALM_COLOR

	match player.cur_emotion:
		Player.PlayerEmotion.RAGE:  return RAGE_COLOR
		Player.PlayerEmotion.ANGRY: return ANGRY_COLOR
		_:                          return CALM_COLOR
