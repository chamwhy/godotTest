# AutoLoad - AudioManager.gd
extends Node

## 게임 전체 오디오의 단일 진입점.
##
## BGM은 현재 한 곡 고정이다. 게임플레이 코드는 재생/정지/일시정지만 요청하고,
## 페이드와 덕킹 처리는 이 노드가 판단한다.
##
##   AudioManager.play_bgm()              # 07_Audio/BGM/main.ogg
##   AudioManager.set_bgm_paused(true)    # 사망 / 일시정지 메뉴
##   AudioManager.stop_bgm()
##   AudioManager.play_sfx("rock_break")
##
## AutoLoad 순서: SaveManager 가 AudioManager 보다 위에 있어야 한다.

signal volume_changed(kind: StringName, value: float)


#region 설정
const BUS_MASTER := "Master"
const BUS_BGM := "BGM"
const BUS_SFX := "SFX"

const BGM_DIR := "res://07_Audio/BGM"
const SFX_DIR := "res://07_Audio/SFX"

## 폴더 안의 파일명(확장자 제외)이 곧 키다. 기본으로 재생할 곡.
const BGM_DEFAULT := "main"
const BGM_FADE_IN := 0.60
const BGM_FADE_OUT := 0.50
const BGM_PAUSE_FADE := 0.25

const SFX_POOL_SIZE := 16
## 같은 SFX가 이 프레임 수 안에 다시 요청되면 무시한다.
## 한 턴에 돌 3개가 동시에 착지해도 볼륨이 3배로 터지지 않게 하는 장치.
const SFX_DEDUP_FRAMES := 2
const SFX_DEFAULT_PITCH_VARIATION := 0.06

const SAVE_SECTION := "audio"
const DEFAULT_VOLUMES := {"master": 0.8, "bgm": 0.8, "sfx": 0.8}
#endregion


#region 덕킹
## SFX가 날 때 BGM을 잠깐 눌러주는 층.
## 최종 BGM 게인 = bgm_volume * _duck_gain  (사용자 볼륨 설정과 완전히 독립)
const DUCK_ENABLED := true
const DUCK_AMOUNT := 0.55        ## 눌렸을 때 비율 (1.0 = 안 누름)
const DUCK_ATTACK := 0.05        ## 내려가는 시간
const DUCK_RELEASE := 0.40       ## 돌아오는 시간
const DUCK_HOLD_EXTRA := 0.05    ## SFX가 끝난 뒤 더 유지할 여유
const DUCK_HOLD_MAX := 1.50      ## 긴 SFX에 물려 BGM이 오래 눌리는 것 방지

## 키별 예외. 없으면 DUCK_AMOUNT를 쓴다. 1.0을 주면 그 SFX는 BGM을 안 건드린다.
const DUCK_BY_SFX := {
	"ui_hover": 1.0,
	"ui_click": 1.0,
}
#endregion


var master_volume := 1.0
var bgm_volume := 0.8
var sfx_volume := 1.0

var _tracks := {}          ## "main" -> AudioStream
var _sfx := {}             ## "rock_break" -> Array[AudioStream]

var _bgm: AudioStreamPlayer
var _bgm_key := ""
var _bgm_paused := false

## BGM 페이드 (0~1 진행값, 실제 게인은 equal-power 변환 후)
var _fade := 0.0
var _fade_from := 0.0
var _fade_target := 0.0
var _fade_dur := 0.0
var _fade_elapsed := 0.0

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _sfx_last_frame := {}

var _duck_gain := 1.0    ## 현재 덕킹 게인 (1.0 = 원상태)
var _duck_floor := 1.0   ## 이번 덕킹의 목표 최저점
var _duck_hold := 0.0    ## 최저점 유지 남은 시간


func _ready() -> void:
	# 설정 UI가 게임을 일시정지시켜도 오디오는 계속 돌아야 한다
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ensure_buses()
	_scan_bgm()
	_scan_sfx()
	_build_bgm_player()
	_build_sfx_pool()

	_load_volumes()


