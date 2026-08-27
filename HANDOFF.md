# Handoff

Current state: MIM 0.4.5 and FFmpeg `n9.0.1` build successfully for Linux amd64
and Windows amd64 in the single `opensagetv-vibe-dev` environment. Generated
artifacts and checksums live under `output/<target>` and are not committed.
The Linux/Windows toolchain Docker stages are owned by
`opensagetv-vibe-build-env`; this repository has no standalone Docker image or
container lifecycle.

`settings.ini` is explicitly checked out with LF endings. Keep that
`.gitattributes` rule: Windows CRLF conversion changes sourced shell values and
causes the unified toolchain pin check to fail during a fresh-clone build.

The complete non-Android suite passes. It covers installer backup/rollback,
argument mapping, `videorateadapt`/`inactivefile`, EOF and signal teardown,
failure containment, completed and growing MPEG-TS, joining a partially written
recording, repeated 59.94 fps starts, audio/video integrity, and orphan checks.
On real Unraid Intel hardware, QSV and both VAAPI decode modes emitted valid
audio/video and fully decoded; an invalid render device selected `libx264`
before stream start. The unified `all` run and clean production-container test
also pass.

`MIM_ENABLED=false` remains the mandatory stable default. Android MiniClient
render/decoder behavior cannot be proven by server-only tests. Do not promote
MIM until repeated Android playback/channel-switch commissioning passes and
real AMD VAAPI and NVIDIA NVENC devices have been tested. The static MIM tests
already validate the command construction for those backends.

The runtime image installs Linux files only. Windows artifacts remain deliverables for native Windows SageTV.
