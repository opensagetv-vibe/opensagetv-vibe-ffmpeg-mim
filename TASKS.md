# OpenSageTV Vibe FFmpeg/MIM tasks

> **Pre-commit task maintenance:** Immediately before every repository commit, move
> completed `[x]` items out of active sections and into
> `## Checklist change ledger`. Preserve IDs, evidence, and context; never
> discard completion history. Active sections contain unchecked work only.

This is the only active FFmpeg/MIM backlog. Completed work moves to the
checklist change ledger; release evidence is also recorded in `CHANGELOG.md`
and `HANDOFF.md`.

Current2026-11-20 reconciliation: MIM-STDIN-001's available Linux gates and
stale MIM-FIXED-001/002 duplicates move to the ledger with exact evidence.
Remaining legacy/general commissioning and vendor/release conditions below
are independent backlog, not unfinished Web Client dependency implementation.
Windows owned-DVD/pipe work was deferred; MIM-WIN-001 below reopens the
requested Windows FFmpeg/MIM consumer qualification only. No full-vendor claim.

## Current Windows commissioning


Current2026-11-24: normal-manager FFmpeg0.1.35/MIM0.4.20 and final Web3.3.0
are loaded on stock185. Windows raw input, exact Java8 owned stop, four Non-Pro
HLS delegates, completed Copy/Direct Transcode, classic Fixed controls, native
DVD and both browser recording/DVD rows pass. Installed isolated public HLS
decoderEOF/caption-clear passes WebKit/software and Chromium/Auto QSV; stock
native terminal Pause is a separate documented boundary, not decoderEOF PASS.
MIM-WIN-001 is complete to the qualified scope in its ledger/result, not
universal Windows GPU or all-defects-fixed certification. Growing Non-Pro
HLS/Copy/Direct/classic controls and actual Chromium/WebKit consumers pass.
Original136 preferences/awake leases restored, borrowed tuner3 released,
37stock files/INI unchanged, independent final sessions/markers/processes0.
Portmaster0x13A remains unchanged by user direction. An intermittent raw-QSV
device failure/WebKit inspection hang does not recur on fresh Auto or four
file/four raw-Java8 comparisons; cause remains unproven, not silently fixed.
Windows in-place rate and full hardware decode/VPP remain unavailable.
See artifacts/results/MIM-WIN-001/RESULT.md and WINDOWS_CRASH.md.
No publication or unrelated matrix replay.

## Other runtime commissioning

MIM-PROBE-001 affected Linux/Non-Pro qualification is complete in the ledger
and artifacts/results/MIM-PROBE-001. Preserve independent platform/vendor
limitations and the deferred original-stock routing boundary; no publication.

MIM-OUTPUT-001 scoped development qualification is complete in the ledger;
retain independent platform/vendor/release conditions below.

- [ ] Finish isolated-server commissioning of the locally passing stock-era
  thumbnail command compatibility. MIM now removes the historical private
  frame-selection options, maps numeric `-vsync`, replaces the removed
  `-deinterlace`, and converts SageTV's old `crop=0:8:0:0` argument order only
  for recognized thumbnail jobs. The exact command produces a valid 512x288
  MJPEG with FFmpeg 9; the isolated `.232` SageTV service must be restarted
  before its server-generated artwork can be verified.
- [ ] Complete physical AMD VAAPI and NVIDIA NVENC tests. Intel VAAPI and
  deliberately failed-hardware software fallback pass. MIM-QSV-001 corrects
  the observed Linux system-memory H.264/caption rc139 scope; other QSV/driver
  paths and all-vendor promotion remain independently unqualified.
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
## Checklist change ledger

- [x] **PUBLISH-001 runtime preparation (2026-11-26).** Explicit user approval
  for0.4.20 beta publication. Current native mapping/probe/backend/caption/QSV/
  raw-EOF/duplex tests and static validation pass. Rebuild deterministic Linux
  and Windows plugin-owned archives from current wrapper outputs; preserve
  qualified engines/INI and platform limitations. Publish before dependent
  plugin manifests, only after the shared pilot and this repository's CI pass.

