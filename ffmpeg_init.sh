#!/usr/bin/env bash
set -euo pipefail

# SageTV FFmpeg MIM installer/repair helper.
# Intended to run from the SageTV executable directory after a SageTV Docker
# update may have restored/replaced the stock ./ffmpeg binary.

# Resolve this script's directory using shell builtins first.  This deliberately
# happens before we try to execute ./ffmpeg or ./ffmpeg_MIM.
SELF="${BASH_SOURCE[0]}"
case "$SELF" in
  /*) SCRIPT_DIR="${SELF%/*}" ;;
  */*) SCRIPT_DIR="$(cd -P -- "${SELF%/*}" && pwd)" ;;
  *) SCRIPT_DIR="$PWD" ;;
esac

FFMPEG="$SCRIPT_DIR/ffmpeg"
MIM="$SCRIPT_DIR/ffmpeg_MIM"
REAL="$SCRIPT_DIR/ffmpeg.real"
FFPROBE="$SCRIPT_DIR/ffprobe"
INIT="$SCRIPT_DIR/ffmpeg_init.sh"

# IMPORTANT: permissions are fixed FIRST, before any binary is executed for
# identification/version checks.  Missing files are ignored here so we can
# report a useful error below.
for exe in "$FFMPEG" "$MIM" "$REAL" "$FFPROBE" "$INIT"; do
  if [[ -e "$exe" || -L "$exe" ]]; then
    chmod 777 -- "$exe" 2>/dev/null || true
  fi
done

if [[ ! -f "$MIM" ]]; then
  echo "ERROR: SageTV FFmpeg MIM not found: $MIM" >&2
  exit 2
fi

if [[ ! -f "$REAL" ]]; then
  echo "ERROR: real FFmpeg not found: $REAL" >&2
  exit 3
fi

# ffprobe is expected in the deployment bundle.  Warn instead of aborting so
# the MIM can still be restored and SageTV can be brought back online.
if [[ ! -f "$FFPROBE" ]]; then
  echo "WARNING: ffprobe not found: $FFPROBE" >&2
fi

mim_info="$($MIM --mim-version 2>/dev/null || true)"
if [[ "$mim_info" == *"SageTV FFmpeg MIM"* ]]; then
  echo "[init] available MIM: $mim_info"
else
  echo "WARNING: ffmpeg_MIM did not report a SageTV MIM version." >&2
fi

same_binary() {
  local a="$1" b="$2"
  if command -v cmp >/dev/null 2>&1; then
    cmp -s -- "$a" "$b"
    return $?
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    [[ "$(sha256sum -- "$a" | awk '{print $1}')" == "$(sha256sum -- "$b" | awk '{print $1}')" ]]
    return $?
  fi
  # Extremely small/minimal containers should normally still have cmp.  If
  # neither comparator exists, fail closed and reinstall after making a backup.
  return 1
}

is_sagetv_mim() {
  local exe="$1" info=""
  [[ -f "$exe" ]] || return 1

  # chmod was deliberately done above before this execution attempt.
  info="$($exe --mim-version 2>/dev/null || true)"
  if [[ "$info" == *"SageTV FFmpeg MIM"* ]]; then
    EXISTING_MIM_INFO="$info"
    return 0
  fi

  # Fallback for an older MIM that might not execute correctly in the current
  # environment but still contains the identifying string.
  if command -v strings >/dev/null 2>&1 && strings -- "$exe" 2>/dev/null | grep -Fq 'SageTV FFmpeg MIM'; then
    EXISTING_MIM_INFO="SageTV FFmpeg MIM (version could not be executed)"
    return 0
  fi
  return 1
}

make_backup_name() {
  local suffix="$1" stamp base candidate n
  stamp="$(date '+%Y%m%d_%H%M%S')"
  base="$SCRIPT_DIR/ffmpeg_${stamp}"
  candidate="${base}${suffix}"
  n=1
  while [[ -e "$candidate" || -L "$candidate" ]]; do
    candidate="${base}_${n}${suffix}"
    n=$((n + 1))
  done
  printf '%s\n' "$candidate"
}

# Exact binary match means the correct MIM is already installed.  Still leave
# every executable at mode 777 as requested.
if [[ -f "$FFMPEG" ]] && same_binary "$FFMPEG" "$MIM"; then
  chmod 777 -- "$FFMPEG" "$MIM" "$REAL" 2>/dev/null || true
  [[ -f "$FFPROBE" ]] && chmod 777 -- "$FFPROBE" 2>/dev/null || true
  chmod 777 -- "$INIT" 2>/dev/null || true
  echo "[init] ffmpeg already matches ffmpeg_MIM. No replacement required."
  exit 0
fi

backup=""
if [[ -e "$FFMPEG" || -L "$FFMPEG" ]]; then
  suffix=""
  EXISTING_MIM_INFO=""
  if is_sagetv_mim "$FFMPEG"; then
    suffix="_MIM"
    echo "[init] existing ffmpeg identified as older/different MIM: $EXISTING_MIM_INFO"
  else
    echo "[init] existing ffmpeg identified as stock/non-MIM FFmpeg."
  fi

  backup="$(make_backup_name "$suffix")"
  cp -pL -- "$FFMPEG" "$backup"
  chmod 777 -- "$backup" 2>/dev/null || true
  echo "[init] backup created: $backup"
else
  echo "[init] no existing ffmpeg found; no backup required."
fi

# Install through a temporary file in the same directory so ffmpeg is never
# left partially copied if the process is interrupted during the copy.
tmp="$SCRIPT_DIR/.ffmpeg_MIM.install.$$"
trap 'rm -f -- "$tmp" 2>/dev/null || true' EXIT
cp -f -- "$MIM" "$tmp"
chmod 777 -- "$tmp"
mv -f -- "$tmp" "$FFMPEG"
trap - EXIT

# Final permission pass.  ffmpeg itself is included explicitly.
for exe in "$FFMPEG" "$MIM" "$REAL" "$FFPROBE" "$INIT"; do
  if [[ -e "$exe" || -L "$exe" ]]; then
    chmod 777 -- "$exe" 2>/dev/null || true
  fi
done

if ! same_binary "$FFMPEG" "$MIM"; then
  echo "ERROR: installed ffmpeg does not match ffmpeg_MIM after copy." >&2
  exit 4
fi

installed_info="$($FFMPEG --mim-version 2>/dev/null || true)"
echo "[init] ffmpeg_MIM installed as ffmpeg."
[[ -n "$installed_info" ]] && echo "[init] installed: $installed_info"
[[ -n "$backup" ]] && echo "[init] previous ffmpeg: $backup"
exit 0
