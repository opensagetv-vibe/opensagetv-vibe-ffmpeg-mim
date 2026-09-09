#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
OUT="$ROOT/output/linux-x64"

mkdir -p "$OUT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
MIM="$TMP/ffmpeg"
CXX_BIN="${CXX:-g++}"
"$CXX_BIN" -std=c++17 -O2 -pipe -pthread -static -s \
  "$ROOT/code/mim/sagetv_ffmpeg_mim.cpp" -o "$MIM"
cat > "$TMP/ffmpeg.real" <<'SH'
#!/usr/bin/env bash
if [[ " $* " == *" -encoders "* ]]; then
  if [[ "${MIM_TEST_SOFTWARE_ONLY:-0}" == 1 ]]; then
    echo ' V..... libx264'
    exit 0
  fi
  cat <<'EOT'
 V....D h264_qsv
 V....D hevc_qsv
 V....D h264_nvenc
 V....D hevc_nvenc
 V....D h264_vaapi
 V....D hevc_vaapi
 V..... libx264
 V..... libx265
EOT
  exit 0
fi
if [[ " $* " == *" -f lavfi "* && " $* " == *" -frames:v 1 "* ]]; then
  exit 0
fi
printf 'FAKE_FFMPEG_ARGS:'
printf ' <%s>' "$@"
printf '\n'
while IFS= read -r line; do printf 'FAKE_STDIN:<%s>\n' "$line"; done
SH
chmod +x "$TMP/ffmpeg.real"
cat > "$TMP/ffprobe" <<'SH'
#!/usr/bin/env bash
echo 'stream|index=0|codec_name=h264|codec_type=video|width=1920|height=1080|avg_frame_rate=30000/1001'
echo 'stream|index=1|codec_name=ac3|codec_type=audio'
echo 'format|format_name=mpegts'
SH
chmod +x "$TMP/ffprobe"
cp "$ROOT/ffmpeg.real.ini" "$TMP/ffmpeg.real.ini"
grep -q '^cached_probesize=524288$' "$TMP/ffmpeg.real.ini"
grep -q '^cached_analyzeduration=500000$' "$TMP/ffmpeg.real.ini"
grep -q '^cached_max_probe_packets=1024$' "$TMP/ffmpeg.real.ini"
# Force deterministic HW backend; explicit backend trusts the compiled encoder list.
sed -i 's/^backend=auto$/backend=qsv/' "$TMP/ffmpeg.real.ini"
# These fixtures replace ffmpeg.real repeatedly with processes that exist only
# to exercise stdin control and process-group teardown.  Hardware preflight has
# separate coverage below; running it here would consume the lifecycle timeout
# before the process under test is started.
sed -i 's/^preflight_hardware_encode=true$/preflight_hardware_encode=false/' "$TMP/ffmpeg.real.ini"
# Control/teardown tests use a one-byte synthetic TS with no video headers.
# The active-video readiness gate has its own integration coverage and would
# intentionally delay launching the fake child used by these unit tests.
sed -i 's/^video_ready_gate=true$/video_ready_gate=false/' "$TMP/ffmpeg.real.ini"
mkdir -p "$TMP/media"
printf '\x47' > "$TMP/media/test.ts"

v="$($TMP/ffmpeg --mim-version)"
[[ "$v" == *"SageTV FFmpeg MIM 0.4.8"* ]]
c="$($TMP/ffmpeg --mim-capabilities)"
[[ "$c" == *'"mimVersion":"0.4.8"'* ]]
[[ "$c" == *'"dvdStreamTransform":true'* ]]
s="$($TMP/ffmpeg --mim-status)"
[[ "$s" == *'"activeJobs":[]'* ]]
[[ "$s" == *'"lastJob":null'* ]]
[[ "$s" == *'"lastTranscodeJob":null'* ]]

# Management command must be untouched.
d="$($TMP/ffmpeg --mim-dry-run -version)"
[[ "$d" == *"ffmpeg.real -version"* ]]
d="$($TMP/ffmpeg --mim-dry-run --version)"
[[ "$d" == *"ffmpeg.real -version"* ]]
[[ "$d" != *" --version"* ]]
[[ "$d" != *"probesize"* ]]

# SageTV-specific -dumpmetadata must be translated for modern FFmpeg rather
# than passed through as an unknown option.  SageTV intentionally requests
# -v 2, so MIM forces info logging to expose Input/Duration/Stream lines.
d="$($TMP/ffmpeg --mim-dry-run -dumpmetadata -v 2 -i "$TMP/media/test.ts")"
[[ "$d" == *"backend=metadata"* ]]
[[ "$d" != *"-dumpmetadata"* ]]
[[ "$d" == *"-loglevel info"* ]]
[[ "$d" == *"-i $TMP/media/test.ts"* ]]
[[ -f "$TMP/ffmpeg.real.log" ]]
grep -q 'mim-start version=0.4.8' "$TMP/ffmpeg.real.log"

