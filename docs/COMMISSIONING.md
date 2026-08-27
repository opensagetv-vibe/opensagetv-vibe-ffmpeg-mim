# SageTV FFmpeg/MIM Ubuntu 26 Commissioning Guide

## Authoritative field state

This package captures the source and deployment state through 2026-08-26.
The current supported build uses the shared `opensagetv-vibe-dev` container. Earlier
field diagnostics used a separate Unraid development instance:

- container: `opensagetv-modern-dev`
- SageTV address: `192.168.10.176`
- persistent root: `/mnt/user/appdata/sagetv_dev`
- server directory: `/mnt/user/appdata/sagetv_dev/server`
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
- Global `hardware_decode=true` is retained for completed files.
- Active-file hardware decode is disabled.
- Active-file hardware encode is disabled; live jobs use `libx264`.
- The MiniClient network-encoder playback delay is 1500 ms in its client
  properties. The attempted 250 ms value caused inconsistent audio-only starts
  and must not be reused.

## Remaining commissioning boundary

The server-side causes reproduced from earlier black-video/audio-only starts
have been corrected in 0.4.5: active inputs no longer use a reduced cached
probe, hardware encoders undergo a bounded real encode preflight, and each GPU
path uses compatible frame/upload/filter chains. Real generated growing and
partially written streams now pass repeated audio/video integrity tests.

Live Android MiniClient playback is still not fully commissioned because the
client is not currently part of the automated harness. Older evidence retained
for comparison was:

- source MPEG-2 video and audio are detected correctly;
- the strengthened readiness gate typically passes in 13-250 ms;
- forcing MPEG-TS does not eliminate the failure;
- QSV live encode showed repeated VA-API initialization;
- switching live encode to `libx264` did not eliminate every missing-video case
  and consumed about 166% CPU on one 59.94 fps stream;
- preserving the original MPEG-4 Part 2 request produced neither audio nor video
  and was rolled back both in deployment and source.

Do not enable MIM by default until multiple real Android sessions, channels,
channel changes, join-in-progress playback, and repeated starts all produce
continuous audio and video. Also complete physical AMD VAAPI and NVIDIA NVENC
tests; their option/filter construction is covered without hardware.

## Recommended next diagnostic

Bring the Android MiniClient MCP/automation harness into the commissioning
pipeline. Capture the exact Matroska bytes and client logs for any failed
session, compare first audio/video packets and keyframe timestamps, and verify
the client recovers without restart after a deliberately failed stream.

## Verification after deployment

```bash
./ffmpeg --mim-version
./ffmpeg.real -version
ldd ./ffmpeg_MIM
tail -f ./ffmpeg.real.log
```

Verify recorded playback first, then live 29.97 fps, live 59.94 fps, rapid
channel changes, and join-in-progress playback. Restart the MiniClient after a
failed stream because its decoder can remain stuck.
