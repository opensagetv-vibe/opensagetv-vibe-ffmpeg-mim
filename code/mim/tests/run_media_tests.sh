#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
OUT="$ROOT/output/linux-x64"
MIM="$OUT/ffmpeg_MIM"
REAL="$OUT/ffmpeg.real"
PROBE="$OUT/ffprobe"

for required in "$MIM" "$REAL" "$PROBE" "$OUT/ffmpeg.real.ini"; do
  [[ -x "$required" || "$required" == *.ini ]] || {
    echo "ERROR: required Linux test artifact is missing: $required" >&2
    exit 1
  }
done

TMP="$(mktemp -d)"
cleanup() {
  local background
  background="$(jobs -pr)"
  if [[ -n "$background" ]]; then
    # shellcheck disable=SC2086
    kill $background 2>/dev/null || true
    wait 2>/dev/null || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT
INI="$TMP/ffmpeg.real.ini"
LOG="$TMP/ffmpeg.real.log"
cp "$OUT/ffmpeg.real.ini" "$INI"

# Keep this integration deterministic on builders with or without a GPU. GPU
# command construction and hardware commissioning are separate tests; these
# media-integrity checks intentionally exercise the universal software path.
sed -i 's/^backend=auto$/backend=software/' "$INI"
sed -i 's/^hardware_decode=true$/hardware_decode=false/' "$INI"
sed -i "s|^directory=cache/probe$|directory=$TMP/probe-cache|" "$INI"
sed -i "s|^file=./ffmpeg.real.log$|file=$LOG|" "$INI"

SOURCE_30="$TMP/source-29.97.ts"
SOURCE_60="$TMP/source-59.94.ts"

generate_source() {
  local rate="$1" duration="$2" output="$3"
  "$REAL" -hide_banner -loglevel error -y \
    -f lavfi -i "testsrc2=size=640x360:rate=$rate" \
    -f lavfi -i 'sine=frequency=1000:sample_rate=48000' \
    -t "$duration" -shortest \
    -c:v mpeg2video -pix_fmt yuv420p -b:v 3000k -g 15 -bf 0 \
    -c:a mp2 -b:a 128k -ar 48000 -ac 2 -f mpegts "$output"
}

generate_source 30000/1001 5 "$SOURCE_30"
generate_source 60000/1001 6 "$SOURCE_60"

# Exercise the exact stock-era imported-video thumbnail command against the
# real pinned FFmpeg, not only the argument-rewrite dry run. This catches old
# crop ordering and removed filter/output options that a fake child accepts.
THUMBNAIL_OUT="$TMP/legacy-thumbnail.jpg"
SAGETV_FFMPEG_MIM_INI="$INI" "$MIM" \
  -hide_banner -loglevel error -y -skip_frame nokey -ss 1 -i "$SOURCE_30" \
  -f mjpeg -deinterlace -vf crop=0:8:0:0,scale=512:288 \
  -vframes 1 -an -minpixvar 300 -minpixnumframes 150 -minpixenergy 1 \
  -vsync 0 "$THUMBNAIL_OUT"
[[ -s "$THUMBNAIL_OUT" ]]
thumbnail_stream="$($PROBE -v error -select_streams v:0 \
  -show_entries stream=codec_name,width,height -of csv=p=0 "$THUMBNAIL_OUT")"
[[ "$thumbnail_stream" == "mjpeg,512,288" ]]
grep -q 'compat: removed obsolete SageTV thumbnail frame-selection options' "$LOG"
grep -q 'compat: translated legacy SageTV thumbnail crop order' "$LOG"
grep -q 'compat: translated legacy thumbnail -deinterlace to yadif' "$LOG"
grep -q 'compat: translated legacy -vsync to -fps_mode passthrough' "$LOG"
echo '[PASS] real FFmpeg legacy SageTV thumbnail compatibility'

# SageTV's historical -dumpmetadata contract is textual. Verify the real
# FFmpeg 9 child output is converted back to the stream-index syntax consumed
# by stock SageTV's unchanged FormatParser, including a Matroska input.
METADATA_MKV="$TMP/metadata-probe.mkv"
"$REAL" -hide_banner -loglevel error -y -i "$SOURCE_30" -map 0 \
  -c:v libx264 -preset ultrafast -c:a copy "$METADATA_MKV"
set +e
metadata_output="$(SAGETV_FFMPEG_MIM_INI="$INI" "$MIM" \
  -dumpmetadata -v 2 -i "$METADATA_MKV" 2>&1)"
metadata_rc=$?
set -e
[[ $metadata_rc -ne 127 ]]
grep -q 'Input #0, matroska,webm, from' <<<"$metadata_output"
grep -Eq 'Duration: 00:00:0[45][.]' <<<"$metadata_output"
grep -q 'Stream #0.0' <<<"$metadata_output"
grep -q 'Stream #0.1' <<<"$metadata_output"
! grep -q 'Stream #0:0' <<<"$metadata_output"
echo '[PASS] real FFmpeg stock SageTV metadata compatibility'

# Exercise the exact stock MiniPlayer command shape that follows imported MKV
# discovery. SageTV omits -vcodec and requests `-f dvd`; MIM's default copy
# policy must remux the existing H.264/MP2 streams to MPEG-TS and emit real
# media instead of asking modern FFmpeg for an invalid H.264 DVD stream.
LEGACY_DVD_COPY="$TMP/stock-miniplayer-copy.ts"
LEGACY_DVD_CONTROL="$TMP/stock-miniplayer-control.fifo"
mkfifo "$LEGACY_DVD_CONTROL"
exec 7<>"$LEGACY_DVD_CONTROL"
SAGETV_FFMPEG_MIM_INI="$INI" "$MIM" \
  -v 3 -y -threads 2 -sn -vsync 1 -async 100 -stdinctrl \
  -i "$METADATA_MKV" -threads 5 -f dvd -b 2000000 -g 3 -bf 0 \
  -acodec mp2 -ab 128000 -ar 48000 -ac 2 -s 352x240 -r 29.97 \
  -map 0:0 -map 0:1 "$LEGACY_DVD_COPY" <"$LEGACY_DVD_CONTROL"
exec 7>&-
rm -f "$LEGACY_DVD_CONTROL"
[[ -s "$LEGACY_DVD_COPY" ]]
legacy_copy_streams="$($PROBE -v error -show_entries stream=codec_type,codec_name \
  -of csv=p=0 "$LEGACY_DVD_COPY")"
grep -q 'h264,video' <<<"$legacy_copy_streams"
grep -q 'mp2,audio' <<<"$legacy_copy_streams"
"$REAL" -hide_banner -loglevel error -i "$LEGACY_DVD_COPY" \
  -map 0:v:0 -map 0:a:0 -f null -
grep -q 'compat: SageTV copy-only format dvd -> mpegts' "$LOG"
echo '[PASS] real FFmpeg stock MiniPlayer MKV remux compatibility'

assert_media_integrity() {
  local media="$1" label="$2" minimum_video_packets="${3:-20}"
  local streams video_packets first_video first_audio

  streams="$($PROBE -v error -show_entries stream=codec_type,codec_name \
    -of csv=p=0 "$media")"
  grep -q ',video' <<<"$streams" || {
    echo "ERROR: $label output has no video stream" >&2
    printf '%s\n' "$streams" >&2
    return 1
  }
  grep -q ',audio' <<<"$streams" || {
    echo "ERROR: $label output has no audio stream" >&2
    printf '%s\n' "$streams" >&2
    return 1
  }

  video_packets="$($PROBE -v error -select_streams v:0 -count_packets \
    -show_entries stream=nb_read_packets -of default=nw=1:nk=1 "$media")"
  [[ "$video_packets" =~ ^[0-9]+$ && "$video_packets" -ge "$minimum_video_packets" ]] || {
    echo "ERROR: $label output contains only $video_packets video packets" >&2
    return 1
  }

  first_video="$($PROBE -v error -select_streams v:0 -show_packets \
    -show_entries packet=pts_time -of csv=p=0 "$media" \
    | sed -n 's/^\(-\?[0-9][0-9]*\([.][0-9]*\)\?\).*$/\1/p' | sed -n '1p')"
  # MP2/AAC demuxers may append skip-sample side data to the same CSV row.
  # Extract only the leading numeric PTS rather than treating that valid side
  # data as a malformed timestamp.
  first_audio="$($PROBE -v error -select_streams a:0 -show_packets \
    -show_entries packet=pts_time -of csv=p=0 "$media" \
    | sed -n 's/^\(-\?[0-9][0-9]*\([.][0-9]*\)\?\).*$/\1/p' | sed -n '1p')"
  [[ "$first_video" =~ ^-?[0-9]+([.][0-9]+)?$ ]] || {
    echo "ERROR: $label first video timestamp is invalid: $first_video" >&2
    return 1
  }
  [[ "$first_audio" =~ ^-?[0-9]+([.][0-9]+)?$ ]] || {
    echo "ERROR: $label first audio timestamp is invalid: $first_audio" >&2
    return 1
  }
  awk -v video="$first_video" -v audio="$first_audio" 'BEGIN {
    delta=video-audio; if (delta<0) delta=-delta; exit(delta<=1.5 ? 0 : 1)
  }' || {
    echo "ERROR: $label starts audio/video more than 1.5 seconds apart: video=$first_video audio=$first_audio" >&2
    return 1
  }

  # Decode every emitted audio/video packet. This catches corrupt headers,
  # broken timestamps, and streams that ffprobe can list but a player cannot
  # actually consume.
  "$REAL" -hide_banner -loglevel error -i "$media" -map 0:v:0 -map 0:a:0 \
    -f null -
}

