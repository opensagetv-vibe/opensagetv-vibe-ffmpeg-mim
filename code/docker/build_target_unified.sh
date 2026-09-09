#!/usr/bin/env bash
set -euo pipefail

TARGET_ID="${1:?target id required: linux-x64|windows-x64}"
PROJECT=/project
# shellcheck disable=SC1091
source "$PROJECT/settings.ini"

if [[ "${SAGETV_FFMPEG_TAG:-}" != "$FFMPEG_TAG" ]]; then
  echo "ERROR: unified image FFmpeg tag '${SAGETV_FFMPEG_TAG:-unset}' does not match $FFMPEG_TAG" >&2
  exit 1
fi
if [[ "${SAGETV_FFMPEG_COMMIT:-}" != "$FFMPEG_COMMIT" ]]; then
  echo "ERROR: unified image FFmpeg commit '${SAGETV_FFMPEG_COMMIT:-unset}' does not match $FFMPEG_COMMIT" >&2
  exit 1
fi

case "$TARGET_ID" in
  linux-x64)
    OUT="$PROJECT/output/linux-x64"
    FFMPEG_BIN=ffmpeg
    FFPROBE_BIN=ffprobe
    REAL_NAME=ffmpeg.real
    PROBE_NAME=ffprobe
    MIM_NAME=ffmpeg_MIM
    # Match BtbN's Linux portability model: FFmpeg/dependencies are static, while
    # glibc remains a normal runtime system dependency. Keep libgcc/libstdc++ local.
    MIM_FLAGS=(-std=c++17 -O2 -pipe -pthread -static-libgcc -static-libstdc++ -s)
    ;;
  windows-x64)
    OUT="$PROJECT/output/windows-x64"
    FFMPEG_BIN=ffmpeg.exe
    FFPROBE_BIN=ffprobe.exe
    REAL_NAME=ffmpeg.real.exe
    PROBE_NAME=ffprobe.exe
    MIM_NAME=SageTVTranscoder.exe
    MIM_FLAGS=(-std=c++17 -O2 -pipe -pthread -static -static-libgcc -static-libstdc++ -s)
    ;;
  *) echo "ERROR: unknown target '$TARGET_ID'" >&2; exit 2 ;;
esac

rm -rf "$OUT"
mkdir -p "$OUT"
WORK="/work/$TARGET_ID"
SRC="$WORK/ffmpeg"
PREFIX="$WORK/prefix"
rm -rf "$WORK"
mkdir -p "$WORK" "$PREFIX"

# FFmpeg source is cached inside the reusable builder image. A normal build does
# not clone/download FFmpeg again.
cp -a /opt/sagetv/src/ffmpeg "$SRC"
if [[ -d "$SRC/.git" ]]; then
  git -C "$SRC" reset --hard "$FFMPEG_TAG" >/dev/null
  git -C "$SRC" clean -fdx >/dev/null
fi

python3 "$PROJECT/code/tools/apply_videorateadapt.py" \
  "$SRC" --compat-dir "$PROJECT/code/compat"

cd "$SRC"
cc_command="${CC:-cc}"
cxx_command="${CXX:-c++}"
cc_args=("$cc_command")
cxx_args=("$cxx_command")
if command -v ccache >/dev/null 2>&1; then
  ccache --max-size "${CCACHE_MAXSIZE:-20G}" >/dev/null
  cc_args=(ccache "$cc_command")
  cxx_args=(ccache "$cxx_command")
fi
echo "================================================================"
echo "SageTV FFmpeg/MIM unified build"
echo "Target      : $TARGET_ID"
echo "FFmpeg tag  : $FFMPEG_TAG"
echo "Compiler    : ${CC:-unset} / ${CXX:-unset}"
echo "Compiler cache: $(command -v ccache 2>/dev/null || echo disabled)"
echo "================================================================"

# Use the exact configure environment captured from the corresponding actual
# BtbN FFmpeg-Builds target image.
# shellcheck disable=SC2086
./configure \
  --prefix="$PREFIX" \
  --pkg-config-flags="--static" \
  ${FFBUILD_TARGET_FLAGS:-} ${FF_CONFIGURE:-} \
  --extra-cflags="${FF_CFLAGS:-${CFLAGS:-}}" \
  --extra-cxxflags="${FF_CXXFLAGS:-${CXXFLAGS:-${CFLAGS:-}}}" \
  --extra-libs="${FF_LIBS:-}" \
  --extra-ldflags="${FF_LDFLAGS:-${LDFLAGS:-}}" \
  --extra-ldexeflags="${FF_LDEXEFLAGS:-}" \
  --cc="${cc_args[*]}" \
  --cxx="${cxx_args[*]}" \
  --ar="${AR:-ar}" \
  --ranlib="${RANLIB:-ranlib}" \
  --nm="${NM:-nm}" \
  --extra-version="sagetv-mim-v0.4.8" \
  || { cat ffbuild/config.log; exit 1; }

JOBS="${BUILD_JOBS:-0}"
if [[ "$JOBS" == 0 ]]; then JOBS="$(nproc)"; fi
make -j"$JOBS"
make install

[[ -f "$PREFIX/bin/$FFMPEG_BIN" ]] || { echo "ERROR: $FFMPEG_BIN was not created" >&2; exit 1; }
[[ -f "$PREFIX/bin/$FFPROBE_BIN" ]] || { echo "ERROR: $FFPROBE_BIN was not created" >&2; exit 1; }