# SageTV's private thumbnail frame-selection switches were removed upstream.
# MIM must drop their option/value pairs while preserving the ordinary MJPEG
# thumbnail command on modern FFmpeg.
d="$($TMP/ffmpeg --mim-dry-run -y -skip_frame nokey -i "$TMP/media/test.ts" -f mjpeg -deinterlace -vf crop=0:8:0:0,scale=512:288 -vframes 1 -an -minpixvar 300 -minpixnumframes 150 -vsync 0 "$TMP/thumb.jpg")"
[[ "$d" == *"backend=passthrough"* ]]
[[ "$d" != *"minpixvar"* ]]
[[ "$d" != *"minpixnumframes"* ]]
[[ "$d" != *"-vsync"* ]]
[[ "$d" != *"-deinterlace"* ]]
[[ "$d" == *"-fps_mode passthrough"* ]]
[[ "$d" == *"-vf yadif,crop=iw:ih-8:0:8,scale=512:288"* ]]
[[ "$d" == *"-f mjpeg"* ]]
[[ "$d" == *"-vframes 1"* ]]
d="$($TMP/ffmpeg --mim-dry-run -y -i "$TMP/media/test.ts" -f mjpeg -vframes 1 -an -minpixenergy 1 -vsync 0 "$TMP/thumb-fallback.jpg")"
[[ "$d" != *"minpixenergy"* ]]
[[ "$d" != *"-vsync"* ]]
[[ "$d" == *"-fps_mode passthrough"* ]]
[[ "$d" == *"$TMP/thumb-fallback.jpg"* ]]
grep -q 'compat: removed obsolete SageTV thumbnail frame-selection options' "$TMP/ffmpeg.real.log"
grep -q 'compat: translated legacy -vsync to -fps_mode passthrough' "$TMP/ffmpeg.real.log"
grep -q 'compat: translated legacy thumbnail -deinterlace to yadif' "$TMP/ffmpeg.real.log"
grep -q 'compat: translated legacy SageTV thumbnail crop order' "$TMP/ffmpeg.real.log"

# The explicit DISC stream marker makes a VM-produced MPEG-PS pipe a SageTV
# transcode job without sharing stdin with -stdinctrl. Input and output -f
# options must remain on their respective sides of -i.
d="$("$TMP/ffmpeg" --mim-dry-run -sagetvdiscstream -f mpeg -i - -map 0:v:0 -map '0:a?' -map '0:s?' -vcodec mpeg4 -acodec copy -c:s dvbsub -f mpegts -)"
[[ "$d" == *"backend=qsv"* ]]
[[ "$d" != *"-sagetvdiscstream"* ]]
[[ "$d" == *"-f mpeg "* ]]
[[ "$d" == *"-i -"* ]]
[[ "$d" == *"-f mpegts -"* ]]
[[ "$d" == *"-c:v h264_qsv"* ]]
[[ "$d" == *"-c:s dvbsub"* ]]

# A normal non-SageTV encode command remains transparent even if it uses a mapped codec.
d="$($TMP/ffmpeg --mim-dry-run -i "$TMP/media/test.ts" -c:v libx264 -f null -)"
[[ "$d" == *"backend=passthrough"* ]]
[[ "$d" == *"-c:v libx264"* ]]
[[ "$d" != *"h264_qsv"* ]]

# Growing live inputs use caption-preserving software decode with QSV filtering
# and encoding. This avoids the unstable growing-file QSV decoder without
# falling back to CPU encoding.
d="$($TMP/ffmpeg --mim-dry-run -stdinctrl -activefile -vsync 0 -async 1 -i "$TMP/media/test.ts" -vcodec mpeg4 -b 4000k -g 300 -bf 2 -rc_init_cplx 197 -minrate 0 -mbd 2 -muxrate 8000000 -f mpegts -)"
[[ "$d" == *"backend=qsv"* ]]
[[ "$d" == *"-sagetvratectrl"* ]]
[[ "$d" == *"-follow 1"* ]]
[[ "$d" == *"-probesize 5000000"* ]]
[[ "$d" == *"-analyzeduration 5000000"* ]]
[[ "$d" != *"-activefile"* ]]
[[ "$d" != *"-stdinctrl"* ]]
[[ "$d" == *"-c:v h264_qsv"* ]]
[[ "$d" != *"-vsync"* ]]
[[ "$d" != *"-async"* ]]
[[ "$d" != *"-rc_init_cplx"* ]]
[[ "$d" != *"-minrate"* ]]
[[ "$d" != *"-mbd"* ]]
[[ "$d" != *"-muxrate"* ]]
[[ "$d" == *"-b:v 4000k"* ]]
# QSV encode needs the device, but caption-safe software decode must not use
# the QSV decoder/hwaccel input path.
[[ "$d" == *"-init_hw_device qsv:hw,child_device=/dev/dri/renderD128"* ]]
[[ "$d" != *"-hwaccel qsv"* ]]
[[ "$d" == *"-vf yadif=deint=interlaced,format=nv12"* ]]
[[ "$d" != *"hwupload"* ]]
[[ "$d" != *"scale_qsv"* ]]
[[ "$d" == *"-bf 0"* ]]
[[ "$d" == *"-g 60"* ]]
[[ "$d" == *"-flush_packets 1"* ]]
[[ "$d" == *"-mpegts_flags +initial_discontinuity+resend_headers"* ]]
[[ "$d" == *"-a53cc 1"* ]]
[[ "$d" == *"-maxrate 6M"* ]]
[[ "$d" == *"-bufsize 12M"* ]]


