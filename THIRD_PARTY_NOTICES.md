# Third-party notices

The OpenSageTV Vibe MIM wrapper, workflow scripts, and original project
documentation are licensed under Apache-2.0 as described in `LICENSE`.

## FFmpeg

This repository builds a patched FFmpeg `n9.0.1` source tree pinned to commit
`bf1b838f2ab88b4f8fd83443325c782ea0e0f7fa`. FFmpeg is licensed primarily
under LGPL-2.1-or-later, but a configured binary may become GPL-licensed when
GPL components are enabled. See <https://ffmpeg.org/legal.html> and inspect
`ffmpeg -L` plus the generated build report for the exact binary configuration.
The narrowly scoped SageTV rate-control patch is distributed for application
to that source and does not relicense FFmpeg.

## Codec and hardware components

The unified FFmpeg toolchain may enable independently licensed components,
including x264, x265, Intel oneVPL/Media SDK, VAAPI, NVIDIA codec interfaces,
AMD AMF, and related platform libraries. Their licenses and any corresponding
source obligations continue to apply. This Git repository intentionally does
not commit generated FFmpeg binaries.

Before distributing a compiled binary, retain its build report, license output,
exact source pin, patches, and all notices/source offers required by the
enabled configuration. OpenSageTV Vibe's Apache-2.0 license does not replace
or weaken those third-party terms.
