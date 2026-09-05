# AutoLoad - AudioManager.gd
extends Node

## 게임 전체 오디오의 단일 진입점.
##
## 게임플레이 코드는 "무슨 일이 일어났는지"만 보고하고,
## 곡을 어떻게 바꿀지(인트로 사용 여부 / 페이드 방식 / 지연)는 이 노드가 판단한다.
##
##   AudioManager.report_health_tier(2, AudioManager.Source.DAMAGE)
##   AudioManager.report_health_tier(1, AudioManager.Source.HEAL)
##   AudioManager.report_health_tier(3, AudioManager.Source.UNDO)   # 자동 디바운스
##   AudioManager.set_dead(true)
##   AudioManager.play_sfx("rock_break")
##
## AutoLoad 순서: SaveManager 가 AudioManager 보다 위에 있어야 한다.

signal volume_changed(kind: StringName, value: float)
signal bgm_tier_changed(tier: int)


#region 설정
const BUS_MASTER := "Master"
const BUS_BGM := "BGM"
const BUS_SFX := "SFX"

const BGM_DIR := "res://07_Audio/BGM"
const SFX_DIR := "res://07_Audio/SFX"

const TIER_COUNT := 3

const SFX_POOL_SIZE := 16
## 같은 SFX가 이 프레임 수 안에 다시 요청되면 무시한다.
## 한 턴에 돌 3개가 동시에 착지해도 볼륨이 3배로 터지지 않게 하는 장치.
const SFX_DEDUP_FRAMES := 2
const SFX_DEFAULT_PITCH_VARIATION := 0.06

## undo 입력이 멈춘 뒤 이 시간이 지나야 BGM을 갱신한다.
## 연타 중 곡이 요동치는 것을 막는다.
const UNDO_SETTLE_TIME := 0.35

const SAVE_SECTION := "audio"
const DEFAULT_VOLUMES := {"master": 0.8, "bgm": 0.8, "sfx": 0.8}
#endregion


## 체력 단계 변화의 "원인". 이것에 따라 전환 연출이 결정된다.
enum Source {
	SPAWN,      ## 스테이지 진입 / 메인 메뉴
	DAMAGE,     ## 피해를 입어 단계가 나빠짐 → 인트로 연출
	HEAL,       ## 쿠키 등으로 호전 → 루프만, 부드럽게
	UNDO,       ## 되돌리기 → 안정화 대기 후 반영
	RESET,      ## R 리셋 / 사망 후 부활
	IMMEDIATE,  ## 연출 없이 즉시 (디버그용)
}

## 전환 프로파일
##   out        : 이전 곡 페이드아웃 시간
##   in         : 새 곡 페이드인 시간
##   intro      : 인트로 사용 여부 (단계가 "나빠질 때"만 실제로 적용됨)
##   sequential : true면 페이드아웃이 끝난 뒤 새 곡 시작(겹치지 않음), false면 크로스페이드
const TRANSITIONS := {
	Source.SPAWN:     {"out": 0.00, "in": 0.60, "intro": false, "sequential": false},
	Source.DAMAGE:    {"out": 0.20, "in": 0.05, "intro": true,  "sequential": true},
	Source.HEAL:      {"out": 1.20, "in": 1.20, "intro": false, "sequential": false},
	Source.UNDO:      {"out": 0.80, "in": 0.80, "intro": false, "sequential": false},
	Source.RESET:     {"out": 0.15, "in": 0.50, "intro": false, "sequential": false},
	Source.IMMEDIATE: {"out": 0.00, "in": 0.00, "intro": false, "sequential": false},
}

const DEATH_FADE_TIME := 0.25


