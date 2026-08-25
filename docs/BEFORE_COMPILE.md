# Before Compile — v0.4.4

Use this merged v0.4.4 tree. Do not compile from the old v0.3.9 handoff or the standalone Ubuntu 26 Docker ZIP.

## 1. Reuse the unified builder image

v0.4.4 does **not** change the builder environment. Reuse the existing builder image:

```bash
chmod +x *.sh code/docker/*.sh code/mim/tests/*.sh code/tools/*.py sagetv-runtime-docker/*.sh
```

Expected image:

```text
sagetv-ffmpeg-mim-builder:9.0.1-v5
```

## 2. Apply restart safety to the existing Ubuntu 26 test container

This changes only Docker's restart policy; it does not rebuild or recreate the container:

```bash
./sagetv-runtime-docker/enable-crash-restart.sh
```

## 3. Build Linux first

```bash
./build_linux_sagetv_ffmpeg_static.sh
```

The command reuses `sagetv-ffmpeg-mim-builder:9.0.1-v5`. If the image is missing it now stops with an error instead of rebuilding Docker implicitly.

Expected output:

```text
output/linux-x64/
    ffmpeg_MIM
    ffmpeg.real
    ffprobe
    ffmpeg.real.ini
    ffmpeg_init.sh
    diagnose_miniplayer.sh
    diagnose_sagetv_abort.sh
    build_report.txt
    hardware_encoders.txt
    SHA256SUMS.txt
```

## 4. Deploy only to the Ubuntu 26 test appdata

Copy the new Linux output into the test SageTV server folder, not production:

```text
/mnt/user/appdata/sagetv-u26-test/server/
```

Then run `ffmpeg_init.sh` from that directory.

## 5. Validate the newly compiled FFmpeg against the proven Ubuntu 26 GPU runtime

```bash
docker exec sagetv-u26-test gpu-check
```

Review:

```text
/mnt/user/appdata/sagetv-u26-test/server/ubuntu26-gpu-check.txt
```

Two tests are intentionally separate:

```text
SYSTEM FFMPEG QSV INIT/ENCODE TEST
PROJECT FFMPEG.REAL QSV TEST
```

The system FFmpeg path is already proven. The project FFmpeg path is the new compile validation.

## 6. If project FFmpeg QSV passes

Test in this order:

1. SageTV copy/remux playback.
2. SageTV hardware transcode with `hardware_decode=false`.
3. Seek/skip and active recording behavior.
4. `videorateadapt` behavior.
5. Set `hardware_decode=true` only after the encode-only path is stable.
6. Test a real interlaced recording to validate `deinterlace_qsv` / `scale_qsv`.
7. Build Windows x64 after Linux is stable.

## 7. If project FFmpeg QSV fails while system FFmpeg passes

Do not change Ubuntu, Java, SageTV, `/dev/dri`, or the Intel driver again. That result isolates the remaining failure to the BtbN dependency stack used to compile the static/patched `ffmpeg.real`.

## What this build is validating

v0.4.4 is specifically a MiniPlayer full-switch teardown fix. It does not change the proven QSV encoding/filter configuration. After deployment, repeat the same recording-to-recording switch that previously aborted SageTV and confirm the old `ffmpeg.real` is terminated before the next MIM invocation.

Do not rebuild the SageTV Ubuntu 26 runtime Docker for this test.
