# OpenSageTV Vibe FFmpeg/MIM tasks

This is the only active FFmpeg/MIM backlog. Completed work is removed and
recorded in `CHANGELOG.md` and `HANDOFF.md`.

- [ ] Complete physical AMD VAAPI and NVIDIA NVENC tests. Intel VAAPI and
  deliberately failed-hardware software fallback pass; Intel QSV remains
  experimental after reproducible return-code-139 crashes.
- [ ] Repeat the complete final-runtime Android matrix on the exact release
  artifacts, including completed/growing media, four 2.1/5.1 changes, EOF, shutdown,
  teardown, captions, and no orphan jobs.
- [ ] Pass repeated real-client channel-change commissioning and retain
  `MIM_ENABLED=false` until every live-playback gate passes.