func _process(delta: float) -> void:
	_update_fade(delta)
	_update_duck(delta)


#region 볼륨
func set_master_volume(v: float) -> void:
	_set_volume(&"master", v)

func set_bgm_volume(v: float) -> void:
	_set_volume(&"bgm", v)

func set_sfx_volume(v: float) -> void:
	_set_volume(&"sfx", v)

func get_volume(kind: StringName) -> float:
	match kind:
		&"master": return master_volume
		&"bgm": return bgm_volume
		&"sfx": return sfx_volume
	return 1.0


func _set_volume(kind: StringName, v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	var bus := ""
	match kind:
		&"master":
			master_volume = v
			bus = BUS_MASTER
		&"bgm":
			bgm_volume = v
			bus = BUS_BGM
		&"sfx":
			sfx_volume = v
			bus = BUS_SFX
		_:
			return

	_apply_bus(bus, v)
	SaveManager.set_value(SAVE_SECTION, "%s_volume" % kind, v)
	volume_changed.emit(kind, v)


func _apply_bus(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var gain := v
	if bus_name == BUS_BGM:
		gain *= _duck_gain
	# mute 판정은 "사용자 볼륨" 기준. 덕킹 때문에 버스가 꺼진 것처럼 처리되면 안 된다.
	# linear_to_db(0)은 -inf라 버스가 깨진다. 0이면 mute 플래그로 처리.
	AudioServer.set_bus_mute(idx, v <= 0.0005)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(gain, 0.0005)))


func _load_volumes() -> void:
	for kind: String in DEFAULT_VOLUMES:
		var v := float(SaveManager.get_value(
			SAVE_SECTION, "%s_volume" % kind, DEFAULT_VOLUMES[kind]))
		match kind:
			"master": master_volume = v
			"bgm": bgm_volume = v
			"sfx": sfx_volume = v
		_apply_bus(_bus_of(kind), v)
		volume_changed.emit(StringName(kind), v)


func _bus_of(kind: String) -> String:
	match kind:
		"master": return BUS_MASTER
		"bgm": return BUS_BGM
		"sfx": return BUS_SFX
	return BUS_MASTER
#endregion


#region BGM
## 곡을 재생한다. 이미 같은 곡이 돌고 있으면 끊지 않고 페이드만 올린다.
## (메인 메뉴 -> 게임 시작 이 이어지는 이유)
func play_bgm(key: String = BGM_DEFAULT, fade_in: float = BGM_FADE_IN) -> void:
	if not _tracks.has(key):
		push_warning("[AudioManager] BGM 트랙이 없다: %s (%s 확인)" % [key, BGM_DIR])
		return

	_bgm_paused = false

	if _bgm_key == key and (_bgm.playing or _bgm.stream_paused):
		_bgm.stream_paused = false
		_fade_to(1.0, fade_in)
		return

	# 다른 곡으로 바꾸면 즉시 갈아끼운다. 곡이 하나뿐인 지금은 발생하지 않는 경로.
	# 나중에 곡이 늘어나면 여기서 fade_out 후 교체하는 처리가 필요하다.
	_bgm_key = key
	_bgm.stream = _tracks[key]
	_bgm.stream_paused = false
	_fade = 0.0
	_apply_fade()
	_bgm.play()
	_fade_to(1.0, fade_in)


## 일시정지. 재생 위치를 유지하므로 사망/메뉴 복귀 시 곡이 이어진다.
func set_bgm_paused(paused: bool, fade: float = BGM_PAUSE_FADE) -> void:
	if paused == _bgm_paused:
		return
	_bgm_paused = paused

	if paused:
		_fade_to(0.0, fade)   # 페이드 완료 시 stream_paused = true
	elif _bgm.stream != null:
		_bgm.stream_paused = false
		_fade_to(1.0, fade)


func stop_bgm(fade_out: float = BGM_FADE_OUT) -> void:
	_bgm_paused = false
	_fade_to(0.0, fade_out)


