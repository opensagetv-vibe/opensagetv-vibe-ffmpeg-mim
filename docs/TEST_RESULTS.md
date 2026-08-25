# Test Results — v0.4.4

## Merge revalidation (2026-08-24)

- `[PASS]` `./validate_static.sh`
- `[PASS]` `./code/mim/tests/run_mim_tests.sh`
- `[PASS]` `./code/mim/tests/run_init_tests.sh`



## v0.4.4 switch-teardown regression

The local MIM test harness now verifies all newly identified SageTV full-switch teardown paths:

- `-stdinctrl` stdin EOF/HUP sends SIGTERM to the isolated FFmpeg process group and reaps it.
- SIGTERM sent directly to the MIM is caught; FFmpeg and a helper descendant are terminated/reaped before MIM exits.
- SIGKILL of the MIM triggers Linux `PR_SET_PDEATHSIG(SIGKILL)` and the direct `ffmpeg.real` process does not survive.
- Existing STOP/QUIT process-group containment, EPIPE/SIGPIPE protection, QSV rewrite, fixed-push contract, metadata compatibility, and clean abnormal-child exit tests remain enabled.

Live status before v0.4.4 deployment: full QSV playback works and greatly lowers CPU use, but changing recordings still aborts the SageTV JVM. The second recording never reaches the MIM log, so the live validation target for v0.4.4 is the teardown/re-init boundary.

## v0.4.3 crash-containment regression

- `[PASS]` Linux `ffmpeg.real` child is placed in an isolated process group.
- `[PASS]` `STOP` terminates both direct FFmpeg child and a spawned descendant while the MIM exits normally.
- `[PASS]` Abnormal realtime child exit code `42` is contained and normalized to MIM rc=0.
- `[PASS]` Closed FFmpeg stdin produces contained/logged `EPIPE` rather than terminating the MIM with `SIGPIPE`.
- `[PASS]` Docker runtime creation uses `--restart unless-stopped`.
- `[PASS]` Existing container restart policy can be updated with `enable-crash-restart.sh` without a rebuild.
- `[PASS]` Builder tag remains `sagetv-ffmpeg-mim-builder:9.0.1-v5`.
- `[PASS]` Linux/Windows/all build wrapper does not implicitly call the builder-image bootstrap when the image is missing.

## v0.4.2 fixed-push contract regression

- `[PASS]` Exact live MiniPlayer command keeps `-f matroska`.
- `[PASS]` Exact live MiniPlayer command keeps `-acodec mp2 -ab 112000 -ar 48000 -ac 1`.
- `[PASS]` Video still maps to `-c:v h264_qsv` with explicit QSV device initialization.
- `[PASS]` Matroska output does not receive `-mpegts_flags`, `-muxpreload`, or `-muxdelay`.
- `[PASS]` Current FFmpeg accepts the resulting Matroska/H.264/MP2-mono output shape in a live encode sanity test.
- `[PASS]` Builder tag remains `sagetv-ffmpeg-mim-builder:9.0.1-v5`.

## v0.4.1 source validation

- `[PASS]` Shell syntax for root build scripts, Docker builder scripts, MIM tests, init tests, and merged Ubuntu 26 runtime scripts.
- `[PASS]` Python syntax for the FFmpeg `videorateadapt` patcher.
- `[PASS]` C++17 syntax for the native MIM.
- `[PASS]` Builder version advanced to `sagetv-ffmpeg-mim-builder:9.0.1-v5`.
- `[PASS]` Linux/Windows x64-only target matrix retained.
- `[PASS]` Windows packaging still emits `SageTVTranscoder.exe`.
- `[PASS]` Linux `ffmpeg_init.sh` chmod-first and backup/restore behavior retained.
- `[PASS]` QSV transcode emits `-init_hw_device qsv:hw,child_device=/dev/dri/renderD128` even when `hardware_decode=false`.
- `[PASS]` With `hardware_decode=false`, QSV hardware decode flags are not added.
- `[PASS]` With `hardware_decode=true`, QSV adds `-hwaccel qsv`, `-hwaccel_device hw`, and `-hwaccel_output_format qsv`.
- `[PASS]` Full QSV decode with SageTV `-s 1280x720` produces `deinterlace_qsv,scale_qsv=w=1280:h=720` and removes the conflicting `-s` option.
- `[PASS]` Existing copy-default, H.264/HEVC mapping, local `stv://` translation, active-file, stdin control, and non-SageTV passthrough tests remain passing.

