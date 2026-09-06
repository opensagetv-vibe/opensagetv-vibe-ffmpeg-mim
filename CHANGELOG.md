# Changelog

## Unreleased

- Prepared v0.4.8 source for public GitHub development with consistent
  contributor, security, third-party, source-only CI, task, handoff, and
  unified-workflow documentation. The repository does not publish a container
  image; generated binaries remain ignored commissioning artifacts.
- Raised the completed-file warm probe cache from the unsafe 64 KiB/100 ms/128
  packet shortcut to 512 KiB/500 ms/1024 packets. The old shortcut caused
  FFmpeg to emit the fixture's 0.5-second A/53 cues at roughly half cadence and
  accumulated about five seconds of caption drift while video and the SageTV
  timeline remained correct. Wrapper fallback defaults and regression tests
  now enforce the safe values.
- Rebuilt and deployed only the 0.4.7 MIM wrapper through the appdata update
  path; no container image rebuild was required. The deployed wrapper SHA-256
  is `4b73733245dfe4ae83a17b90f6e315f7bf2a36daf52290671ad16e057b138993`.
- Passed the exact 0.4.7 hardware-only seven-selection Android matrix and the
  row-14 Fixed/MIM and Push caption/timeline gates. The stable middle cue is
  within one second of the visible STV time and no longer covers the timeline.
- Passed the repeated Fixed/MIM synchronization gate after server-owned FF,
  REW, and FF_2. Each seek recovered real A/V and stable captions in 328-331
  ms; final caption/media-clock cadence drift was 4 ms. The retained Android
  screenshot is `20260830-191129_caption-media3-fixed-visible.png`.

- Disabled completed-file MPEG-TS seek preroll by default after physical
  testing proved its hidden five-second input seek could shift SageTV's
  reported timeline and A/53 caption presentation by approximately five
  seconds relative to the visible generated clock. Exact SageTV seek times are
  now preserved by default; the old workaround remains an explicit opt-in for
  a decoder/GPU combination that genuinely requires it.
- Added default and opt-in dry-run regression coverage so the normal path must
  contain only SageTV's requested `-ss`, while the compatibility setting still
  produces the older bounded input/output-preroll command when enabled.

## 0.4.7

- Closed the previously retained Android commissioning failures: IJK passed
  repeated completed playback plus four 2.1/5.1 live changes, and legacy
  ExoPlayer software decode passed prerecorded pause/play and the full control
  sequence. MIM remains disabled by default pending exact-release repetition
  and physical AMD/NVIDIA tests.
- Packaged and installed the exact 0.4.7 Linux output on the isolated Unraid
  test server through the verified component-only appdata update. The update
  passed hash, restart-health, status, backup, and rollback gates without an
  image rebuild or any restart of protected production services.

- Generalized caption-preserving input decode from QSV to QSV, VAAPI, and
  NVENC. When `preserve_a53cc=true`, FFmpeg decodes MPEG-2 in software to retain
  `AV_FRAME_DATA_A53_CC`, then still performs GPU filtering/upload/encoding and
  writes the station's existing captions with `-a53cc 1`.
- Added `closed_captions.caption_software_decode=true` as the cross-vendor
  policy. Older INI files without that key retain the prior
  `qsv_software_decode` behavior; explicitly disabling the new key restores a
  hardware-input-decode validation path.
- Kept generated timestamp caption injection strictly in the Android test
  fixture. Real recordings and live ATSC channels are never modified or given
  synthetic captions.
- Rebuilt both targets from pinned FFmpeg `n9.0.1` in the unified environment
  on 2026-08-30. Linux `ffmpeg.real`/`ffmpeg_MIM` SHA-256 values are
  `e57508fe3ceb35d93bb16efb0d43b069719f7de6d1782eee6409e6d9f1aa7754`
  and `ccb78765a843b7a146aa2311c91df12aae4e17786c57ceaf41a74cf7765189f7`;
  Windows `ffmpeg.real.exe`/`SageTVTranscoder.exe` values are
  `32d28a80b8c8bd01f541665bf0bd503c540fddec48d3393d990a7ccfa6a58586`
  and `3501282d08ad327036f54f10915e7da105fa494272371dda520bc7af816f2107`.
- Passed the complete non-Android 0.4.7 gate on the rebuilt unified image:
  installer backup/rollback, MIM mapping/control/crash containment, completed
  A/V, growing join-in-progress, three repeated switches, complete decode, and
  no orphan processes. First output measured 1610 ms for the partial join and
  175-177 ms for the complete repeated starts.

## 0.4.6

- Changed the Linux automatic hardware preference to
  `vaapi,qsv,nvenc,software` after FFmpeg 9 QSV stress runs reproducibly exited
  with return code 139 on the commissioned Intel i915 host. VAAPI is now the
  tested Intel default; QSV remains an explicit experimental option.
