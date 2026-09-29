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
- [ ] **MIM-FIXED-001 - Original-compressed-video caption tap.** Add a bounded
  per-job A/53 extraction path that reads the original compressed video before
  GPU decode and publishes only timed CEA-608/708 records to the owning
  Standard-plugin session. Keep media payload, caption text, paths, and
  credentials out of diagnostics. The tap must not add a second selectable
  video PID to SageTV's media output, block transcoding, or change older-client
  behavior. Prove full GPU decode/deinterlace/encode and caption extraction in
  the same real FFmpeg gate, plus seek/flush/wrap/discontinuity, growing input,
  backpressure, teardown, and software fallback.
- [ ] **MIM-FIXED-002 - Optional direct-session output contract.** After the
  caption tap passes, expose bounded media/status/seek lifecycle primitives for
  the stock-compatible Standard plugin to own an opted-in Android session.
  Preserve the existing stdin/stdout replacement-transcoder mode unchanged and
  support explicit `copy` and `transcode` policies. Copy must not decode or
  encode video/audio; it may only remux for a negotiated compatible container
  while preserving elementary streams, languages, timestamps, CEA, Teletext,
  and DVB descriptors. It must reject an incompatible copy contract rather
  than silently encode. Transcode retains the fallback order full GPU ->
  hardware encode with software decode/filters -> software. Require a unique
  session token, reconnect and live growth; a failed direct session must
  terminate cleanly and permit ordinary stock Fixed playback.
- [ ] **MIM-FIXED-003 - Caption/subtitle transport gates.** Verify that CEA
  uses the timed side channel while Teletext and DVB bitmap subtitle PIDs are
  preserved independently in applicable MPEG-TS output. Test completed/live
  MPEG-2 and H.264 sources, multiple languages/services, pause/resume, seek,
  stream/program changes, EOF, and repeated teardown without duplicate
  captions, timestamp regressions, leaked processes, or synthetic caption
  insertion into real media.
  - [x] Linux VAAPI Direct Transcode passes full-GPU decode and encode with
    deinterlacing Auto, On, and Off. Windows Haswell QSV passes full-GPU with
    Off and accurately reports the mixed fallback for Auto/On. The Off policy
    passed physical non-Pro playback, seek, pause/resume, CEA event-225
    delivery, teardown, and zero-orphan checks on both platforms.