run_completed_transcode() {
  local source="$1" output="$2"
  local control="$TMP/completed-control.fifo"
  rm -f "$control"
  mkfifo "$control"
  exec 9<>"$control"
  SAGETV_FFMPEG_MIM_INI="$INI" "$MIM" \
    -v 3 -y -threads 2 -sn -stdinctrl -i "$source" \
    -f matroska -vcodec mpeg4 -b 1200000 -r 29.97 -s 640x360 \
    -g 300 -bf 0 -acodec mp2 -ab 112000 -ar 48000 -ac 2 "$output" \
    <"$control"
  exec 9>&-
  rm -f "$control"
}

COMPLETED_OUT="$TMP/completed.mkv"
run_completed_transcode "$SOURCE_30" "$COMPLETED_OUT"
assert_media_integrity "$COMPLETED_OUT" completed 100
grep -q 'final backend=software' "$LOG"

run_active_transcode() {
  local source="$1" output="$2" label="$3"
  local control="$TMP/$label-control.fifo"
  local started first_output=0
  rm -f "$control" "$output"
  mkfifo "$control"
  exec 8<>"$control"
  now_ms() {
    local nanoseconds
    nanoseconds="$(date +%s%N)"
    printf '%s\n' "$(( nanoseconds / 1000000 ))"
  }
  started="$(now_ms)"
  SAGETV_FFMPEG_MIM_INI="$INI" "$MIM" \
    -v 3 -y -threads 2 -sn -stdinctrl -activefile -i "$source" \
    -f matroska -vcodec mpeg4 -b 1200000 -r 59.94 -s 640x360 \
    -g 300 -bf 0 -acodec mp2 -ab 112000 -ar 48000 -ac 2 "$output" \
    <"$control" &
  local mim_pid=$!

  for _ in {1..160}; do
    if [[ -s "$output" ]]; then
      first_output=$(( $(now_ms) - started ))
      break
    fi
    kill -0 "$mim_pid" 2>/dev/null || break
    sleep .025
  done
  if (( first_output == 0 || first_output > 3000 )); then
    echo "ERROR: $label first output took ${first_output}ms" >&2
    printf 'STOP\n' >&8 || true
    wait "$mim_pid" || true
    exec 8>&-
    return 1
  fi

  # Let the real encoder consume all currently available input, then perform
  # SageTV's active-to-inactive handoff. FFmpeg must finalize a decodable file
  # and the MIM must reap it.
  sleep .75
  printf 'videorateadapt -100\n' >&8
  sleep .1
  printf 'inactivefile\n' >&8
  wait "$mim_pid"
  exec 8>&-
  rm -f "$control"

  assert_media_integrity "$output" "$label" 20
  if pgrep -x ffmpeg.real >/dev/null 2>&1; then
    echo "ERROR: $label left an ffmpeg.real process running" >&2
    pgrep -a -x ffmpeg.real >&2 || true
    return 1
  fi
  printf '[PASS] %s first-output-ms=%s\n' "$label" "$first_output"
}

