#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"

for f in "$ROOT"/*.sh "$ROOT"/code/docker/*.sh "$ROOT"/code/mim/tests/*.sh; do
  bash -n "$f"
done
python3 -m py_compile "$ROOT/code/tools/apply_videorateadapt.py"
if command -v g++ >/dev/null 2>&1; then
  g++ -std=c++17 -fsyntax-only "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp"
fi

test -x "$ROOT/build_opensagetv_vibe_builder_image.sh"
test -x "$ROOT/cleanup_old_opensagetv_vibe_build_images.sh"
grep -q 'opensagetv-vibe-ffmpeg-mim-builder:9.0.1-v5' \
  "$ROOT/build_opensagetv_vibe_builder_image.sh"

grep -q 'opensagetv-vibe-ffmpeg-mim-builder:9.0.1-v5' "$ROOT/settings.ini"

grep -q '^SAGETV_BUILDER_CONTAINER=opensagetv-vibe-ffmpeg-mim-builder$' "$ROOT/settings.ini"
grep -q -- '--name "$CONTAINER"' "$ROOT/code/docker/run_unified_builder.sh"
grep -q '"$IMAGE" "$MODE"' "$ROOT/code/docker/run_unified_builder.sh"
! grep -q 'build_opensagetv_vibe_builder_image.sh' "$ROOT/code/docker/run_unified_builder.sh"
if grep -Eq 'sagetv-ffmpeg-build-(linux|windows)' "$ROOT/code/docker/run_unified_builder.sh"; then
  echo "ERROR: target-specific runtime container names are not allowed" >&2
  exit 1
fi
grep -q 'BTBN_LINUX_IMAGE' "$ROOT/docker/Dockerfile"
grep -q 'BTBN_WIN64_IMAGE' "$ROOT/docker/Dockerfile"
grep -q 'linux-x64 windows-x64' <(tr '\n' ' ' < "$ROOT/code/docker/unified_entrypoint.sh") || true

# x86/Win32 must not be an active build target. Legacy cleanup script is excluded
# because it intentionally removes old Win32 image tags from previous versions.
for f in \
  "$ROOT/settings.ini" \
  "$ROOT/docker/Dockerfile" \
  "$ROOT/code/docker/unified_entrypoint.sh" \
  "$ROOT/code/docker/build_target_unified.sh" \
  "$ROOT/ffmpeg.real.ini"; do
  if grep -Eqi 'windows-x86|windows_x86|base-win32|targets/win32|btbn_win32|BUILD_WINDOWS_X86|BTBN_WIN32' "$f"; then
    echo "ERROR: stale x86/Win32 build reference in $f" >&2
    exit 1
  fi
done

! grep -q 'windows-x86' "$ROOT/docs/BUILD_MATRIX.md"
! grep -q 'output/windows-x86' "$ROOT/README.md"


# Deployment naming/init requirements.
grep -q 'MIM_NAME=ffmpeg_MIM' "$ROOT/code/docker/build_target_unified.sh"
grep -q 'MIM_NAME=SageTVTranscoder.exe' "$ROOT/code/docker/build_target_unified.sh"
! grep -q 'MIM_NAME=ffmpeg_MIM.exe' "$ROOT/code/docker/build_target_unified.sh"
grep -q 'ffmpeg_init.sh' "$ROOT/code/docker/build_target_unified.sh"
grep -q 'chmod 777 -- "$exe"' "$ROOT/ffmpeg_init.sh"
bash -n "$ROOT/ffmpeg_init.sh"

grep -q 'cp "$PROJECT/ffmpeg_init.sh" "$OUT/ffmpeg_init.sh"' "$ROOT/code/docker/build_target_unified.sh"
grep -q 'cp "$PROJECT/diagnose_miniplayer.sh" "$OUT/diagnose_miniplayer.sh"' "$ROOT/code/docker/build_target_unified.sh"
grep -q 'cp "$PROJECT/diagnose_sagetv_abort.sh" "$OUT/diagnose_sagetv_abort.sh"' "$ROOT/code/docker/build_target_unified.sh"
grep -q 'MIM_NAME=SageTVTranscoder.exe' "$ROOT/code/docker/build_target_unified.sh"


# Runtime Docker checks belong to the separate opensagetv-vibe-container project.
# This repository validates only FFmpeg/MIM source, configuration, and output.

# v0.4.5 keeps containment and closes MiniPlayer switch teardown paths.
grep -q 'MIM_VERSION = "0.4.5"' "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp"
grep -q 'qsv:hw,child_device=' "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp"
grep -q 'hardware_encode_preflight' "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp"
grep -q '^preflight_hardware_encode=true$' "$ROOT/ffmpeg.real.ini"
grep -q 'probe-cache BYPASS active input=' "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp"
grep -q 'yadif_cuda=deint=interlaced' "$ROOT/ffmpeg.real.ini"
grep -q 'format=nv12,hwupload' "$ROOT/ffmpeg.real.ini"
grep -q 'preserve_sagetv_output_contract' "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp"
grep -q '^preserve_sagetv_output_contract=true$' "$ROOT/ffmpeg.real.ini"
grep -q 'const bool hardware_decode=' "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp"

grep -q '^isolate_child_process=true$' "$ROOT/ffmpeg.real.ini"
grep -q '^terminate_grace_ms=2000$' "$ROOT/ffmpeg.real.ini"
grep -q '^clean_exit_on_ffmpeg_failure=true$' "$ROOT/ffmpeg.real.ini"
grep -q 'setpgid(0,0)' "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp"
grep -q 'kill(-pid,sig)' "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp"
grep -q 'containing EPIPE' "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp"
grep -q 'contained ffmpeg failure' "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp"
grep -q 'PR_SET_PDEATHSIG,SIGKILL' "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp"
grep -q 'handle_parent_stdin_closed("stdin EOF")' "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp"
grep -q 'handle_parent_stdin_closed("stdin HUP")' "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp"
grep -q 'control: parent signal=' "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp"

grep -q 'has_flag(a,"-dumpmetadata")' "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp"
grep -q 'compat: SageTV -dumpmetadata' "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp"
grep -q 'ffmpeg_transcode_loglevel=error' "$ROOT/ffmpeg.real.ini"
grep -q 'ffmpeg-stderr:' "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp"
grep -q '^file=./ffmpeg.real.log$' "$ROOT/ffmpeg.real.ini"
grep -q 'log_name="./ffmpeg.real.log"' "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp"
grep -q 'remove_opt_value(a,{"-vsync","-fps_mode"})' "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp"
grep -q "does not contain the SageTV -sagetvratectrl patch marker" "$ROOT/code/docker/build_target_unified.sh"

echo '[PASS] v0.4.5 FFmpeg/MIM static validation'