- Defaulted hardware input decode off while retaining hardware encode. This
  keeps MPEG-2/A53 captions available to the encoder and avoids the unstable
  active-file QSV decode path.
- Added caption-preserving `-a53cc 1` output policy and physically verified
  visible CEA-608/708 through H.264/VAAPI Fixed playback.
- Added completed MPEG-TS seek preroll with output offset and MPEG-TS
  discontinuity/header resend so FF/REW and absolute jumps restart on usable
  decoder context.
- Added machine-readable `--mim-status` job evidence and fail-closed Android
  commissioning checks for backend, encoder, hardware-encode state, input,
  freshness, and cleanup.
- Deployed the exact 0.4.6 Linux artifact to the isolated Unraid container and
  passed Media3 Fixed/hardware prerecorded controls, captions, and four live
  2.1/5.1 changes. Telemetry proved fresh `vaapi`/`h264_vaapi` jobs and no
  active MIM jobs after either teardown.
- Deliberately invalidated the Intel render device and verified deterministic
  software fallback (`libx264`) through completed and growing-live Android
  playback, then restored and re-verified `/dev/dri/renderD128` VAAPI use.
- Isolated the MIM unit-test compilation in its temporary directory. Running
  the test suite no longer overwrites the validated Linux release wrapper or
  leaves `SHA256SUMS.txt` stale after a successful build.
- Added the common AI takeover, task, changed-files update, resumable unified
  gate, and handoff ZIP workflow without changing FFmpeg/MIM behavior.
- Forced INI build settings to LF in Git checkouts. This prevents a Windows
  fresh clone from appending a carriage return to `FFMPEG_TAG` and
  `FFMPEG_COMMIT` when `settings.ini` is sourced inside the Linux container.
- Removed the standalone FFmpeg/MIM Dockerfile, image bootstrap, cleanup
  helper, and temporary build-container lifecycle. Component launchers now
  delegate to the sibling `opensagetv-vibe-build-env` wrapper and reuse
  `opensagetv-vibe-dev`.
- Pinned the expected FFmpeg source commit and made component compilation fail
  if the unified image contains a different tag or commit.
- Updated build reports to identify the unified build-environment and internal
  toolchain rather than a separate builder image.
- Renamed the project and shared build-environment references to the
  `opensagetv-vibe-*` namespace without changing the FFmpeg/MIM binary ABI.
- Advanced the wrapper and FFmpeg build suffix to 0.4.5.
- Fixed the FFmpeg option/control regression and retained deterministic
  `videorateadapt`, `inactivefile`, EOF, signal, and descendant-process teardown
  tests.
- Stopped using the reduced probe-cache shortcut for active/growing files. A
  cache hit could omit audio or video depending on MPEG-TS packet order when a
  client joined an already growing recording.
- Added a bounded Linux hardware-encoder preflight. QSV, VAAPI, and NVENC are
  selected only after a real one-frame encode succeeds; a failed initialization
  falls through to the next backend or `libx264` before playback starts.
- Cached successful preflights by FFmpeg binary, backend, encoder, and render
  device, and prevented the same failed backend from being probed twice during
  one selection pass.
- Corrected NVENC hardware-decode filtering to use CUDA-native filters.
- Corrected VAAPI software-decode encoding with an explicit device,
  `format=nv12`, `hwupload`, and VAAPI scaling, and corrected full-VAAPI decode
  filtering.
- Added real media tests for completed recordings, growing MPEG-TS,
  join-in-progress playback, 29.97/59.94 fps input, repeated starts/teardowns,
  A/V presence and start-time alignment, full decode, and orphan detection.
- Built and checksum-validated Linux amd64 and Windows amd64 artifacts in the
  unified build environment.
- Commissioned Intel QSV, Intel VAAPI, and software fallback on Unraid. AMD and
  NVIDIA command construction is tested, but matching physical hardware and
  Android MiniClient commissioning remain release gates.
- Kept `MIM_ENABLED=false` as the stable runtime default.

## 0.4.4 extraction baseline

- Created the local FFmpeg/MIM extraction scaffold.
- Extracted the v0.4.4 wrapper, FFmpeg 9 runtime-rate-control patch, configuration, tests, diagnostics, and unified Linux/Windows toolchain.
- Rebuilt Linux amd64 and Windows amd64 FFmpeg, ffprobe, and MIM artifacts from source in one Docker container.
- Preserved Intel QSV, AMD VAAPI, and NVIDIA capability configuration; hardware decode defaults true.
- Confirmed install/backup/rollback tests pass.
- Recorded the then-unresolved live control regression and kept runtime
  activation disabled by default.