# Regression from live MiniPlayer fixed-push failure: SageTV explicitly requested
# Matroska + MP2 mono.  Hardware mapping may replace only the video encoder; it
# must not silently change the wire contract to MPEG-TS + copied AC3.
d="$($TMP/ffmpeg --mim-dry-run -v 3 -y -threads 2 -sn -vsync 0 -async 1 -stdinctrl -i "$TMP/media/test.ts" -threads 5 -f matroska -vcodec mpeg4 -b 1000000 -r 29.97 -s 720x480 -g 300 -bf 0 -acodec mp2 -ab 112000 -ar 48000 -ac 1 -packetsize 1024 -aspect 16:9 -muxrate 2000000 -rc_init_cplx 197 -maxrate 1000000 -minrate 0 -bufsize 1000000 -mbd 2 -)"
[[ "$d" == *"backend=qsv"* ]]
[[ "$d" == *"-c:v h264_qsv"* ]]
[[ "$d" == *"-f matroska"* ]]
[[ "$d" == *"-acodec mp2"* ]]
[[ "$d" == *"-ab 112000"* ]]
[[ "$d" == *"-ar 48000"* ]]
[[ "$d" == *"-ac 1"* ]]
[[ "$d" != *"-c:a copy"* ]]
[[ "$d" != *"-mpegts_flags"* ]]
[[ "$d" != *"-muxpreload"* ]]
[[ "$d" != *"-muxdelay"* ]]

# Current SageTV Core still spells its AAC request as the removed libfaac
# encoder. MIM must retain AAC on the wire but use modern FFmpeg's native name.
d="$($TMP/ffmpeg --mim-dry-run -stdinctrl -i "$TMP/media/test.ts" -f mpegts -vcodec mpeg4 -b 4000000 -acodec libfaac -ab 128000 -ar 48000 -ac 2 -)"
[[ "$d" == *"-c:a aac"* ]]
[[ "$d" != *"libfaac"* ]]
[[ "$d" == *"-ab 128000"* ]]
[[ "$d" == *"-ar 48000"* ]]
[[ "$d" == *"-ac 2"* ]]

# Completed MPEG-TS seeks must preserve SageTV's exact requested time by
# default. A hidden five-second preroll caused the SageTV timeline and A/53
# captions to lag the generated video's visible clock by approximately five
# seconds even though standalone playback of the source was synchronized.
d="$($TMP/ffmpeg --mim-dry-run -ss 120 -stdinctrl -i "$TMP/media/test.ts" -f mpegts -vcodec mpeg4 -b 4000000 -acodec aac -)"
[[ "$d" == *"-ss 120"* ]]
[[ "$d" == *"-i $TMP/media/test.ts"* ]]
[[ "$d" != *"-ss 115"* ]]
[[ "$d" != *"-ss 5"* ]]
[[ "$d" == *"-mpegts_flags +initial_discontinuity+resend_headers"* ]]

# Retain the old preroll only as an explicit compatibility option for a known
# decoder/GPU that cannot start at the requested point.
cp "$TMP/ffmpeg.real.ini" "$TMP/ffmpeg.preroll.ini"
sed -i 's/^completed_mpegts_preroll=false$/completed_mpegts_preroll=true/' "$TMP/ffmpeg.preroll.ini"
d="$(SAGETV_FFMPEG_MIM_INI="$TMP/ffmpeg.preroll.ini" "$TMP/ffmpeg" --mim-dry-run -ss 120 -stdinctrl -i "$TMP/media/test.ts" -f mpegts -vcodec mpeg4 -b 4000000 -acodec aac -)"
[[ "$d" == *"-ss 115"* ]]
[[ "$d" == *"-ss 5"* ]]

# Growing files must not receive completed-file seek rewriting.
d="$($TMP/ffmpeg --mim-dry-run -ss 120 -stdinctrl -activefile -i "$TMP/media/test.ts" -f mpegts -vcodec mpeg4 -b 4000000 -acodec aac -)"
[[ "$d" == *"-ss 120"* ]]
[[ "$d" != *"-ss 115"* ]]

