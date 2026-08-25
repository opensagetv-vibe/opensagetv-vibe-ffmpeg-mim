#!/usr/bin/env bash
set -u
CONTAINER="${1:-sagetv-u26-test}"
APPDATA="${2:-/mnt/user/appdata/sagetv-u26-test}"
SERVER="$APPDATA/server"
OUT="$SERVER/sagetv_abort_debug.txt"
mkdir -p "$SERVER"
{
  echo "===== DATE ====="; date -Is; echo
  echo "===== CONTAINER STATE ====="
  docker container inspect "$CONTAINER" --format 'Status={{.State.Status}} Running={{.State.Running}} ExitCode={{.State.ExitCode}} OOMKilled={{.State.OOMKilled}} RestartCount={{.RestartCount}} RestartPolicy={{.HostConfig.RestartPolicy.Name}} Error={{.State.Error}} StartedAt={{.State.StartedAt}} FinishedAt={{.State.FinishedAt}}' 2>&1 || true
  echo
  echo "===== CURRENT MIM / FFMPEG PROCESSES ====="
  docker exec "$CONTAINER" bash -lc 'ps -eo pid,ppid,pgid,sid,stat,etime,cmd | grep -E "[f]fmpeg(_MIM|\.real)?|[S]ageTVTranscoder"' 2>&1 || true
  echo
  echo "===== LAST CONTAINER LOG ====="
  docker logs --tail 400 "$CONTAINER" 2>&1 || true
  echo
  echo "===== HOTSPOT / NATIVE CRASH FILES ====="
  find "$APPDATA" -maxdepth 4 -type f \( -name 'hs_err_pid*.log' -o -name 'replay_pid*.log' -o -name 'core' -o -name 'core.*' \) -print -exec sh -c 'echo "--- $1 ---"; tail -200 "$1" 2>/dev/null || true' _ {} \; 2>&1 || true
  echo
  echo "===== SAGETV LOG TAIL ====="
  tail -300 "$SERVER/sagetv_0.txt" 2>&1 || tail -300 "$SERVER/sagetv_0.log" 2>&1 || true
  echo
  echo "===== FFMPEG.REAL LOG TAIL ====="
  tail -300 "$SERVER/ffmpeg.real.log" 2>&1 || true
  echo
  echo "===== HOST KERNEL OOM/FAULT HINTS ====="
  dmesg 2>&1 | grep -Ei 'oom|out of memory|segfault|general protection|trap|i915|drm|java' | tail -200 || true
} >"$OUT" 2>&1
chmod 666 "$OUT" 2>/dev/null || true
echo "Wrote: $OUT"
