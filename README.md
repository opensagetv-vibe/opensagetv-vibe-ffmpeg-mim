# OpenSageTV Vibe FFmpeg/MIM

Modern FFmpeg and SageTV Media Interface Module add-on for Linux/amd64 and
Windows/amd64. The add-on will be included in the runtime but remain disabled
until live MiniClient playback passes commissioning tests.

The current add-on version is 0.4.5. It builds both targets in the unified
Ubuntu 26/OpenJDK 11 development container. The FFmpeg source baseline is
`n9.0.1`; SageTV's runtime `videorateadapt` control is applied as a narrowly
scoped patch.

```bash
./code/docker/run_unified_builder.sh all
```

That compatibility launcher delegates to the sibling
`opensagetv-vibe-build-env` wrapper. It never creates a component-specific
image or container.

Outputs are written to `output/linux-x64` and `output/windows-x64`. Linux/Unraid release images consume only the Linux directory. Windows artifacts are retained as a separate release package.

MIM is experimental and remains disabled by default in the SageTV runtime.
The non-Android gate passes: installer rollback, option/control forwarding,
crash containment, completed recordings, growing/join-in-progress MPEG-TS,
repeated start/stop, Intel QSV/VAAPI, and software fallback. Final promotion
still requires repeated real Android MiniClient commissioning plus AMD and
NVIDIA hardware tests.

Run only the complete non-Android MIM suite through the shared build container:

```bash
../opensagetv-vibe-build-env/opensagetv-vibe-dev.sh test-mim
```

The suite writes `output/test-results/non-android-suite.log` and returns
non-zero if any required check fails.