func is_bgm_playing() -> bool:
	return _bgm.playing and not _bgm.stream_paused


func _build_bgm_player() -> void:
	_bgm = AudioStreamPlayer.new()
	_bgm.bus = BUS_BGM
	_bgm.volume_db = -80.0
	add_child(_bgm)
	_bgm.finished.connect(_on_bgm_finished)


func _on_bgm_finished() -> void:
	# 임포트 설정에서 Loop를 안 켠 경우에 대한 안전망.
	# stop()은 finished를 쏘지 않으므로 여기로 들어오지 않는다.
	if _bgm.stream != null and not _bgm_paused:
		_bgm.play()


## 0~1 값을 equal-power 곡선으로 변환한다. 페이드 중간이 함몰되지 않는다.
func _apply_fade() -> void:
	var g := sin(clampf(_fade, 0.0, 1.0) * PI * 0.5)
	_bgm.volume_db = -80.0 if g <= 0.0005 else linear_to_db(g)


func _fade_to(target: float, duration: float) -> void:
	_fade_from = _fade
	_fade_target = target
	_fade_dur = maxf(duration, 0.0)
	_fade_elapsed = 0.0
	if _fade_dur <= 0.0:
		_fade = target
		_apply_fade()
		if _fade <= 0.0:
			_on_fade_silent()


func _update_fade(delta: float) -> void:
	if _fade_dur <= 0.0:
		return
	_fade_elapsed += delta
	var t := clampf(_fade_elapsed / _fade_dur, 0.0, 1.0)
	_fade = lerpf(_fade_from, _fade_target, t)
	_apply_fade()
	if t >= 1.0:
		_fade_dur = 0.0
		if _fade <= 0.0:
			_on_fade_silent()


func _on_fade_silent() -> void:
	if _bgm_paused:
		_bgm.stream_paused = true   # 재생 위치 유지
	else:
		_bgm.stop()
		_bgm.stream = null
		_bgm_key = ""
#endregion


#region 덕킹
## BGM을 amount 비율까지 눌렀다가 hold 뒤에 자동 복귀시킨다.
## 여러 번 겹쳐 들어오면 더 깊은 쪽 / 더 긴 쪽이 이긴다.
func duck_bgm(amount: float, hold: float = 0.0) -> void:
	amount = clampf(amount, 0.0, 1.0)
	if amount >= 1.0:
		return
	_duck_floor = minf(_duck_floor, amount)
	_duck_hold = maxf(_duck_hold, maxf(hold, DUCK_ATTACK))


func get_duck_gain() -> float:
	return _duck_gain


func _update_duck(delta: float) -> void:
	# 완전히 복귀한 상태면 매 프레임 버스를 만지지 않는다
	if _duck_hold <= 0.0 and is_equal_approx(_duck_gain, 1.0):
		_duck_floor = 1.0
		return

	var target := 1.0
	if _duck_hold > 0.0:
		_duck_hold -= delta
		target = _duck_floor

	# 깊이에 상관없이 attack/release 시간이 일정하도록 rate를 깊이로 정규화
	var depth := maxf(1.0 - _duck_floor, 0.001)
	var dur := DUCK_ATTACK if target < _duck_gain else DUCK_RELEASE
	_duck_gain = move_toward(_duck_gain, target, depth / maxf(dur, 0.001) * delta)

	_apply_bus(BUS_BGM, bgm_volume)
#endregion


