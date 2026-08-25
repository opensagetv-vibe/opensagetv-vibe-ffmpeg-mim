# OpenSageTV FFmpeg/MIM

Modern FFmpeg and SageTV Media Interface Module add-on for Linux/amd64 and
Windows/amd64. The add-on will be included in the runtime but remain disabled
until live MiniClient playback passes commissioning tests.

The source has been extracted from the v0.4.4 Ubuntu 26 handoff and builds both targets in one Linux Docker builder. The FFmpeg source baseline is `n9.0.1`; SageTV's runtime `videorateadapt` control is applied as a narrowly scoped patch.

```bash
./code/docker/run_unified_builder.sh all
```

Outputs are written to `output/linux-x64` and `output/windows-x64`. Linux/Unraid release images consume only the Linux directory. Windows artifacts are retained as a separate release package.

MIM is experimental and must remain disabled by default in the SageTV runtime. Static builds and installer rollback tests pass, but the live control regression currently fails during the `videorateadapt`/`inactivefile` handoff. This is a release gate, not a skipped test.