## Confirmed Ubuntu 26 runtime results from Unraid

- `[PASS]` Ubuntu 26.04 container starts.
- `[PASS]` OpenJDK 11.0.31 starts SageTV and reaches `Main is starting`.
- `[PASS]` Intel Alder Lake-N `/dev/dri` devices are visible.
- `[PASS]` VAAPI 1.23 opens Intel iHD 26.1.2.
- `[PASS]` oneVPL GPU implementation becomes available after installing `libmfx-gen1.2`.
- `[PASS]` `vpl-inspect` reports Intel implementations.
- `[PASS]` Ubuntu system FFmpeg `h264_qsv` test encoded 60 frames and exited 0.

## Still required after compilation

The project-built v0.4.1 `ffmpeg.real` was compiled/deployed and successfully reached the Intel QSV/iHD path during live MiniPlayer transcoding. The remaining failure was the MiniPlayer wire-format rewrite, corrected in v0.4.2.

After building/deploying v0.4.4, run:

```bash
docker exec sagetv-u26-test gpu-check
```

and verify the `PROJECT FFMPEG.REAL QSV TEST` section still succeeds. Then repeat the real MiniPlayer fixed-push playback test and a file switch. Full release validation requires both video+audio playback and no SageTV/native abort.

## Windows

The final Windows x64 PE build still needs to be compiled/tested with the supplied BtbN/Docker toolchain on the user's build machine.

## Runtime Docker v4 validation - 2026-08-24

- `[PASS]` shell syntax validation for every script in `sagetv-runtime-docker/`.
- `[PASS]` static checks for Ubuntu 26.04, Intel oneVPL runtime, `tini`, in-container supervisor, Docker restart policy, unlimited core size, ptrace/debug settings, and persistent HotSpot error path.
- `[PASS]` live supervisor test: a fake SageTV process exited with code 134 (`SIGABRT`), the supervisor kept running, restarted SageTV, and later forwarded SIGTERM cleanly to the isolated SageTV process group.
- `[PASS]` existing MIM v0.4.4 regression tests and `ffmpeg_init.sh` tests remain unchanged and pass.

The SageTV runtime Docker itself was not launched in this artifact environment; the live Unraid validation remains the next step.

## Additional confirmed runtime findings - 2026-08-24

### SageTV native PNG crash

CONFIRMED from a native core dump:

```text
SIGABRT
 -> libc abort
 -> system libpng16 png_error
 -> system libpng16 png_set_filler
 -> SageTV LoadPNG (imageload.c:171)
 -> Java_sage_media_image_ImageLoader_loadScaledImageFromFile
```

Manual validation: removing/renaming the triggering channel-logo PNG stopped the SageTV crash.

A diagnostic `DT_SYMBOLIC` binary made from the supplied original `libImageLoader.so` passed a local symbol-preemption regression test. This demonstrates the old bundled-libpng/interposition mechanism, but a real user deployment test of that binary is not recorded here. The preferred Ubuntu 26 source modernization is system libpng16 + updated ImageLoader error handling/tests.

### Current QSV regression after Codex Docker rebuild

FAIL / unresolved:

- COPY/direct mode works.
- QSV path produces no video.
- Latest MIM log shows FFmpeg is spawned and then immediately terminated by `stdin HUP`, signal 15, rc 143.
- This must be diagnosed as a control-pipe/file-descriptor lifecycle regression before changing QSV encode policy.
- Same log shows MIM 0.4.4 paired with an `ffmpeg.real` identifying as v0.3.9; deployment consistency must be corrected.
## Field continuation validation - 2026-08-24

- PASS: MIM C++17 static compilation.
- PASS: `code/mim/tests/run_mim_tests.sh` after active-file software fallback.
- PASS: `code/mim/tests/run_init_tests.sh`.
- PASS: `validate_static.sh`.
- PASS: forced MPEG-TS argument is positioned before the active input.
- PASS: readiness gate recognized tested MPEG-2 live input in 13-250 ms.
- PASS: SageTV container restart and TCP reachability on port 42024.
- FAIL: live MiniClient playback is not reliable on all tested channels.
- FAIL: some live starts produced audio without video.
- FAIL: some 59.94 fps software transcodes stalled initially under high CPU.
- ROLLED BACK: 250 ms network encoder delay.
- ROLLED BACK: active-file MPEG-4 Part 2 preservation (no audio or video).
