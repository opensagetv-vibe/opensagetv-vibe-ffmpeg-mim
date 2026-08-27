# Changelog

## Unreleased

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
