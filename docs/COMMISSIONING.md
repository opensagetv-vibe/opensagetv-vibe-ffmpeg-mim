# SageTV FFmpeg/MIM Ubuntu 26 Commissioning Guide

## Authoritative field state

This package captures the source and deployment state through 2026-08-29.
The current supported build uses the shared `opensagetv-vibe-dev` container.
The commissioned isolated Unraid development instance is:

- container: `sagetv-vibe-server-u26-gpu-j11`
- SageTV address: `192.168.10.232`
- persistent root: `/mnt/user/appdata/sagetv-vibe-server-u26-gpu-j11`
- server directory: `/mnt/user/appdata/sagetv-vibe-server-u26-gpu-j11/server`
- media: `/mnt/user/sagemedia` mounted at `/var/media`
- runtime base: Ubuntu 26.04 with Java 11
- development image: `opensagetv-vibe-build-env:u26-j11`

Do not copy credentials, license data, or an existing SageTV database from this
handoff. Supply those locally during commissioning.

## Build

Docker is the only host build prerequisite.

```bash
../opensagetv-vibe-build-env/opensagetv-vibe-dev.sh ffmpeg-linux
../opensagetv-vibe-build-env/opensagetv-vibe-dev.sh test-mim
```

To create or refresh the unified image when it is not already present:

```bash
../opensagetv-vibe-build-env/opensagetv-vibe-dev.sh image
```

Linux output is written to `output/linux-x64/`. The commissioning set is:

```text
ffmpeg_MIM
ffmpeg.real
ffprobe
ffmpeg.real.ini
ffmpeg_init.sh
diagnose_miniplayer.sh
diagnose_sagetv_abort.sh
```

## Install into SageTV

Stop SageTV before replacing the transcoder. Copy the commissioning set into
the persistent SageTV server directory, then run:

```bash
cd /opt/sagetv/server
chmod 777 ffmpeg_init.sh
./ffmpeg_init.sh
```

`ffmpeg_init.sh` preserves a timestamped backup and installs `ffmpeg_MIM` as
the `ffmpeg` executable used by SageTV.

## Current live-TV policy

- Known `.ts` active files are passed to FFmpeg with the MPEG-TS demuxer forced.
- The readiness gate scans up to 5 MB already present and requires codec setup
  plus a picture/keyframe before FFmpeg launches.
- Linux automatic backend order is `vaapi,qsv,nvenc,software`.
- Global and active-file hardware input decode are disabled so A/53 caption
  side data survives software MPEG-2 decode.
- Intel live and completed jobs hardware-encode with `h264_vaapi`; the filter
  path uploads NV12 frames explicitly.
- Output uses `-a53cc 1`, zero B-frames for live safety, prompt MPEG-TS muxing,
  and header/discontinuity resend.
- Completed MPEG-TS seeks preserve SageTV's exact requested time. The old
  bounded input/output-preroll workaround is opt-in only because applying it
  globally shifted SageTV timeline and A/53 caption presentation by about five
  seconds on the commissioned software-decode/VAAPI-encode path.
- Completed-file warm probe caching uses at least 512 KiB, 500 ms, and 1024
  packets. Do not restore the old 64 KiB/100 ms/128 packet shortcut: physical
  A/53 testing proved it accumulated about five seconds of caption drift.
- Intel QSV remains selectable but is not the default because the final
  FFmpeg 9 seek/live stress stream reproducibly exited with return code 139.

## Remaining commissioning boundary

The Android MCP harness is integrated. The exact 0.4.7 hardware-only matrix
passes legacy Exo, Media3, IJK, GSY Auto, GSY Media3, GSY legacy Exo, and the
bounded GSY System safe delegate for completed controls and real 2.1/5.1 live
changes on Amazon AFTMM/API 25. Fresh-job, expected-input, Intel
VAAPI/`h264_vaapi`, stopped-state, and zero-orphan checks all pass. Older
software/fallback results remain historical evidence but are outside the
current hardware-only commissioning scope.

Do not enable MIM by default. Physical AMD VAAPI and NVIDIA NVENC tests remain
SKIPPED without matching hardware, and repeated final-release seek/live soak
still remains before promotion.

## Recommended next diagnostic

Run repeated exact-release FF/REW/jump and 2.1/5.1 channel-change soak while
retaining the generated-clock/row-14 screenshot gate. Commission AMD and
NVIDIA only on matching physical hardware; do not infer them from encoder
listings or Intel results.

## Verification after deployment

```bash
./ffmpeg --mim-version
./ffmpeg.real -version
ldd ./ffmpeg_MIM
tail -f ./ffmpeg.real.log
```

Verify recorded playback first, then live 29.97 fps, live 59.94 fps, rapid
channel changes, and join-in-progress playback. Query `./ffmpeg --mim-status`
during each job and require the expected backend, encoder, input, freshness,
hardware-encode state, and post-stop cleanup.