- [x] **SETTINGS-005 - Optional owned hardware backend pin.** Linked Android
  task: consume a validated private per-session selector only for Direct encode,
  advertise revision1 and refuse unavailable choices without fallback. Auto,
  qualified engines, INI, ordinary legacy callers and stock Core stay unchanged.
  Run native scope/selection tests and affected installed consumer qualification.
  Completed2026-11-26: validated optional backend revision and immutable pin,
  old-wrapper/conflict refusals, full native/provider tests and12actual QSV/
  VAAPI Legacy/responsive output/seek/quality rows pass. Normal manager232
  wrapper1e3eddf6/99matching Java entries preserve stock20/INI/engines.
  Non-Pro115/e0d85ea1 passes4Direct/HLS routes/8seeks/2FF, independent HDMI,
  controls/reset and2AMF refusals.210prefs/CC/power restored; final activity/
  provider0. Compact artifacts/results/SETTINGS-005 and linked Android report
  own exact scope/retirement; no Core/175/Windows/vendor-wide/publication claim.

- [x] **FIXED-002 - Prevent VAAPI caption-header overflow at recording seeks.**
  Linked Android/provider task complete2026-11-26 to mapped Linux affected scope.
  Exact source153.090/419.527s reproduces8192-bit packed-header ENOSPC despite
  available disk. Metadata-only ccrepack preserves hardware pixels/cadence and
  captions; four90-frame comparisons and10scope/native/EOF/duplex/policy/package
  guards pass. Linux349452c7/Windows8c0220cb wrappers rebuilt; engines/INI remain
  unchanged. Normal-manager232 install verified against stock20; Non-Pro11routes/
  33seeks plus FF and independent HLS/IJK HDMI pass,210prefs/CC/power restored,
  final activity/provider0. See artifacts/results/FIXED-002/RESULT.md and linked
  Android VALIDATION/SERVER/CLEANUP reports. No Pro/Windows physical certification,
  native Web VAAPI claim, original FFmpeg/Core replacement or publication.

- [x] **MIM-PROBE-001 - Correct incomplete MPEG-TS encode discovery.**
  Parent Android FIXED-001. Independently reproduced real recording: MIM's
  analyzeduration500000 misses sequence metadata; input90kTBR/unknown format,
  VAAPI RC65535/1 -> error24/exit251. Removing that one option gives proper
  30000/1001 and actual hardware output. Cold/cache TS file encode discovery
  needs a bounded safe budget; preserve larger caller budgets, Copy/non-TS/
  unknown stdin policies and actual cadence. Add failed-before source/mapping
  and real-source installed regression, rebuild wrappers only, normal plugin
  manager update and protected-stock/INI/engine verification. No driver/Core
  edits or silent switch to a different encoder as the claimed fix.

**Completion2026-11-26 supersedes the archived pending wording.** Normal
manager232 loads tested Javaec96a781/wrappercc794701, stock20/INI/engines
unchanged. Native failed-before/mapping/QSV/caption/raw-input/owned-stop and
13installed old/current API/output/policy/isolation/refusal rows pass. Android
115/92df378a passes18supported routes, actual Source6 QSV/software controls,
two explicit failures, seven compatibility rows and HLS session/default A/V.
All210prefs/power/CC restored and final activity/owned sessions0. Written
reproduction/provider API and compact Android validation retained; reviewed
raw retired recoverably. No Windows runtime/all-vendor/Pro/Core/publication claim.

- [x] **MIM-OUTPUT-001 - Owned Direct encoder policy dependency.**
  Authorized2026-11-25; parent FFmpeg Plugin MIM-OUTPUT-001 / Android SETTINGS-003.
  Scoped consumed -sagetvencoderpolicy enforces in-memory default/prefer/software/
  hardware-only without editing INI. Both wrappers build; four engines unchanged.
  CPU fake-policy/real-output and installed232 QSV/software/isolation/seek plus
  affected Non-Pro H.264/HEVC/status gates pass. Full native mapping/raw-input/
  owned-stop regression and independently decoded HEVC segment regression pass
  on unchanged wrappers. No speculative GOP/decoder fix. First provider502 and
  initial HEVC repeat remain unproven observations, not claimed fixed. Native
  Windows policy/every-vendor support and publication are not inferred. Preserve
  stock Core/FFmpeg and existing launcher clients; stock-routing is deferred
  in provider MIM-STOCK-001. Compact provider and Android SETTINGS-003 results
  retain exact builds, observations and restoration evidence.


