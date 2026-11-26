# OpenSageTV Vibe FFmpeg/MIM

Development SETTINGS-005 exposes optional `hardwareBackendRevision=1` for an
owned Direct encode only. Private `-sagetvhardwarebackend` is validated and
removed before FFmpeg; its in-memory session choice never edits authoritative
INI. Explicit QSV/NVENC/VAAPI/AMF selections use the existing qualified backend
pipeline and refuse unsupported hardware without an unrequested fallback.
Auto and ordinary callers retain their existing selection. The shipped
Linux/Windows targets cannot execute macOS VideoToolbox; that named Web parity
choice refuses explicitly here. Engine pins/binaries remain unchanged.

Development0.4.20 adds a Windows OS-owned caption claim so terminating MIM
cannot leave its active slot file behind. The actual Java8 forced-stop probe
fails before and passes after the fix. It retains0.4.19's pipe/device changes
below; installed acceptance and remaining scope belong to MIM-WIN-001.

Development0.4.19 removes the Windows raw-stdin pump throttle and explicitly
initializes D3D11 for software-frame H.264 QSV(default adapter0, optional
`hardware.windows_qsv_device`). Caller-supplied devices/hardware input and
other platforms/codecs are unchanged. Real Windows185 comparisons, Java8 pipe
tests and installed consumer results are owned by MIM-WIN-001. This is not
universal Windows/QSV or in-place-bitrate certification; publication is held.

Development0.4.17 fixes the reproduced ordinary Fixed Linux H.264 QSV
caption-encode crash by limiting system-memory submissions to one frame in
flight. Captions and GPU encoding remain enabled; bitrate, VBV, filters and
cadence are unchanged. Installed through FFmpeg Plugin0.1.32 on stock232;
Non-Pro Media3/Legacy Exo pass sustained post-seek output, repeated seeks,
pause/resume and actual EOF. Both wrappers build against unchanged engines.
See `artifacts/results/MIM-QSV-001/RESULT.md` for the causal evidence and
limits; this is not universal driver, hardware-decode or Windows certification.

Development0.4.16 adds optional `runtimeBitrateControlRevision=1` for Linux
H.264 QSV file-input jobs. Both site and session opt-ins are required. Private
`-sagetvruntimebitrate` is consumed by MIM; it never leaks to ordinary FFmpeg
or enables raw-pipe/copy/unsupported encoders. Existing `videorateadapt` is
reused, not a second external command protocol. Native Web argv and legacy
Direct mapping both select the qualified CBR profile. Linux/Windows wrappers
are rebuilt; the four qualified engine binaries remain unchanged.
Actual stock232 synthetic settings diagnostic measures6.09→2.02→2.47Mbps in
one QSV process with clean60fps decode. See the owning FFmpeg Plugin contract;
consumer/network and unavailable-vendor scope remains separately recorded.

Development0.4.15 adds the optional `responsiveHlsRevision=1` contract for
FFmpeg Plugin0.1.28. Only an explicitly requested owned Direct segment/M3U8
transcode consumes `-sagetvresponsivehls` and applies forced IDR to the actual
H.264 QSV encoder. The flag is removed for other scopes and other encoders
never receive the QSV-only option. No FFmpeg/FFprobe engine, default INI or
ordinary Fixed behavior change. Both wrappers build; local CPU proof is not
physical Windows/GPU/device/WAN certification. Public0.4.11 is unchanged.

Modern FFmpeg and SageTV Media Interface Module add-on for Linux/amd64 and
Windows/amd64. The stock container installs this only through the separate
FFmpeg plugin, never by image seeding or replacing stock FFmpeg. Public0.4.11
remains unchanged;0.4.14 is the qualified raw-duplex development base for
the optional0.4.15 HLS change above.
Its bounded Linux pipe correction is qualified on actual stock232 WTTW fullGPU
growth/natural960s completion, plus affected one-picture/DVD/caption/control
rows. Exact original lost-file stall cause remains unproven. Physical Windows
and MIM-STDIN-001's separate legacy Fixed row remain explicitly pending.
The preceding0.4.13 MIM-STDIN-001 candidate
It fixes Linux raw-pipe EOF truncation, is installed through FFmpeg Plugin
0.1.25 on stock232, and retains the existing FFmpeg/probe engine bytes.
Six exact EOF count/hash cases and affected control/media/package tests pass;
broader physical qualification remains tracked in TASKS.md.

The current public add-on version is 0.4.11. It builds both targets in the unified
Ubuntu 26/OpenJDK 11 development container. The FFmpeg source baseline is
`n9.0.1`; SageTV's runtime `videorateadapt` control is applied as a narrowly
scoped patch.

The0.4.11 prerelease rebuilds only MIM for Linux/Windows. Its FFmpeg/FFprobe
engines are byte-identical to the qualified0.4.10 packages; the engine banner
therefore retains its0.4.10 build label. No new GPU/Windows physical matrix is
implied. Installing the paired FFmpeg Plugin0.1.5 provides the negotiated
owned-stream recovery used by Android0.5.101; older/missing support keeps
ordinary Fixed playback.

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
commissioned stable default; QSV remains behind VAAPI in Auto preference.
The reproduced caption-bearing system-memory H.264 crash is corrected in
development0.4.17; other QSV/driver scopes require their own qualification. Final
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