# Native H.264 software request maps to H.264 hardware.
d="$($TMP/ffmpeg --mim-dry-run -stdinctrl -i "$TMP/media/test.ts" -c:v libx264 -b:v 2M -f mpegts -)"
[[ "$d" == *"backend=qsv"* ]]
[[ "$d" == *"-c:v h264_qsv"* ]]

# Native HEVC software request maps to HEVC hardware, not H.264.
d="$($TMP/ffmpeg --mim-dry-run -stdinctrl -i "$TMP/media/test.ts" -c:v libx265 -b:v 2M -f mpegts -)"
[[ "$d" == *"backend=qsv"* ]]
[[ "$d" == *"-c:v hevc_qsv"* ]]

# Local stv:// must map to a local file path.
d="$($TMP/ffmpeg --mim-dry-run -stdinctrl -i stv://localhost//tmp/example.ts -vcodec mpeg4 -b 1M -f mpegts -)"
[[ "$d" == *"-i /tmp/example.ts"* ]]
[[ "$d" == *"-c:v h264_qsv"* ]]

# Recognized SageTV media job with no software-transcode trigger defaults to full stream copy.
d="$($TMP/ffmpeg --mim-dry-run -stdinctrl -i "$TMP/media/test.ts" -c:v copy -c:a copy -f mpegts -)"
[[ "$d" == *"backend=copy"* ]]
[[ "$d" == *"-c:v copy"* ]]
[[ "$d" == *"-c:a copy"* ]]
[[ "$d" != *"-sagetvratectrl"* ]]
[[ "$d" != *"-probesize"* ]]

# Even if SageTV supplied old encode tuning without a mapped video encoder request,
# copy policy strips encode/filter-only options rather than accidentally transcoding.
d="$($TMP/ffmpeg --mim-dry-run -stdinctrl -i "$TMP/media/test.ts" -b:v 3M -g 250 -bf 2 -vf scale=1280:720 -f mpegts -)"
[[ "$d" == *"backend=copy"* ]]
[[ "$d" == *"-c:v copy"* ]]
[[ "$d" == *"-c:a copy"* ]]
[[ "$d" != *"-b:v 3M"* ]]
[[ "$d" != *"-g 250"* ]]
[[ "$d" != *"-bf 2"* ]]
[[ "$d" != *"-vf"* ]]

# Caption preservation deliberately keeps GPU filtering/encoding but decodes in
# software because hardware MPEG-2 decode can drop A/53 frame side data.
cp "$ROOT/ffmpeg.real.ini" "$TMP/ffmpeg.hwdecode.ini"
sed -i 's/^backend=auto$/backend=qsv/' "$TMP/ffmpeg.hwdecode.ini"
sed -i 's/^hardware_decode=false$/hardware_decode=true/' "$TMP/ffmpeg.hwdecode.ini"
d="$(SAGETV_FFMPEG_MIM_INI="$TMP/ffmpeg.hwdecode.ini" "$TMP/ffmpeg" --mim-dry-run -stdinctrl -i "$TMP/media/test.ts" -vcodec mpeg4 -s 1280x720 -b 4M -f mpegts -)"
[[ "$d" == *"-init_hw_device qsv:hw,child_device=/dev/dri/renderD128"* ]]
[[ "$d" != *"-hwaccel qsv"* ]]
[[ "$d" != *"-hwaccel_device hw"* ]]
[[ "$d" != *"-hwaccel_output_format qsv"* ]]
[[ "$d" == *"-vf yadif=deint=interlaced,scale=w=1280:h=720,format=nv12"* ]]
[[ "$d" != *"hwupload"* ]]
[[ "$d" != *"scale_qsv"* ]]
[[ "$d" != *"-s 1280x720"* ]]

# Operators may explicitly disable the cross-vendor caption decode policy for
# full GPU decode validation. That path remains available and uses
# hardware-native filters.
sed -i 's/^caption_software_decode=true$/caption_software_decode=false/' "$TMP/ffmpeg.hwdecode.ini"
d="$(SAGETV_FFMPEG_MIM_INI="$TMP/ffmpeg.hwdecode.ini" "$TMP/ffmpeg" --mim-dry-run -stdinctrl -i "$TMP/media/test.ts" -vcodec mpeg4 -s 1280x720 -b 4M -f mpegts -)"
[[ "$d" == *"-hwaccel qsv"* ]]
[[ "$d" == *"-hwaccel_device hw"* ]]
[[ "$d" == *"-hwaccel_output_format qsv"* ]]
[[ "$d" == *"-vf deinterlace_qsv,scale_qsv=w=1280:h=720"* ]]

