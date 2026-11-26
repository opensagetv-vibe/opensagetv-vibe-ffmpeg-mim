#!/usr/bin/env bash
# Use only the existing unified toolchains; preserve qualified FFmpeg engines.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
for path in output/linux-x64/ffmpeg.real output/linux-x64/ffprobe output/windows-x64/ffmpeg.real.exe output/windows-x64/ffprobe.exe; do
  test -s "$ROOT/$path" || { echo "Missing qualified engine: $path" >&2; exit 2; }
done
before="$(cd "$ROOT" && sha256sum output/linux-x64/ffmpeg.real output/linux-x64/ffprobe output/windows-x64/ffmpeg.real.exe output/windows-x64/ffprobe.exe)"
g++ -std=c++17 -O2 -pipe -pthread -static -s "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp" -o "$ROOT/output/linux-x64/ffmpeg_MIM"
cross=/opt/sagetv/targets/win64/ct-ng/bin/x86_64-w64-mingw32-g++
test -x "$cross" || { echo 'Existing unified Windows compiler required' >&2; exit 2; }
"$cross" -std=c++17 -O2 -pipe -pthread -static -static-libgcc -static-libstdc++ -s "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp" -o "$ROOT/output/windows-x64/SageTVTranscoder.exe"
after="$(cd "$ROOT" && sha256sum output/linux-x64/ffmpeg.real output/linux-x64/ffprobe output/windows-x64/ffmpeg.real.exe output/windows-x64/ffprobe.exe)"
test "$before" = "$after" || { echo 'Qualified engine changed' >&2; exit 3; }
"$ROOT/output/linux-x64/ffmpeg_MIM" --mim-version
sha256sum "$ROOT/output/linux-x64/ffmpeg_MIM" "$ROOT/output/windows-x64/SageTVTranscoder.exe"
echo 'PASS both wrappers rebuilt; all four qualified engines unchanged'