# Join a file that has already started, then continue appending TS packets while
# the active transcode is running.
GROWING="$TMP/growing-59.94.ts"
TOTAL_PACKETS=$(( $(stat -c %s "$SOURCE_60") / 188 ))
INITIAL_PACKETS=500
CHUNK_PACKETS=250
dd if="$SOURCE_60" of="$GROWING" bs=188 count="$INITIAL_PACKETS" status=none
(
  offset=$INITIAL_PACKETS
  while (( offset < TOTAL_PACKETS )); do
    count=$CHUNK_PACKETS
    (( offset + count > TOTAL_PACKETS )) && count=$(( TOTAL_PACKETS - offset ))
    dd if="$SOURCE_60" bs=188 skip="$offset" count="$count" status=none >> "$GROWING"
    offset=$(( offset + count ))
    sleep .03
  done
) &
writer_pid=$!
run_active_transcode "$GROWING" "$TMP/join-in-progress.mkv" join-in-progress
wait "$writer_pid"

# Repeat full active-file startup/teardown to catch stale children, cache
# identity mistakes, and lifecycle failures without requiring a rendering
# client. The 59.94 source also exercises the historically troublesome rate.
for iteration in 1 2 3; do
  run_active_transcode "$SOURCE_60" "$TMP/repeated-$iteration.mkv" \
    "repeated-switch-$iteration"
done

grep -q 'active-file video-ready after ms=' "$LOG"
grep -q 'control: inactivefile -> signal=15 ffmpeg process-group' "$LOG"
grep -q 'stdin: videorateadapt -100' "$LOG"

echo '[PASS] real FFmpeg completed/growing/join/repeated-switch media integrity tests'
