# SageTV FFmpeg/MIM Ubuntu 26 Commissioning Guide

## Authoritative field state

This package captures the source and deployment state tested on 2026-08-24.
The separate Unraid development instance was:

- container: `opensagetv-modern-dev`
- SageTV address: `192.168.10.176`
- persistent root: `/mnt/user/appdata/sagetv_dev`
- server directory: `/mnt/user/appdata/sagetv_dev/server`
- media: `/mnt/user/sagemedia` mounted at `/var/media`
- runtime base: Ubuntu 26.04 with Java 11
- builder: `sagetv-ffmpeg-mim-builder:9.0.1-v5`

Do not copy credentials, license data, or an existing SageTV database from this
handoff. Supply those locally during commissioning.

## Build

Docker is the only host build prerequisite.

```bash
docker image inspect sagetv-ffmpeg-mim-builder:9.0.1-v5
./build_linux_sagetv_ffmpeg_static.sh
./code/mim/tests/run_mim_tests.sh
./code/mim/tests/run_init_tests.sh
./validate_static.sh
```

To create the builder when it is not already present:

```bash
./build_sagetv_builder_image.sh
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

## Important unresolved issue

Live MiniClient playback is not fully commissioned. Some channels still begin
with audio but no video, and software-encoded 59.94 fps channels have shown an
initial stall. Evidence collected so far:

- source MPEG-2 video and audio are detected correctly;
- the strengthened readiness gate typically passes in 13-250 ms;
- forcing MPEG-TS does not eliminate the failure;
- QSV live encode showed repeated VA-API initialization;
- switching live encode to `libx264` did not eliminate every missing-video case
  and consumed about 166% CPU on one 59.94 fps stream;
- preserving the original MPEG-4 Part 2 request produced neither audio nor video
  and was rolled back both in deployment and source.

The deployed rollback point uses `libx264` for live files. Do not claim live-TV
commissioning complete until multiple 29.97 and 59.94 channels, channel changes,
join-in-progress playback, and repeated starts all produce continuous audio and
video.

## Recommended next diagnostic

Capture the exact Matroska bytes emitted by a successful and failed MIM session
without changing the MiniClient contract. Run `ffprobe -show_streams`, inspect
the first cluster/keyframe timestamps, and compare time-to-first video packet
with time-to-first audio packet. This will distinguish an FFmpeg mux/encoder
problem from a MiniClient decoder-start problem. Also record FFmpeg CPU use and
effective encoding speed for 59.94 fps sources.

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