#region BGM 채널
## BGM 한 곡을 재생하는 단위. 크로스페이드를 위해 두 개를 번갈아 쓴다.
class BgmChannel extends RefCounted:
	var a: AudioStreamPlayer   ## 단일 파일 / 인트로 / 루프전용
	var b: AudioStreamPlayer   ## 인트로+루프 분리 구성일 때의 루프
	var key := ""

	var vol := 0.0             ## 0~1 페이드 진행값 (실제 게인은 equal-power 변환 후)
	var _from := 0.0
	var _to := 0.0
	var _dur := 0.0
	var _elapsed := 0.0
	var _chain: AudioStream = null

	func _init(parent: Node, bus: String) -> void:
		a = AudioStreamPlayer.new()
		b = AudioStreamPlayer.new()
		for p: AudioStreamPlayer in [a, b]:
			p.bus = bus
			p.volume_db = -80.0
			parent.add_child(p)
		a.finished.connect(_on_a_finished)
		b.finished.connect(_on_b_finished)

	func _on_a_finished() -> void:
		if _chain != null:
			b.stream = _chain
			_chain = null
			b.play()
			apply()
		elif a.stream != null:
			# 임포트 설정에서 Loop를 안 켠 경우에 대한 안전망
			a.play()

	func _on_b_finished() -> void:
		if b.stream != null:
			b.play()

	## 0~1 값을 equal-power 곡선으로 변환한다.
	## 두 채널이 서로 보완적으로 움직일 때 gA^2 + gB^2 = 1 이 되어
	## 크로스페이드 중간의 볼륨 함몰(-3dB dip)이 사라진다.
	func apply() -> void:
		var g := sin(clampf(vol, 0.0, 1.0) * PI * 0.5)
		var db := -80.0 if g <= 0.0005 else linear_to_db(g)
		a.volume_db = db
		b.volume_db = db

	func fade_to(target: float, duration: float) -> void:
		_from = vol
		_to = target
		_dur = maxf(duration, 0.0)
		_elapsed = 0.0
		if _dur <= 0.0:
			vol = target
			apply()
			if vol <= 0.0:
				stop()

	func update(delta: float) -> void:
		if _dur <= 0.0:
			return
		_elapsed += delta
		var t := clampf(_elapsed / _dur, 0.0, 1.0)
		vol = lerpf(_from, _to, t)
		apply()
		if t >= 1.0:
			_dur = 0.0
			if vol <= 0.0:
				stop()

	func is_active() -> bool:
		return a.playing or b.playing

	func stop() -> void:
		_chain = null
		a.stop()
		b.stop()
		a.stream = null
		b.stream = null
		key = ""
		vol = 0.0
		_dur = 0.0
		apply()

	func play_track(track: Dictionary, use_intro: bool) -> void:
		stop()
		key = String(track["key"])

		if track["single"] != null:
			# 권장 구성: 인트로+루프가 한 파일. Import 탭의 Loop Offset이 루프 시작점.
			a.stream = track["single"]
			a.play(0.0 if use_intro else float(track["loop_offset"]))
		elif use_intro and track["intro"] != null and track["loop"] != null:
			a.stream = track["intro"]
			_chain = track["loop"]
			a.play()
		else:
			a.stream = track["loop"] if track["loop"] != null else track["intro"]
			if a.stream != null:
				a.play()

		apply()
#endregion


var master_volume := 1.0
var bgm_volume := 0.8
var sfx_volume := 1.0

var _tracks := {}          ## "tier_1" -> {key, single, intro, loop, loop_offset}
var _sfx := {}             ## "rock_break" -> Array[AudioStream]

var _channels: Array = []
var _active := 0
var _pending := {}         ## sequential 전환 대기 상태

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _sfx_last_frame := {}

var _current_tier := 0
var _dead := false
var _undo_timer: Timer
var _undo_pending_tier := 0


func _ready() -> void:
	# 설정 UI가 게임을 일시정지시켜도 오디오는 계속 돌아야 한다
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ensure_buses()
	_scan_bgm()
	_scan_sfx()
	_build_channels()
	_build_sfx_pool()

	_undo_timer = Timer.new()
	_undo_timer.one_shot = true
	_undo_timer.timeout.connect(_on_undo_settled)
	add_child(_undo_timer)

	_load_volumes()


func _process(delta: float) -> void:
	for c: BgmChannel in _channels:
		c.update(delta)

	if not _pending.is_empty():
		_pending["delay"] = float(_pending["delay"]) - delta
		if float(_pending["delay"]) <= 0.0:
			var p := _pending
			_pending = {}
			_start(p)


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
	# linear_to_db(0)은 -inf라 버스가 깨진다. 0이면 mute 플래그로 처리.
	AudioServer.set_bus_mute(idx, v <= 0.0005)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0005)))


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
## 체력 단계 변화를 보고한다. 연출 판단은 이 함수 안에서 이뤄진다.
func report_health_tier(tier: int, source: Source = Source.IMMEDIATE) -> void:
	tier = clampi(tier, 1, TIER_COUNT)

	if source == Source.UNDO:
		# 되돌리기 연타 중에는 곡을 건드리지 않고, 멈춘 뒤에 한 번만 반영한다
		_undo_pending_tier = tier
		_undo_timer.start(UNDO_SETTLE_TIME)
		return

	_undo_timer.stop()
	_undo_pending_tier = 0
	#_apply_tier(tier, source)