# NVENC retains GPU encode but defaults to caption-preserving software decode.
cp "$ROOT/ffmpeg.real.ini" "$TMP/ffmpeg.nvenc.ini"
sed -i 's/^backend=auto$/backend=nvenc/' "$TMP/ffmpeg.nvenc.ini"
sed -i 's/^hardware_decode=false$/hardware_decode=true/' "$TMP/ffmpeg.nvenc.ini"
d="$(SAGETV_FFMPEG_MIM_INI="$TMP/ffmpeg.nvenc.ini" "$TMP/ffmpeg" --mim-dry-run -stdinctrl -i "$TMP/media/test.ts" -vcodec mpeg4 -s 1280x720 -b 4M -f mpegts -)"
[[ "$d" == *"backend=nvenc"* ]]
[[ "$d" != *"-hwaccel cuda"* ]]
[[ "$d" == *"-c:v h264_nvenc"* ]]
[[ "$d" == *"-a53cc 1"* ]]

# With caption preservation explicitly disabled, NVDEC produces CUDA frames;
# hardware decode + scale must stay entirely on CUDA filters.
sed -i 's/^caption_software_decode=true$/caption_software_decode=false/' "$TMP/ffmpeg.nvenc.ini"
d="$(SAGETV_FFMPEG_MIM_INI="$TMP/ffmpeg.nvenc.ini" "$TMP/ffmpeg" --mim-dry-run -stdinctrl -i "$TMP/media/test.ts" -vcodec mpeg4 -s 1280x720 -b 4M -f mpegts -)"
[[ "$d" == *"-hwaccel cuda"* ]]
[[ "$d" == *"-hwaccel_output_format cuda"* ]]
[[ "$d" == *"-c:v h264_nvenc"* ]]
[[ "$d" == *"-vf yadif_cuda=deint=interlaced,scale_cuda=w=1280:h=720"* ]]
[[ "$d" != *"-s 1280x720"* ]]

# VAAPI encode after software decode needs a device plus format/upload chain.
# Merely selecting h264_vaapi with system-memory frames fails before video is
# emitted, which previously presented as audio-only playback.
cp "$ROOT/ffmpeg.real.ini" "$TMP/ffmpeg.vaapi-sw.ini"
sed -i 's/^backend=auto$/backend=vaapi/' "$TMP/ffmpeg.vaapi-sw.ini"
sed -i 's/^hardware_decode=true$/hardware_decode=false/' "$TMP/ffmpeg.vaapi-sw.ini"
d="$(SAGETV_FFMPEG_MIM_INI="$TMP/ffmpeg.vaapi-sw.ini" "$TMP/ffmpeg" --mim-dry-run -stdinctrl -i "$TMP/media/test.ts" -vcodec mpeg4 -s 1280x720 -b 4M -f mpegts -)"
[[ "$d" == *"backend=vaapi"* ]]
[[ "$d" == *"-vaapi_device /dev/dri/renderD128"* ]]
[[ "$d" != *"-hwaccel vaapi"* ]]
[[ "$d" == *"-c:v h264_vaapi"* ]]
[[ "$d" == *"-vf yadif=deint=interlaced,format=nv12,hwupload,scale_vaapi=w=1280:h=720"* ]]
[[ "$d" == *"-a53cc 1"* ]]
[[ "$d" != *"-s 1280x720"* ]]

# Full VAAPI decode keeps the filters and encoder on VAAPI frames.
cp "$ROOT/ffmpeg.real.ini" "$TMP/ffmpeg.vaapi-hw.ini"
sed -i 's/^backend=auto$/backend=vaapi/' "$TMP/ffmpeg.vaapi-hw.ini"
sed -i 's/^hardware_decode=false$/hardware_decode=true/' "$TMP/ffmpeg.vaapi-hw.ini"
sed -i 's/^caption_software_decode=true$/caption_software_decode=false/' "$TMP/ffmpeg.vaapi-hw.ini"
d="$(SAGETV_FFMPEG_MIM_INI="$TMP/ffmpeg.vaapi-hw.ini" "$TMP/ffmpeg" --mim-dry-run -stdinctrl -i "$TMP/media/test.ts" -vcodec mpeg4 -s 1280x720 -b 4M -f mpegts -)"
[[ "$d" == *"-hwaccel vaapi"* ]]
[[ "$d" == *"-hwaccel_device /dev/dri/renderD128"* ]]
[[ "$d" == *"-hwaccel_output_format vaapi"* ]]
[[ "$d" == *"-vf deinterlace_vaapi=auto=1,scale_vaapi=w=1280:h=720"* ]]
[[ "$d" != *"-s 1280x720"* ]]

