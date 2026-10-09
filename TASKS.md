# OpenSageTV Vibe FFmpeg/MIM tasks

> **Pre-commit task maintenance:** Immediately before every repository commit, move
> completed `[x]` items out of active sections and into
> `## Checklist change ledger`. Preserve IDs, evidence, and context; never
> discard completion history. Active sections contain unchecked work only.

This is the only active FFmpeg/MIM backlog. Completed work moves to the
checklist change ledger; release evidence is also recorded in `CHANGELOG.md`
and `HANDOFF.md`.


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
## Checklist change ledger

- [x] **PLUGIN-RELEASE-001 - Publish paired MIM0.4.11 runtime.** Closed
  2026-10-09 under explicit user approval. Both wrappers built against unchanged
  independently verified0.4.10 FFmpeg/FFprobe engines. CLI/static/containment,
  deterministic actual packages and release-source CI pass. Public prerelease
  at a2ca1d00faa32319f03383fae4aab57248c5b0c5; all3 downloaded assets match
  GitHub digests. Linuxb0113e24/Windows5f0643d3 match catalog runtime MD5s.
  Paired FFmpeg0.1.5 catalog submission: OpenSageTV/sagetv-plugin-repo#127,
  OPEN/MERGEABLE, not merged/live. No new Windows/GPU physical matrix or
  promotion. Compact workspace artifacts/results/PLUGIN-RELEASE-001 evidence;
  completed temporary staging retires recoverably. Post-release documentation
  closure does not move the immutable tag or alter runtime payloads.

- 2026-10-09 pre-commit publication review: explicit user approval, unchanged
  verified FFmpeg engines and both rebuilt MIM wrappers; affected CLI/static/
  containment/deterministic package gates pass. Publication remains unchecked
  until public download verification. No completed checkoffs in active work;
  workspace PLUGIN-RELEASE-001 priority reviewed, Android order306 unchanged.

- 2026-10-08 pre-commit source-sync review: explicit owned-Direct capability
  source/Linux commissioning is retained; static and argument/lifecycle/crash-
  containment gates pass. Matching canonical Windows/Linux runtime publication
  is not part of this Android release. Completed entries ledger-only; order305.

- [x] **MIM-DIRECT-CAP-001 - Explicit owned-Direct runtime feature gate.**
  Parent Android TABLET-MIM-001 / FFmpeg Plugin MIM-DIRECT-005. Proven old175
  wrapper forwarded private Direct markers into FFmpeg (exit8). Add typed
  ownedDirectStreams capability; plugin rejects absent/false/untyped/unrelated
  feature. CLI/mapping/lifecycle/crash-containment tests pass; plugin-owned Linux
  candidate6e80a2d9 actual175/232 execution/ABI checks preserve INI/Core/root
  FFmpeg and rollback files.175 real owned playback and both failure recovery
  paths pass;232 VAAPI full decode/encode is verified. No unrelated matrix.
  This closes the source/Linux commissioning gate, not canonical publication:
  rebuild matching Linux/Windows release payloads under the existing release
  gates before shipping this new feature; no new Windows binary was deployed.

- [x] **MIM-FIXED-003 - Caption/subtitle transport gates (2026-10-05).** CEA
  uses the timed side channel while applicable Direct MPEG-TS output preserves
  Teletext and DVB bitmap PIDs independently. Prior Linux and Windows physical
  gates cover completed/growing MPEG-2 and H.264, AC-3/AAC, language/service
  selection, pause/resume, seek, program/channel replacement, EOF/fallback,
  repeated teardown, and zero-orphan cleanup. The final stock `.175` HD200
  compatibility run retained unmodified legacy MPEG-2/CEA, H.264/AC-3,
  authored-DVD, STOP/Home, and live-transition behavior; stock Teletext/DVB
  non-rendering was reproduced as an old stock-FFmpeg limitation rather than a
  MIM regression. No synthetic caption stream is inserted into real media.
  Evidence: workspace `artifacts/mimfix003-hd200/RESULTS.md`.


### Archived completed checklist items (2026-09-30)

These completed items were moved from active task sections immediately
before commit. Stable IDs, acceptance evidence, and source context are
preserved; active sections contain unchecked work only.

#### From `# OpenSageTV Vibe FFmpeg/MIM tasks`

Parent context: `- [ ] **MIM-FIXED-003 - Caption/subtitle transport gates.** Verify that CEA`

  - [x] Linux VAAPI Direct Transcode passes full-GPU decode and encode with
    deinterlacing Auto, On, and Off. Windows Haswell QSV passes full-GPU with
    Off and accurately reports the mixed fallback for Auto/On. The Off policy
    passed physical non-Pro playback, seek, pause/resume, CEA event-225
    delivery, teardown, and zero-orphan checks on both platforms.
