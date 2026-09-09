#!/usr/bin/env bash
set -u

# Run from the SageTV server directory after deploying a build.
# Optional first argument: a real recording path visible inside the container.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT="${1:-}"
OUT="$ROOT/sagetv_miniplayer_debug.txt"

{
  echo "===== DATE ====="
  date -Is
  echo
  echo "===== DEPLOYED MIM ====="
  "$ROOT/ffmpeg" --mim-version 2>&1 || true
  "$ROOT/ffmpeg_MIM" --mim-version 2>&1 || true
  echo
  echo "===== FILE HASHES ====="
  sha256sum "$ROOT/ffmpeg" "$ROOT/ffmpeg_MIM" "$ROOT/ffmpeg.real" "$ROOT/ffmpeg.real.ini" 2>&1 || true
  echo
  echo "===== FFMPEG.REAL VERSION ====="
  "$ROOT/ffmpeg.real" -version 2>&1 | head -20 || true
  echo
  echo "===== SAGETV RATE-CONTROL PATCH ====="
  if grep -a -q 'sagetvratectrl' "$ROOT/ffmpeg.real" 2>/dev/null; then
    echo "PASS: sagetvratectrl marker found in ffmpeg.real"
  else
    echo "FAIL: sagetvratectrl marker NOT found in ffmpeg.real"
  fi
  echo
  echo "===== HARDWARE CONFIG ====="
  awk 'BEGIN{p=0} /^\[hardware\]/{p=1} /^\[/{if(p && $0!="[hardware]") exit} p{print}' "$ROOT/ffmpeg.real.ini" 2>&1 || true
  echo
  echo "===== COMPATIBILITY CONFIG ====="
  awk 'BEGIN{p=0} /^\[compatibility\]/{p=1} /^\[/{if(p && $0!="[compatibility]") exit} p{print}' "$ROOT/ffmpeg.real.ini" 2>&1 || true
  echo
  echo "===== LOGGING CONFIG ====="
  awk 'BEGIN{p=0} /^\[logging\]/{p=1} /^\[/{if(p && $0!="[logging]") exit} p{print}' "$ROOT/ffmpeg.real.ini" 2>&1 || true
  echo
  echo "===== FFMPEG.REAL LOG ====="
  if [[ -f "$ROOT/ffmpeg.real.log" ]]; then
    tail -200 "$ROOT/ffmpeg.real.log" 2>&1 || true
  else
    echo "$ROOT/ffmpeg.real.log not found"
  fi

  if [[ -n "$INPUT" ]]; then
    echo
    echo "===== INPUT ====="
    printf '%s\n' "$INPUT"
    ls -l "$INPUT" 2>&1 || true

    echo
    echo "===== DUMPMETADATA DRY RUN ====="
    "$ROOT/ffmpeg" --mim-dry-run -dumpmetadata -v 2 -i "$INPUT" 2>&1 || true

    echo
    echo "===== DUMPMETADATA LIVE COMPAT TEST ====="
    "$ROOT/ffmpeg" -dumpmetadata -v 2 -i "$INPUT" 2>&1 || true

    echo
    echo "===== MINIPLAYER QSV DRY RUN ====="
    "$ROOT/ffmpeg" --mim-dry-run \
      -ss 10 -v 3 -y -threads 2 -sn -vsync 0 -async 1 -stdinctrl \
      -i "$INPUT" -threads 5 -f matroska -vcodec mpeg4 -b 1000000 \
      -r 29.97 -s 720x480 -g 300 -bf 0 -acodec mp2 -ab 112000 \
      -ar 48000 -ac 1 -packetsize 1024 -aspect 16:9 -muxrate 2000000 \
      -rc_init_cplx 197 -maxrate 1000000 -minrate 0 -bufsize 1000000 \
      -mbd 2 - 2>&1 || true
  else
    echo
    echo "No input file supplied. To include metadata/MiniPlayer dry-run checks:"
    echo "  ./diagnose_miniplayer.sh /var/media/path/to/recording.ts"
  fi
} >"$OUT" 2>&1

chmod 666 "$OUT" 2>/dev/null || true
echo "Wrote: $OUT"