# If a requested/explicit hardware encoder is not actually present in the
# bundled FFmpeg capabilities, select the matching software encoder rather
# than copying, passing through, or emitting a command that cannot start.
rm -rf "$TMP/cache/capabilities"
d="$(MIM_TEST_SOFTWARE_ONLY=1 "$TMP/ffmpeg" --mim-dry-run -stdinctrl -i "$TMP/media/test.ts" -vcodec mpeg4 -b 4M -f mpegts -)"
[[ "$d" == *"backend=software"* ]]
[[ "$d" == *"-c:v libx264"* ]]
[[ "$d" != *"-init_hw_device"* ]]
[[ "$d" != *"-hwaccel"* ]]
rm -rf "$TMP/cache/capabilities"

# Advertising a hardware encoder is insufficient: drivers can be installed
# while device/session initialization still fails.  A failed bounded preflight
# must fall back to software before SageTV starts a stream (the former failure
# mode produced audio-only or black-video playback).
mkdir -p "$TMP/preflight"
cp "$MIM" "$TMP/preflight/ffmpeg"
cp "$TMP/ffprobe" "$TMP/preflight/ffprobe"
cp "$ROOT/ffmpeg.real.ini" "$TMP/preflight/ffmpeg.real.ini"
sed -i 's/^backend=auto$/backend=qsv/' "$TMP/preflight/ffmpeg.real.ini"
cat > "$TMP/preflight/ffmpeg.real" <<'SH'
#!/usr/bin/env bash
if [[ " $* " == *" -encoders "* ]]; then
  printf ' V....D h264_qsv\n V..... libx264\n'
  exit 0
fi
if [[ " $* " == *" -f lavfi "* && " $* " == *" -frames:v 1 "* ]]; then
  echo 'simulated QSV session initialization failure' >&2
  exit 23
fi
exit 0
SH
chmod +x "$TMP/preflight/ffmpeg.real" "$TMP/preflight/ffprobe"
d="$("$TMP/preflight/ffmpeg" --mim-dry-run -stdinctrl -i "$TMP/media/test.ts" -vcodec mpeg4 -b 4M -f mpegts -)"
[[ "$d" == *"backend=software"* ]]
[[ "$d" == *"-c:v libx264"* ]]
[[ "$d" != *"h264_qsv"* ]]
grep -q 'hardware preflight failed backend=qsv encoder=h264_qsv rc=23' "$TMP/preflight/ffmpeg.real.log"

# Verify live SageTV control handling on an actual transcode:
# videorateadapt is forwarded; inactivefile terminates stock-follow child.
cat > "$TMP/ffmpeg.real" <<'SH'
#!/usr/bin/env bash
if [[ " $* " == *" -encoders "* ]]; then printf ' V....D h264_qsv\n V..... libx264\n'; exit 0; fi
trap 'echo CHILD_TERM; exit 0' TERM
touch "$MIM_TEST_DIR/control.ready"
while IFS= read -r line; do
  echo "CHILD_STDIN:$line"
  [[ "$line" == "videorateadapt -500" ]] && touch "$MIM_TEST_DIR/control.received"
done
SH
chmod +x "$TMP/ffmpeg.real"
rm -rf "$TMP/cache"
rm -f "$TMP/control.ready" "$TMP/control.received"
ctrl="$({
  for _ in {1..100}; do [[ -f "$TMP/control.ready" ]] && break; sleep .01; done
  printf 'videorateadapt -500\n'
  for _ in {1..100}; do [[ -f "$TMP/control.received" ]] && break; sleep .01; done
  if [[ ! -f "$TMP/control.received" ]]; then
    echo "ERROR: fake FFmpeg did not receive videorateadapt" >&2
    [[ -f "$TMP/ffmpeg.real.log" ]] && cat "$TMP/ffmpeg.real.log" >&2
    exit 1
  fi
  printf 'inactivefile\n'
} | MIM_TEST_DIR="$TMP" "$TMP/ffmpeg" -stdinctrl -activefile -i "$TMP/media/test.ts" -vcodec mpeg4 -b 4M -f mpegts - 2>&1)"
[[ "$ctrl" == *"CHILD_STDIN:videorateadapt -500"* ]]
[[ "$ctrl" == *"CHILD_TERM"* ]]

# v0.4.5 retains the crash containment: STOP must target the isolated FFmpeg process group,
# including helper descendants, without terminating the MIM/SageTV parent.
cat > "$TMP/ffmpeg.real" <<'SH'
#!/usr/bin/env bash
if [[ " $* " == *" -encoders "* ]]; then printf ' V....D h264_qsv\n V..... libx264\n'; exit 0; fi
trap 'touch "$MIM_TEST_DIR/direct.term"; exit 0' TERM
(
  trap 'touch "$MIM_TEST_DIR/descendant.term"; exit 0' TERM
  while :; do sleep 1; done
) &
while IFS= read -r line; do :; done
SH
chmod +x "$TMP/ffmpeg.real"
rm -f "$TMP/direct.term" "$TMP/descendant.term"
set +e
{ sleep .4; printf 'STOP\n'; } | MIM_TEST_DIR="$TMP" timeout 6 "$TMP/ffmpeg" -stdinctrl -i "$TMP/media/test.ts" -vcodec mpeg4 -b 4M -f mpegts - >/dev/null 2>&1
iso_rc=$?
set -e
[[ "$iso_rc" -eq 0 ]]
for _ in {1..30}; do
  [[ -f "$TMP/direct.term" && -f "$TMP/descendant.term" ]] && break
  sleep .05
