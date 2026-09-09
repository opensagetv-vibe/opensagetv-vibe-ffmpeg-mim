#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MIM="$ROOT/output/linux-x64/ffmpeg_MIM"
INIT_SRC="$ROOT/ffmpeg_init.sh"

[[ -x "$MIM" ]] || {
  CXX_BIN="${CXX:-g++}"
  mkdir -p "$ROOT/output/linux-x64"
  "$CXX_BIN" -std=c++17 -O2 -pipe -pthread -static -s \
    "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp" -o "$MIM"
}

make_bundle() {
  local d="$1"
  mkdir -p "$d"
  cp "$MIM" "$d/ffmpeg_MIM"
  cp "$INIT_SRC" "$d/ffmpeg_init.sh"
  cat > "$d/ffmpeg.real" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  cat > "$d/ffprobe" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod 600 "$d/ffmpeg_MIM" "$d/ffmpeg.real" "$d/ffprobe" "$d/ffmpeg_init.sh"
}

mode_of() { stat -c '%a' "$1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 1) Stock/non-MIM ffmpeg starts non-executable, is chmodded before detection,
# backed up without _MIM, and replaced with ffmpeg_MIM.
D="$TMP/stock"
make_bundle "$D"
cat > "$D/ffmpeg" <<'SH'
#!/usr/bin/env bash
echo stock
SH
chmod 600 "$D/ffmpeg"
bash "$D/ffmpeg_init.sh" > "$D/log.txt"
cmp -s "$D/ffmpeg" "$D/ffmpeg_MIM"
stock_backup="$(find "$D" -maxdepth 1 -type f -name 'ffmpeg_20*' ! -name '*_MIM' | head -n1)"
[[ -n "$stock_backup" ]]
[[ "$(mode_of "$D/ffmpeg")" == 777 ]]
[[ "$(mode_of "$D/ffmpeg_MIM")" == 777 ]]
[[ "$(mode_of "$D/ffmpeg.real")" == 777 ]]
[[ "$(mode_of "$D/ffprobe")" == 777 ]]
[[ "$(mode_of "$D/ffmpeg_init.sh")" == 777 ]]

# 2) Older MIM is detected and its backup gets the _MIM postfix.
D="$TMP/oldmim"
make_bundle "$D"
cat > "$D/ffmpeg" <<'SH'
#!/usr/bin/env bash
if [[ "${1:-}" == "--mim-version" ]]; then
  echo 'SageTV FFmpeg MIM 0.3.1 (linux-x64)'
  exit 0
fi
exit 0
SH
chmod 600 "$D/ffmpeg"
bash "$D/ffmpeg_init.sh" > "$D/log.txt"
cmp -s "$D/ffmpeg" "$D/ffmpeg_MIM"
old_backup="$(find "$D" -maxdepth 1 -type f -name 'ffmpeg_20*_MIM' | head -n1)"
[[ -n "$old_backup" ]]
grep -q 'older/different MIM' "$D/log.txt"

# 3) Exact current MIM is left untouched and no timestamp backup is made.
D="$TMP/current"
make_bundle "$D"
cp "$D/ffmpeg_MIM" "$D/ffmpeg"
chmod 600 "$D/ffmpeg"
bash "$D/ffmpeg_init.sh" > "$D/log.txt"
cmp -s "$D/ffmpeg" "$D/ffmpeg_MIM"
[[ -z "$(find "$D" -maxdepth 1 -type f -name 'ffmpeg_20*' -print -quit)" ]]
grep -q 'already matches ffmpeg_MIM' "$D/log.txt"
[[ "$(mode_of "$D/ffmpeg")" == 777 ]]

echo '[PASS] ffmpeg_init chmod-first + backup + older-MIM detection tests'