- [x] **MIM-WIN-001 - Qualify current FFmpeg/MIM on stock Windows185.**
  Authorized/completed2026-11-24. Original0.1.32/.17 candidates advance through
  normal manager to FFmpeg0.1.35/MIM0.4.20, MCP22 and Web3.3.0 development.
  Preserve stock Sage.jar/original FFmpeg/Core/INI; fresh recording/client and
  encoder guards precede restarts. Raw-pipe/EOF, Java8 owned stop, scoped QSV
  device and OS caption lease fixes have failed-before/after proof. Actual
  Non-Pro completed/growing HLS/Copy/Direct/classic controls, four HLS delegates,
  repeated seeks/CEA/decoderEOF/native DVD and Chromium/WebKit recording/DVD/
  growing/isolated public-HLS EOF pass their separately recorded scope.
  Web owns the additional backslash OPENURL parser correction; installed WAR
  9c4cecb7 exactly matches its manager package. Native terminal Pause is not
  HTML decoderEOF. Windows rate capability0 and full hardware decode/VPP are
  unavailable; intermittent QSV device failure is retained, not claimed fixed.
  User-corrected expired account resolved initial SSH refusal without guesses;
  READINESS/AUTH_DIAGNOSTIC preserve that chronology. Matching-symbol0x13A
  implicates Portmaster; user directs leave it unchanged. Authorized service V:
  restoration/exact shared OpenDCT restart clear post-crash environment faults.
  Final19:57Z185/232 recording/UI/client0, slots/processes0;37stock files/INI
  unchanged,136 preferences/awake restored, exact task recordings cancelled/
  tuner3 released. Compact RESULT/FINAL_STATE/CONSUMER_SUMMARY retain evidence;
  redundant owned raw retires recoverably to rootdeleteme. No publication,
  unrelated Linux/phone matrix,175 SageTV or232 installation change.

- [x] **MIM-QSV-001 - Diagnose and correct ordinary Fixed QSV seek crash.**
  User authorized/completed2026-11-24. Standalone same1080i/CEA postseek input
  and GDB locate SIGSEGV in Intel's async H.264 worker without a client. New
  Linux mapped system-memory/caption depth1 retains GPU/captions/rates and
  passes focused before/after argv,33 hardware experiments, four full48s
  decode/1437A53/clock comparisons, both wrappers/unchanged engines, lifecycle/
  EOF/duplex/media/packages and Non-Pro Media3/Legacy Exo actual sustained/
  repeated seek/Pause/Play/EOF/no orphan. HDMI captions/picture reviewed.
  Normal-manager FFmpeg0.1.32/MIM0.4.17 installed; Auto/sitefalse/settings and
  exact INI restored, stock20 intact. Effective driver mitigation, not a proven
  upstream source-line fix/all-platform certification. No publication,175 or
  Windows install/unrelated matrix. `artifacts/results/MIM-QSV-001/RESULT.md`
  retains scope/evidence; completed raw retires recoverably to rootdeleteme.