done
[[ -f "$TMP/direct.term" ]]
[[ -f "$TMP/descendant.term" ]]
grep -q 'safety: ffmpeg child isolated' "$TMP/ffmpeg.real.log"
grep -q 'ffmpeg process-group pgid=' "$TMP/ffmpeg.real.log"


# MiniPlayer full-switch teardown: SageTV may close the MIM stdin
# without first writing STOP/QUIT. EOF must terminate the isolated FFmpeg
# process group, including descendants, so no old QSV transcode survives into
# the next MiniPlayer initialization.
cat > "$TMP/ffmpeg.real" <<'SH'
#!/usr/bin/env bash
if [[ " $* " == *" -encoders "* ]]; then printf ' V....D h264_qsv\n V..... libx264\n'; exit 0; fi
trap 'touch "$MIM_TEST_DIR/eof.direct.term"; exit 0' TERM
(
  trap 'touch "$MIM_TEST_DIR/eof.descendant.term"; exit 0' TERM
  while :; do sleep 1; done
) &
touch "$MIM_TEST_DIR/eof.ready"
while IFS= read -r line; do :; done
SH
chmod +x "$TMP/ffmpeg.real"
rm -f "$TMP/eof.direct.term" "$TMP/eof.descendant.term" "$TMP/eof.ready"
set +e
{ sleep .5; } | MIM_TEST_DIR="$TMP" timeout 6 "$TMP/ffmpeg" -stdinctrl -i "$TMP/media/test.ts" -vcodec mpeg4 -b 4M -f mpegts - >/dev/null 2>&1
eof_rc=$?
set -e
[[ "$eof_rc" -eq 0 ]]
for _ in {1..40}; do
  [[ -f "$TMP/eof.direct.term" && -f "$TMP/eof.descendant.term" ]] && break
  sleep .05
done
[[ -f "$TMP/eof.direct.term" ]]
[[ -f "$TMP/eof.descendant.term" ]]
grep -Eq 'control: stdin (EOF|HUP) -> terminate ffmpeg process-group' "$TMP/ffmpeg.real.log"

# SageTV/Java Process.destroy() is allowed to terminate the MIM itself. The MIM
# must catch SIGTERM, tear down/reap the isolated FFmpeg process group, and only
# then exit; FFmpeg and descendants must not be orphaned across a file switch.
cat > "$TMP/ffmpeg.real" <<'SH'
#!/usr/bin/env bash
if [[ " $* " == *" -encoders "* ]]; then printf ' V....D h264_qsv\n V..... libx264\n'; exit 0; fi
trap 'touch "$MIM_TEST_DIR/sig.direct.term"; exit 0' TERM
(
  trap 'touch "$MIM_TEST_DIR/sig.descendant.term"; exit 0' TERM
  while :; do sleep 1; done
) &
touch "$MIM_TEST_DIR/sig.ready"
while IFS= read -r line; do :; done
SH
chmod +x "$TMP/ffmpeg.real"
rm -f "$TMP/sig.direct.term" "$TMP/sig.descendant.term" "$TMP/sig.ready"
rm -f "$TMP/control.fifo"
mkfifo "$TMP/control.fifo"
exec 9<>"$TMP/control.fifo"
MIM_TEST_DIR="$TMP" "$TMP/ffmpeg" -stdinctrl -i "$TMP/media/test.ts" -vcodec mpeg4 -b 4M -f mpegts - <"$TMP/control.fifo" >/dev/null 2>&1 &
mim_pid=$!
for _ in {1..60}; do [[ -f "$TMP/sig.ready" ]] && break; sleep .05; done
[[ -f "$TMP/sig.ready" ]]
for _ in {1..40}; do
  s="$($TMP/ffmpeg --mim-status)"
  [[ "$s" == *'"activeJobs":[{'* ]] && break
  sleep .05
done
[[ "$s" == *'"backend":"qsv"'* ]]
[[ "$s" == *'"encoder":"h264_qsv"'* ]]
[[ "$s" == *'"hardwareEncode":true'* ]]
[[ "$s" == *'"state":"running"'* ]]
kill -TERM "$mim_pid"
set +e
wait "$mim_pid"
sig_rc=$?
set -e
exec 9>&-
[[ "$sig_rc" -eq 0 ]]
for _ in {1..40}; do
  [[ -f "$TMP/sig.direct.term" && -f "$TMP/sig.descendant.term" ]] && break
  sleep .05