## 사망 / 부활. 사망 시 BGM은 그냥 꺼진다.
func set_dead(dead: bool, revive_tier: int = 0) -> void:
	if dead == _dead:
		return
	_dead = dead

	if dead:
		_undo_timer.stop()
		_undo_pending_tier = 0
		_pending = {}
		for c: BgmChannel in _channels:
			c.fade_to(0.0, DEATH_FADE_TIME)
	else:
		var t := revive_tier if revive_tier > 0 else maxi(_current_tier, 1)
		_current_tier = 0   # 강제로 다시 재생시키기 위해 초기화
		_apply_tier(t, Source.RESET)


func stop_bgm(fade_time: float = 0.5) -> void:
	_pending = {}
	_current_tier = 0
	for c: BgmChannel in _channels:
		c.fade_to(0.0, fade_time)


func get_current_tier() -> int:
	return _current_tier


func _on_undo_settled() -> void:
	if _undo_pending_tier <= 0:
		return
	var t := _undo_pending_tier
	_undo_pending_tier = 0
	if _dead:
		return
	_apply_tier(t, Source.UNDO)


func _apply_tier(tier: int, source: Source) -> void:
	if _dead and source != Source.RESET:
		_current_tier = tier   # 부활 시 쓰도록 기억만 해둔다
		return

	var key := "tier_%d" % tier
	if not _tracks.has(key):
		push_warning("[AudioManager] BGM 트랙이 없다: %s (%s 확인)" % [key, BGM_DIR])
		return

	var worse := tier > _current_tier and _current_tier > 0
	var previous := _current_tier
	_current_tier = tier

	# 이미 같은 곡이 돌고 있으면 아무것도 하지 않는다.
	# 메인 메뉴(tier 1) -> 게임 시작(tier 1) 이 끊기지 않고 이어지는 이유.
	var active: BgmChannel = _channels[_active]
	if active.key == key and active.is_active() and _pending.is_empty():
		return

	var profile: Dictionary = (TRANSITIONS[source] as Dictionary).duplicate()
	# 인트로는 "나빠질 때"의 연출이다. 호전이거나 첫 재생이면 루프부터 간다.
	if not worse:
		profile["intro"] = false
		profile["sequential"] = false

	_transition(_tracks[key], profile)
	if previous != tier:
		bgm_tier_changed.emit(tier)


func _transition(track: Dictionary, profile: Dictionary) -> void:
	var out_t := float(profile["out"])
	var in_t := float(profile["in"])
	var sequential := bool(profile["sequential"])
	var use_intro := bool(profile["intro"])

	var current: BgmChannel = _channels[_active]
	if current.is_active():
		current.fade_to(0.0, out_t)

	var req := {"track": track, "use_intro": use_intro, "in": in_t,
		"delay": out_t if sequential else 0.0}

	if float(req["delay"]) <= 0.0:
		_start(req)
	else:
		_pending = req


func _start(req: Dictionary) -> void:
	_active = 1 - _active
	var ch: BgmChannel = _channels[_active]
	ch.play_track(req["track"], bool(req["use_intro"]))
	ch.fade_to(1.0, float(req["in"]))
#endregion


#region SFX
## opts:
##   volume_db       (float)  기본 0.0
##   pitch_scale     (float)  기본 1.0
##   pitch_variation (float)  기본 0.06, 0으로 주면 랜덤화 끔
##   bypass_dedup    (bool)   기본 false
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


func _build_channels() -> void:
	_channels = [BgmChannel.new(self, BUS_BGM), BgmChannel.new(self, BUS_BGM)]


func _build_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_sfx_pool.append(p)


## 파일명 규칙
##   tier_1.ogg                        -> 단일 파일 (Import 탭의 Loop Offset이 루프 시작점)
##   tier_2_intro.ogg / tier_2_loop.ogg -> 분리 구성
##   tier_3_loop.ogg                    -> 인트로 없음
func _scan_bgm() -> void:
	for path: String in _list_audio_files(BGM_DIR):
		var stream := load(path) as AudioStream
		if stream == null:
			continue

		var base := path.get_file().get_basename()
		var key := base
		var role := "single"
		if base.ends_with("_intro"):
			key = base.trim_suffix("_intro")
			role = "intro"
		elif base.ends_with("_loop"):
			key = base.trim_suffix("_loop")
			role = "loop"

		if not _tracks.has(key):
			_tracks[key] = {"key": key, "single": null, "intro": null,
				"loop": null, "loop_offset": 0.0}
		_tracks[key][role] = stream

		if role == "single":
			var offset: Variant = stream.get("loop_offset")
			_tracks[key]["loop_offset"] = float(offset) if offset != null else 0.0


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