- [x] **MIM-RATE-001 - Qualify single-process hardware bitrate adaptation.**
  Added2026-11-23 at user request. External encoder experiment authorized
  2026-11-23: E1 QSV external pair PASS (see ledger/result); client/provider
  integration underway2026-11-24UTC: explicit site/client opt-in, Linux-QSV
  rate profile and capability marker implemented; affected qualification pending.
  Parent:
  FFmpeg Plugin REMOTE-004; reuse the existing `videorateadapt` parser and
  encoding-thread hook, not a second control interface. Initial targets are
  QSV and NVENC with bitrate-based rate control, unchanged codec/resolution/
  frame rate and one continuous FFmpeg process. Stock Sage.jar, bundled
  natives, stock FFmpeg and authoritative user INI remain untouched.
  - Negotiate actual encoder/runtime support, rejecting unsupported hardware,
    constant-QP/copy modes and invalid targets without disturbing playback.
    Inspect bitrate/maxrate/VBV handling and encoder reset/IDR requirements;
    AVCodecContext mutation or a forwarded-command log is not success proof.
  - Add bounded request identity, encoding-thread application and trustworthy
    applied/rejected/failed results, including ambiguous/lost-response handling
    without replaying relative bitrate deltas. Preserve stdin/media duplex,
    growing-file/EOF, cancellation, process isolation and legacy callers.
  - Prove measured output-rate decreases and increases with the same encoder
    PID, continuous timestamps, decodable HLS and readable/clearing captions;
    distinguish encoder application from delayed delivery of buffered segments.
    Keep qualified producer replacement available when live reconfiguration
    is unsupported or fails; no permanent multi-rendition ladder.
  - Run focused parser/thread/control/EOF/duplex negatives, affected Linux/
    Windows builds/packages and available QSV/NVENC physical rows only. Record
    unavailable platform/vendor gates as pending, never certified by CPU or
    command-acceptance tests. No three-hour test or unrelated full matrix.
    Share the negotiated contract with Web and Android via REMOTE-004.

  **Completion (supersedes earlier pending checkpoints):** Completed2026-11-24 for the available explicitly negotiated Linux-QSV CBR file profile. Both wrapper builds/mapping/EOF6/1MiB17-burst duplex/signals pass; four qualified engines unchanged. Actual E1, public settings test, Web Chromium/WebKit measured output/GPU/PID/clock and Non-Pro manual/automatic consumers pass. Unsupported modes/vendors are not advertised. Existing physical NVIDIA/AMD/Windows and classic-QSV limitations stay independent below; not universal QSV/NVENC certification. Auto/sitefalse restored; exact result in artifacts/results/MIM-RATE-001/RESULT.md. No publication.

- [x] **MIM-RATE-001/E1 - External same-process QSV bitrate proof.** Completed
  2026-11-24UTC/2026-11-23Chicago before client integration. Installed232
  plugin-owned FFmpeg; constant baseline versus6->2->6Mbps measured actual
  video5999.394->1978.695->5923.077kbps, same PID/start/GPU descriptor,
  3600pictures/60s each, clean full HLS decode and timestamps. Eight measurement
  guards PASS;20stock/engine/probe/INI unchanged. No client, runtime mutation,
  install/restart or publication. Parent stays open for optional protocol/
  production lifecycle and unavailable-vendor/platform qualification.
  Compact artifacts/results/MIM-RATE-001/{RESULT.md,EXTERNAL_QSV.json}.

- [x] **MIM-HLS-001 - Negotiated responsive-HLS encoder control.** Completed
  development scope2026-11-21, parent Android HLS-002 / FFmpeg HLS-START-001.
  Private flag consumed only for owned segment/M3U8 transcode; actual H.264
  QSV receives forced IDR. Legacy/Copy/TS/software/other-GPU negatives pass.
  Mapping/switch/containment, raw EOF6 and1MiB duplex17-burst/signal tests PASS;
  Linux/Windows wrappers0.4.15 build with four unchanged engines. Actual local
  CPU HLS first segment2525→472ms,2.007→1.006s;20s source completes14.372s,
  proving burst returns to pacing. Packages match final wrapper bytes.
  No server/INI/install/publication or physical GPU/Windows/device/WAN claim.
  Compact artifacts/results/MIM-HLS-001/{RESULT.md,CPU_HLS.json}.


- [x] **MIM-STDIN-001 — Drain raw stdin before EOF** (Web WP08-006/WEB085,
  Reconciled2026-11-20: Source/build and available Linux acceptance COMPLETE. Web WP08-006/WEB087 retain failing-before1025-to1024, six count/hash passes, both wrapper builds/unchanged engines, control/media/packages and actual one-picture/feature/root/Stop. Android GATE-001/revision502 qualifies affected Non-Pro classic Fixed; later MIM-PIPE-002 acceptance verifies no-orphan/stock/INI/engine teardown. Physical Windows remains DEFERRED.

  Original specification and dated checkpoints (historical; pending wording
  below is superseded only within the scoped closure above):
  priority2026-11-18). Exact stock232 one-picture DVD has18432bytes; real
  FFmpeg decodes it but MIM sees only NAV/no video. Deterministic synthetic
  test proves1025bytes become1024: POLLIN|POLLHUP reads one chunk then closes
  child pipe with unread bytes. Browser cannot reconstruct bytes lost before
  conversion. Fix Linux MIM to read through HUP until real read()==0, retain
  control EOF/Stop/isolation semantics and no input retry. Six exact count/hash
  cases pass after/fail before. Build only both wrappers against unchanged
  engines, affected mapping/control/media/package gates, normal FFmpeg plugin
  manager update on stock232 and actual one-picture/ordinary Fixed/caption/
  teardown checks. No Core/stockFFmpeg/INI/publication; Windows physical deferred.

