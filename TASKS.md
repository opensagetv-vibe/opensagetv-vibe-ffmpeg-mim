# OpenSageTV Vibe FFmpeg/MIM tasks

This is the only active FFmpeg/MIM backlog. Completed work is removed and
recorded in `CHANGELOG.md` and `HANDOFF.md`.

- [ ] Finish isolated-server commissioning of the locally passing stock-era
  thumbnail command compatibility. MIM now removes the historical private
  frame-selection options, maps numeric `-vsync`, replaces the removed
  `-deinterlace`, and converts SageTV's old `crop=0:8:0:0` argument order only
  for recognized thumbnail jobs. The exact command produces a valid 512x288
  MJPEG with FFmpeg 9; the isolated `.232` SageTV service must be restarted
  before its server-generated artwork can be verified.
- [ ] Complete physical AMD VAAPI and NVIDIA NVENC tests. Intel VAAPI and
  deliberately failed-hardware software fallback pass; Intel QSV remains
  experimental after reproducible return-code-139 crashes.
- [ ] Evaluate legacy Kepler NVENC compatibility using the Windows Quadro
  K1100M test host. Prefer making unused modern CUDA entry points optional in
  the dynamic loader; otherwise produce a separately identified legacy-NVENC
  build against compatible NVIDIA codec/CUDA headers. Keep Intel QSV as the
  commissioned backend until a real H.264 NVENC encode passes.
- [ ] Repeat the complete final-runtime Android matrix on the exact release
  artifacts, including completed/growing media, four 2.1/5.1 changes, EOF, shutdown,
  teardown, captions, and no orphan jobs.
- [ ] Pass repeated real-client channel-change commissioning and retain
  `MIM_ENABLED=false` until every live-playback gate passes.