cp "$PREFIX/bin/$FFMPEG_BIN" "$OUT/$REAL_NAME"
cp "$PREFIX/bin/$FFPROBE_BIN" "$OUT/$PROBE_NAME"

# Do not package a binary if the SageTV runtime-rate-control option was lost
# during an FFmpeg/BtbN update.  The option name is embedded in the binary on
# both native Linux and cross-compiled Windows targets.
if ! grep -a -q 'sagetvratectrl' "$OUT/$REAL_NAME"; then
  echo "ERROR: $REAL_NAME does not contain the SageTV -sagetvratectrl patch marker" >&2
  exit 1
fi
cp "$PROJECT/ffmpeg.real.ini" "$OUT/ffmpeg.real.ini"
if [[ "$TARGET_ID" == linux-x64 ]]; then
  cp "$PROJECT/ffmpeg_init.sh" "$OUT/ffmpeg_init.sh"
  cp "$PROJECT/diagnose_miniplayer.sh" "$OUT/diagnose_miniplayer.sh"
  cp "$PROJECT/diagnose_sagetv_abort.sh" "$OUT/diagnose_sagetv_abort.sh"
fi

"${cxx_args[@]}" "${MIM_FLAGS[@]}" \
  "$PROJECT/code/mim/sagetv_ffmpeg_mim.cpp" \
  -o "$OUT/$MIM_NAME"

if [[ "$TARGET_ID" == linux-x64 ]]; then
  chmod 777 "$OUT/$MIM_NAME" "$OUT/$REAL_NAME" "$OUT/$PROBE_NAME" "$OUT/ffmpeg_init.sh" "$OUT/diagnose_miniplayer.sh" "$OUT/diagnose_sagetv_abort.sh"
else
  chmod 777 "$OUT/$MIM_NAME" "$OUT/$REAL_NAME" "$OUT/$PROBE_NAME" 2>/dev/null || true
fi

{
  echo "SageTV FFmpeg MIM v0.4.8"
  echo "build_environment=${OPENSAGETV_VIBE_BUILD_ENV_VERSION:-unknown}"
  echo "ffmpeg_toolchain=${OPENSAGETV_VIBE_FFMPEG_TOOLCHAIN:-unknown}"
  echo "target=$TARGET_ID"
  echo "ffmpeg_tag=$FFMPEG_TAG"
  echo "ffmpeg_commit=$FFMPEG_COMMIT"
  echo "cc=${CC:-}"
  echo "cxx=${CXX:-}"
  echo
  echo "Hardware encoder configuration:"
  grep -E '^CONFIG_(H264|HEVC)_(QSV|NVENC|VAAPI|AMF|D3D12VA)_ENCODER=yes$' ffbuild/config.mak || true
  echo
  echo "Hardware acceleration configuration:"
  grep -E '^CONFIG_(QSV|VAAPI|NVENC|NVDEC|CUVID|D3D11VA|D3D12VA|DXVA2|VULKAN|AMF)=yes$' ffbuild/config.mak || true
  echo
  file "$OUT/$MIM_NAME" "$OUT/$REAL_NAME" "$OUT/$PROBE_NAME" || true
} > "$OUT/build_report.txt" 2>&1

if [[ "$TARGET_ID" == linux-x64 ]]; then
  {
    echo
    echo "MIM runtime dependencies:"
    ldd "$OUT/$MIM_NAME" || true
    echo
    echo "FFmpeg runtime dependencies:"
    ldd "$OUT/$REAL_NAME" || true
  } >> "$OUT/build_report.txt" 2>&1
  "$OUT/$REAL_NAME" -hide_banner -encoders 2>/dev/null | \
    grep -E 'h264_(qsv|nvenc|vaapi|amf|d3d12va)|hevc_(qsv|nvenc|vaapi|amf|d3d12va)' \
    > "$OUT/hardware_encoders.txt" || true
else
  objdump_bin="${FFBUILD_CROSS_PREFIX:-}objdump"
  if command -v "$objdump_bin" >/dev/null 2>&1; then
    {
      echo
      echo "MIM imported DLLs:"
      "$objdump_bin" -p "$OUT/$MIM_NAME" | grep 'DLL Name:' || true
      echo
      echo "FFmpeg imported DLLs:"
      "$objdump_bin" -p "$OUT/$REAL_NAME" | grep 'DLL Name:' || true
    } >> "$OUT/build_report.txt"
  fi
fi

(
  cd "$OUT"
  if [[ "$TARGET_ID" == linux-x64 ]]; then
    sha256sum "$MIM_NAME" "$REAL_NAME" "$PROBE_NAME" ffmpeg.real.ini ffmpeg_init.sh diagnose_miniplayer.sh diagnose_sagetv_abort.sh build_report.txt > SHA256SUMS.txt
  else
    sha256sum "$MIM_NAME" "$REAL_NAME" "$PROBE_NAME" ffmpeg.real.ini build_report.txt > SHA256SUMS.txt
  fi
)

echo "[SUCCESS] $TARGET_ID -> $OUT"
if command -v ccache >/dev/null 2>&1; then
  ccache --show-stats
fi