done
[[ -f "$TMP/sig.direct.term" ]]
[[ -f "$TMP/sig.descendant.term" ]]
grep -q 'control: parent signal=15 -> terminate ffmpeg process-group' "$TMP/ffmpeg.real.log"
s="$($TMP/ffmpeg --mim-status)"
[[ "$s" == *'"activeJobs":[]'* ]]
[[ "$s" == *'"state":"stopped"'* ]]
[[ "$s" == *'"exitCode":0'* ]]
[[ "$s" == *'"lastTranscodeJob":{'* ]]

# Last-resort Linux parent-death protection: if the MIM itself is SIGKILLed and
# cannot run cleanup code, PR_SET_PDEATHSIG(SIGKILL) guarantees the direct
# ffmpeg.real process cannot survive indefinitely.
cat > "$TMP/ffmpeg.real" <<'SH'
#!/usr/bin/env bash
if [[ " $* " == *" -encoders "* ]]; then printf ' V....D h264_qsv\n V..... libx264\n'; exit 0; fi
echo $$ > "$MIM_TEST_DIR/pdeath.pid"
touch "$MIM_TEST_DIR/pdeath.ready"
while IFS= read -r line; do :; done
SH
chmod +x "$TMP/ffmpeg.real"
rm -f "$TMP/pdeath.pid" "$TMP/pdeath.ready"
rm -f "$TMP/control2.fifo"
mkfifo "$TMP/control2.fifo"
exec 8<>"$TMP/control2.fifo"
MIM_TEST_DIR="$TMP" "$TMP/ffmpeg" -stdinctrl -i "$TMP/media/test.ts" -vcodec mpeg4 -b 4M -f mpegts - <"$TMP/control2.fifo" >/dev/null 2>&1 &
mim_pid=$!
for _ in {1..60}; do [[ -f "$TMP/pdeath.ready" && -f "$TMP/pdeath.pid" ]] && break; sleep .05; done
[[ -f "$TMP/pdeath.pid" ]]
ff_pid="$(cat "$TMP/pdeath.pid")"
kill -0 "$ff_pid" 2>/dev/null
kill -KILL "$mim_pid"
set +e
wait "$mim_pid" 2>/dev/null
pdeath_rc=$?
set -e
exec 8>&-
[[ "$pdeath_rc" -eq 137 ]]
for _ in {1..60}; do
  if ! kill -0 "$ff_pid" 2>/dev/null; then break; fi
  sleep .05
done
! kill -0 "$ff_pid" 2>/dev/null
grep -q 'safety: parent-death SIGKILL configured for ffmpeg child' "$TMP/ffmpeg.real.log"

# An abnormal realtime FFmpeg exit is contained as clean EOF/no-video instead
# of returning a failed transcoder process status to SageTV.
cat > "$TMP/ffmpeg.real" <<'SH'
#!/usr/bin/env bash
if [[ " $* " == *" -encoders "* ]]; then printf ' V....D h264_qsv\n V..... libx264\n'; exit 0; fi
exit 42
SH
chmod +x "$TMP/ffmpeg.real"
set +e
{ sleep .2; } | "$TMP/ffmpeg" -stdinctrl -i "$TMP/media/test.ts" -vcodec mpeg4 -b 4M -f mpegts - >/dev/null 2>&1
fail_rc=$?
set -e
[[ "$fail_rc" -eq 0 ]]
grep -q 'contained ffmpeg failure rc=42 -> MIM exit rc=0' "$TMP/ffmpeg.real.log" || {
  echo "ERROR: abnormal child exit was not logged as contained" >&2
  tail -80 "$TMP/ffmpeg.real.log" >&2
  exit 1
}

# Closing FFmpeg stdin before a forwarded runtime-control command must not kill
# the MIM with SIGPIPE. The broken control pipe is logged and contained.
cat > "$TMP/ffmpeg.real" <<'SH'
#!/usr/bin/env bash
if [[ " $* " == *" -encoders "* ]]; then printf ' V....D h264_qsv\n V..... libx264\n'; exit 0; fi
exec 0<&-
sleep 1
exit 0
SH
chmod +x "$TMP/ffmpeg.real"
set +e
{ sleep .1; printf 'videorateadapt -500\n'; } | "$TMP/ffmpeg" -stdinctrl -i "$TMP/media/test.ts" -vcodec mpeg4 -b 4M -f mpegts - >/dev/null 2>&1
pipe_rc=$?
set -e
[[ "$pipe_rc" -eq 0 ]]
grep -q 'containing EPIPE' "$TMP/ffmpeg.real.log"

echo "[PASS] MIM mapping + MiniPlayer switch teardown + crash-containment tests"
