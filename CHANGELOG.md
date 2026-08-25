# Changelog

## Unreleased

- Created the local FFmpeg/MIM extraction scaffold.
- Extracted the v0.4.4 wrapper, FFmpeg 9 runtime-rate-control patch, configuration, tests, diagnostics, and unified Linux/Windows toolchain.
- Rebuilt Linux amd64 and Windows amd64 FFmpeg, ffprobe, and MIM artifacts from source in one Docker container.
- Preserved Intel QSV, AMD VAAPI, and NVIDIA capability configuration; hardware decode defaults true.
- Confirmed install/backup/rollback tests pass.
- Recorded the remaining live control regression as a failure and kept runtime activation disabled by default.