- [x] **MIM-FIXED-001 - Original-compressed-video caption tap.** Add a bounded
  Reconciled2026-11-20: Stale duplicate of the completed owning FFmpeg Plugin MIM-FIXED-001 side-channel contract and this runtime's checked MIM-FIXED-003 physical transport matrix. Close to those exact Linux/Windows caption/lifecycle limits, not a new all-format claim or default-enable approval.

  Original specification and dated checkpoints (historical; pending wording
  below is superseded only within the scoped closure above):
  per-job A/53 extraction path that reads the original compressed video before
  GPU decode and publishes only timed CEA-608/708 records to the owning
  Standard-plugin session. Keep media payload, caption text, paths, and
  credentials out of diagnostics. The tap must not add a second selectable
  video PID to SageTV's media output, block transcoding, or change older-client
  behavior. Prove full GPU decode/deinterlace/encode and caption extraction in
  the same real FFmpeg gate, plus seek/flush/wrap/discontinuity, growing input,
  backpressure, teardown, and software fallback.

- [x] **MIM-FIXED-002 - Optional direct-session output contract.** After the
  Reconciled2026-11-20: Stale duplicate of the completed owning FFmpeg Plugin MIM-FIXED-002 Direct contract and this runtime's checked MIM-FIXED-003 Linux/Windows/HD200 matrix. Copy/transcode/captions/fallback/teardown retain their recorded limits. New adaptive quality and owned-DVD Windows work are independent, not retroactive blockers for this delivered contract.

  Original specification and dated checkpoints (historical; pending wording
  below is superseded only within the scoped closure above):
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

- [x] **MIM-PIPE-002 — Bounded Linux raw-media duplex forwarding** (Web097),
  2026-11-19. Deterministic diagnostic-burst/raw-write deadlock fails before,
  passes after nonblocking64KiB queue/POLLOUT correction; EOF6/control/isolation,
  real media/Copy/transcode and exact packages pass. Installed0.4.14 via normal
  FFmpeg0.1.27 manager39001/guarded restart171009; wrapper8fc256aa/JARdd1fc8e0,
  stock20/INI/engines verified repeatedly. Actual same-channel WTTW fullGPU
  natural194346 input848789016B/960s/28640phoneframes/exit0/ENDLIST/ownedcleanup
  and CBS494s, one-picture4/DVD20s/originalUK5 pass. This closes the bounded
  raw-duplex correction/available Linux acceptance, NOT a proven cause of the
  missing original84256 tail stall; exact file absent, logs/prefix remain Web097.
  Windows builds/CLI only, physical deferred; no engine/Core/publication change.
  Compact sibling Web artifacts/results/WEB-097/RUNTIME_ACCEPTANCE.md retains
  commands/builds/observations; its original-stall investigation stays separate.

- [x] **MIM-MAP-001 - Preserve automatic A/V during subtitle preservation
  (2026-11-09; parent container STOCK-005).** Unmapped stock Fixed plus newly
  appended subtitle-only map produced940bytes/no A/V; client cannot reconstruct
  omitted streams. MIM0.4.12 only extends subtitle maps when mappings already
  exist. Unmapped automatic A/V/first-compatible subtitle is preserved, no
  guessed stream selection or all-language promise. Both wrappers rebuild
  against byte-identical public0.4.11 engines; CLI/mapping/lifecycle/containment,
  real-media and paired plugin/package tests pass. Real manager installs local
  FFmpeg0.1.7, guarded232 restart20:15:58UTC retains stock hashes/settings.
  Non-Pro25 classic Fixed/DVB, absent Direct endpoint fallback and positive
  Direct transcode/DVB controls pass; HDMI independently confirms picture and
  readable captions. Compact parent STOCK-005 report retains exact runs/hashes.
  No publication or new Windows physical/all-vendor matrix claimed.

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
