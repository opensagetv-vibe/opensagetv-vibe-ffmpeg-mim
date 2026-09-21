# OpenSageTV Vibe FFmpeg/MIM

Modern FFmpeg and SageTV Media Interface Module add-on for Linux/amd64 and
Windows/amd64. The add-on will be included in the runtime but remain disabled
until live MiniClient playback passes commissioning tests.

The current add-on version is 0.4.9. It builds both targets in the unified
Ubuntu 26/OpenJDK 11 development container. The FFmpeg source baseline is
`n9.0.1`; SageTV's runtime `videorateadapt` control is applied as a narrowly
scoped patch.

MIM also preserves SageTV's legacy FFmpeg command contracts. In particular,
current FFmpeg metadata output is adapted to the stream-index syntax expected
by stock SageTV, so imported MKV/AVI duration and stream discovery work without
repairing media files. When stock MiniPlayer subsequently requests its legacy
`-f dvd` compatibility stream without an explicit video codec, MIM remuxes the
existing compatible streams to MPEG-TS instead of passing copied H.264 to the
incompatible DVD muxer. This changes only the temporary network transport; it
does not rewrite the library file.

For optional transformed DVD playback, the sibling SageTV FFmpeg plugin owns
the Core extension provider and invokes MIM's existing `-sagetvdiscstream`
mode only after `--mim-capabilities` reports `dvdStreamTransform: true`.
SageTV Core knows only the generic `dvd_mpegts_v1` transport and has no
MIM/FFmpeg process dependency. If this runtime or capability is absent, the
updated Core safely retains native DVD playback.

```bash
./code/docker/run_unified_builder.sh all
```

That compatibility launcher delegates to the sibling
`opensagetv-vibe-build-env` wrapper. It never creates a component-specific
image or container.

The standard takeover/update entry points are documented in
[`WORKFLOW.md`](WORKFLOW.md) and work from any caller directory.

Outputs are written to `output/linux-x64` and `output/windows-x64`. Linux/Unraid release images consume only the Linux directory. Windows artifacts are retained as a separate release package.

This repository publishes source and commissioning/build scripts. It does not
publish a Docker image or push any container to a registry; the shared
`opensagetv-vibe-build-env` image may be exported to a file for offline
commissioning.

MIM is experimental and remains disabled by default in the SageTV runtime.
The non-Android gate passes: installer rollback, option/control forwarding,
crash containment, completed recordings, growing/join-in-progress MPEG-TS,
repeated start/stop, Intel VAAPI, and software fallback. Intel VAAPI is the
commissioned stable path; QSV remains selectable but is behind VAAPI because
the final FFmpeg 9 seek/live stress case reproduced a QSV process crash. Final
Android IJK repeated live switching and legacy-Exo software pause/play now
pass on the commissioned Intel host. Final promotion still requires the exact
release-artifact matrix plus physical AMD and NVIDIA tests.

Caption preservation never injects synthetic text into live television. The
wrapper carries a station's existing ATSC A/53 CEA-608/708 frame data through
FFmpeg with `-a53cc 1`. When preservation is enabled, input decode stays in
software so GPU decoders cannot discard that metadata; filtering/upload and
QSV/VAAPI/NVENC video encoding remain hardware accelerated. Synthetic caption
injection belongs only to the Android project's deterministic test generator.

Run only the complete non-Android MIM suite through the shared build container:

```bash
../opensagetv-vibe-build-env/opensagetv-vibe-dev.sh test-mim
```

The suite writes `output/test-results/non-android-suite.log` and returns
non-zero if any required check fails.

Query the wrapper itself while a Fixed job is running, or after it stops:

```bash
/opt/sagetv/server/ffmpeg --mim-status
```

The JSON response reports all live MIM jobs plus `lastJob` and
`lastTranscodeJob`. Tests must use the latter when a metadata probe ran near
the transcode. A hardware commissioning gate checks `backend`, `encoder`, and
`hardwareEncode`; CPU utilization is not accepted as evidence of GPU use.
The default status directory is `cache/status` beside the wrapper and can be
changed in the `[status]` INI section.