#region SFX
## opts:
##   volume_db       (float)  기본 0.0
##   pitch_scale     (float)  기본 1.0
##   pitch_variation (float)  기본 0.06, 0으로 주면 랜덤화 끔
##   bypass_dedup    (bool)   기본 false
##   duck            (float)  기본 DUCK_BY_SFX/DUCK_AMOUNT, 1.0이면 덕킹 안 함
##   duck_hold       (float)  기본 SFX 길이 기반 자동 계산
func play_sfx(key: String, opts: Dictionary = {}) -> void:
	if not _sfx.has(key):
		push_warning("[AudioManager] SFX가 없다: %s (%s 확인)" % [key, SFX_DIR])
		return

	if not bool(opts.get("bypass_dedup", false)):
		var frame := Engine.get_process_frames()
		if int(_sfx_last_frame.get(key, -9999)) > int(frame) - SFX_DEDUP_FRAMES:
			return
		_sfx_last_frame[key] = frame

	var variants: Array = _sfx[key]
	var player := _take_sfx_player()
	player.stream = variants[randi() % variants.size()]
	player.volume_db = float(opts.get("volume_db", 0.0))

	var variation := float(opts.get("pitch_variation", SFX_DEFAULT_PITCH_VARIATION))
	var base_pitch := float(opts.get("pitch_scale", 1.0))
	player.pitch_scale = base_pitch * randf_range(1.0 - variation, 1.0 + variation)
	player.play()

	if not DUCK_ENABLED:
		return
	var amount := float(opts.get("duck", DUCK_BY_SFX.get(key, DUCK_AMOUNT)))
	if amount >= 1.0:
		return
	# 피치를 올리면 실제 재생 시간이 줄어든다
	var length := player.stream.get_length() / maxf(player.pitch_scale, 0.01)
	var hold := float(opts.get("duck_hold",
		minf(length, DUCK_HOLD_MAX) + DUCK_HOLD_EXTRA))
	duck_bgm(amount, hold)


func has_sfx(key: String) -> bool:
	return _sfx.has(key)


func _take_sfx_player() -> AudioStreamPlayer:
	var n := _sfx_pool.size()
	for i in n:
		var idx := (_sfx_cursor + i) % n
		if not _sfx_pool[idx].playing:
			_sfx_cursor = (idx + 1) % n
			return _sfx_pool[idx]
	# 전부 사용 중이면 가장 오래된 것을 뺏는다
	var p := _sfx_pool[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % n
	return p
#endregion


#region 초기화
func _ensure_buses() -> void:
	# 에디터 Audio 탭에서 만들어두는 게 정석이지만, 없으면 런타임에 만들어 둔다
	for bus_name: String in [BUS_BGM, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, BUS_MASTER)


func _build_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_sfx_pool.append(p)


## 파일명 규칙
##   main.ogg -> "main"
## 루프는 Import 탭에서 켜둘 것.
func _scan_bgm() -> void:
	for path: String in _list_audio_files(BGM_DIR):
		var stream := load(path) as AudioStream
		if stream == null:
			continue
		_tracks[path.get_file().get_basename()] = stream


## 파일명 규칙
##   rock_break.wav                       -> "rock_break"
##   rock_break_1.wav / rock_break_2.wav  -> "rock_break" (랜덤 선택)
func _scan_sfx() -> void:
	for path: String in _list_audio_files(SFX_DIR):
		var stream := load(path) as AudioStream
		if stream == null:
			continue

		var base := path.get_file().get_basename()
		var key := base
		var parts := base.rsplit("_", true, 1)
		if parts.size() == 2 and (parts[1] as String).is_valid_int():
			key = parts[0]

		if not _sfx.has(key):
			_sfx[key] = []
		_sfx[key].append(stream)


func _list_audio_files(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("[AudioManager] 폴더를 열 수 없다: %s" % dir_path)
		return out

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				out.append_array(_list_audio_files(dir_path.path_join(entry)))
		else:
			# 에디터에서는 x.ogg 와 x.ogg.import 가 같이 보이고,
			# 익스포트된 빌드에서는 .remap 이 붙는다. 둘 다 벗겨서 통일한다.
			var name := entry
			if name.ends_with(".import") or name.ends_with(".remap"):
				name = name.get_basename()
			if name.get_extension().to_lower() in ["ogg", "wav", "mp3", "tres", "res"]:
				var full := dir_path.path_join(name)
				if not (full in out):
					out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return out
#endregion
