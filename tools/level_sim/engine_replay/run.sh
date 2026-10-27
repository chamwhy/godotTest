#!/bin/bash
# 엔진 재생 검증. 게임 프로젝트를 임시 폴더에 복사하고 Replay.gd를 오토로드로 넣어 헤드리스로 돌린다.
#   GODOT=/path/to/Godot_v4.7 tools/level_sim/engine_replay/run.sh            # 모든 스테이지
#   GODOT=/path/to/Godot_v4.7 tools/level_sim/engine_replay/run.sh 02_01 02_09 # 일부만
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../.." && pwd)
: "${GODOT:?GODOT 환경변수에 Godot 4.7 실행 파일 경로를 넣어 주세요}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp -r "$ROOT/godot/." "$TMP/"
rm -rf "$TMP/.godot"
cp "$HERE/Replay.gd" "$TMP/Replay.gd"
python3 - "$TMP/project.godot" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
s = s.replace("[autoload]\n\n", '[autoload]\n\nReplay="*res://Replay.gd"\n', 1)
open(p, "w", encoding="utf-8").write(s)
PY
python3 "$HERE/make_solutions.py" "$TMP/replay_solutions.json" "$@"
"$GODOT" --headless --path "$TMP" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$TMP" 2>&1 | grep -E "REPLAY|SCRIPT ERROR|Parse Error"
