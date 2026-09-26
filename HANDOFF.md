# Handoff

## Standard takeover

Read `AGENTS.md`, `README.md`, `TASKS.md`, and `WORKFLOW.md`, then use the common
root commands. Changed-files packages live in `artifacts/downloads`. Install
means the non-Android MIM test suite and never enables MIM by default.

Current state: MIM 0.4.9 and FFmpeg `n9.0.1` build successfully for Linux amd64
and Windows amd64 in the single `opensagetv-vibe-dev` environment. Generated
artifacts and checksums live under `output/<target>` and are not committed.
The Linux/Windows toolchain Docker stages are owned by
`opensagetv-vibe-build-env`; this repository has no standalone Docker image or
container lifecycle.

Windows capability discovery is now physically commissioned on the `.212`
SageTV host. The former `_popen` probe was routed through `cmd.exe`, whose
first-quoted-token parsing broke the FFmpeg path under `Program Files` and
reported every backend unavailable. MIM now uses `CreateProcessW`, captures
the child output directly, and runs bounded one-frame hardware preflights.
The installed development wrapper selects Intel QSV; QSV and libx264 pass,
while the legacy Quadro K1100M fails modern NVENC initialization at
`cuMemAllocAsync` and is correctly rejected. The prior Windows wrapper remains
recoverable beside the runtime as
`ffmpeg_MIM.exe.before-win-probe-fix-20260926`.

The optional DVD transform ownership is explicit. MIM continues to expose
`dvdStreamTransform` through `--mim-capabilities` and implements
`-sagetvdiscstream`; the sibling SageTV FFmpeg plugin is the only component
that launches and manages that transform. Updated Core discovers a generic
`dvd_mpegts_v1` provider and otherwise stays native. Core contains no MIM JSON,
custom flags, executable lookup, or child-process code, and stock Core remains
supported by the plugin's ordinary Fixed/MIM path.

The repository syntax test and pinned Linux/Windows validation pass after this
ownership clarification (`n9.0.1`, Linux PASS, Windows PASS). No MIM source or
binary behavior changed.

MIM 0.4.9 restores the stock SageTV metadata-parser contract with current
FFmpeg. SageTV still sends its private `-dumpmetadata -v 2 -i FILE` command;
MIM removes the unavailable switch, forces FFmpeg info output, and converts
only stream-index delimiters from `Stream #N:M` to `Stream #N.M`. Both target
platforms buffer partial stderr lines, and Linux captures metadata stderr even
when normal FFmpeg stderr logging is disabled. Real FFmpeg 9 integration and
the full lifecycle/media suite pass. On the isolated `.232` server, a normal
full reindex restored the unmodified `Beauty And The Beast.mkv` as Matroska,
2:09:14, 2151 kbps, H.264, two AC3 tracks, and DVD subtitles. The guarded MIM
component installer set mode 0755, recorded a rollback backup, restarted only
the Vibe container, and passed its in-container status check. Stock `.175` was
not modified.

The matching stock MiniPlayer MKV playback failure is also corrected. SageTV's
legacy Push command omits `-vcodec` and requests `-f dvd`; the default copy
branch used to return before the existing DVD-to-MPEG-TS mapping, causing
FFmpeg to reject copied H.264 with return code 234 and emit zero bytes. The
mapping now applies to both copy branches, while `-fps_mode`/`-async` are
removed from stream-copy jobs. Real FFmpeg H.264/audio remux and full decode
pass. On `.25` against isolated `.232`, `Beauty And The Beast.mkv` visibly
rendered through Media3 hardware AVC, with advancing audio/video and 42 MB of
initial Push data; FF, REW, and pause/resume recovered in 573, 330, and 328 ms.
The source MKV and stock `.175` server were not modified. Screenshot evidence
is retained by the Android project as
`artifacts/firetv/20260910-024426_mim-mkv-remux-playback-restored.png`.
The revisioned component package
`opensagetv-vibe-mim-4741072da29b.tar.gz` was then installed through the guarded
component updater on `.232`; its archive SHA-256 is
`655809234f1aeb16c69c97bb56619c5822f389c78eab781bf861deeca64a9da0` and its
rollback backup is `.component-backups/mim-20260910-025236`. A post-install
physical run again passed startup, single FF (334 ms), single REW (327 ms), a
16-command mixed FF/REW stress sequence (364 ms), pause, and resume with the
hardware AVC decoder, valid surface, advancing video/audio output, and no
player error.
The final unified-build SHA-256 values are
`de3f724c661027d668c5f5d39553f09d0fff29c1b87c917d190b6700c50ba883`
for Linux `ffmpeg_MIM`,
`0f925398bb48c83c31bf8f9f7673c6c4450b770b720210a2065b5b803db1d856`
for Linux `ffmpeg.real`,
`bb717817cd5ab27e98d9a5a73dede85c48c8eb3561426def295b2c73d43f579e`
for Windows `SageTVTranscoder.exe`, and
`23e00040fdcc07e5e7dd6b4d70b59e5e233b5b2155cdfb20ecb1d0d66b7722e9`
for Windows `ffmpeg.real.exe`.

The 2026-09-09 stock-era thumbnail compatibility work passes native/static and
real FFmpeg 9 integration. The exact SageTV command, including private
`-minpix*` switches, numeric `-vsync`, removed `-deinterlace`, and the old
x:y:w:h `crop=0:8:0:0` expression, produced a valid 512x288 MJPEG after the
narrow thumbnail-only rewrite. The rebuilt Linux wrapper SHA-256 is
`2a178d9689fd46947ff8e84496e5dc160f87143a14292565d511889ed2fdfb84`.
The complete lifecycle/media suite passed with 1659 ms deliberate partial-join
first output and 235/270/303 ms repeated starts, plus full decode, teardown,
and orphan-process checks.
It is staged only in the isolated Vibe server appdata; the previous wrapper is
recoverable from `.component-backups/mim-thumbnail-crop-20260909-1222`.
Physical SageTV commissioning awaits a normal restart of `.232`; stock `.175`
was not modified and remains the primary Android compatibility baseline.
All maintained shell entry points carry executable Git metadata. Keep those
mode bits intact so fresh Linux and GitHub Actions checkouts can invoke the
scripts directly; repository CI uses `actions/checkout@v7`.

The 2026-09-05 clean target rebuild produced Linux `ffmpeg.real` SHA-256
`3e77761abc5a430f8ff43041255e7612e6c988ced373697e4772a79686634ae0`
and `ffmpeg_MIM` SHA-256
`67617a7a0de3ee0405f757a28c86490d570c9e10aec9a4e14cb9ddd9419047f7`.
Windows `ffmpeg.real.exe` and `SageTVTranscoder.exe` SHA-256 values are
`cc4e4ba91672ddcedf16be7526ca4c4bb5d5441b38ed92d4bfe25a87302af60f`
and `fd6e3923ce6dfa3e50fe7964a98cea614132e654c729917df96c7bf3d08c91e9`.
The complete non-Android 0.4.7 gate passes on the refreshed unified image:
installer backup/rollback, MIM option/control/crash containment, completed
media, growing join-in-progress, three repeated switches, full A/V decode, and
orphan-process checks. The measured first output was 1610 ms for the deliberately
partial join and 175-177 ms for the three complete repeated starts. Physical
Android hardware commissioning also passes; AMD/NVIDIA hardware and
long-duration promotion soak remain separate gates.

Version 0.4.7 makes the A/53 input-decode policy cross-vendor. With caption
preservation enabled, QSV, VAAPI, and NVENC jobs decode in software so an
accelerated MPEG-2 decoder cannot discard `AV_FRAME_DATA_A53_CC`; GPU
filter/upload/encode remains active and `-a53cc 1` carries the station's real
captions. This does not inject synthetic captions into live television. The
synthetic timestamp injector exists only in the Android test-fixture tooling.

`settings.ini` is explicitly checked out with LF endings. Keep that
`.gitattributes` rule: Windows CRLF conversion changes sourced shell values and
causes the unified toolchain pin check to fail during a fresh-clone build.

The complete non-Android suite passes. It covers installer backup/rollback,
argument mapping, `videorateadapt`/`inactivefile`, EOF and signal teardown,
failure containment, completed and growing MPEG-TS, joining a partially written
recording, repeated 59.94 fps starts, audio/video integrity, and orphan checks.
The 2026-08-28 Linux and Windows rebuild and subsequent install gate passed;
the test suite was also proven not to mutate the Linux release checksums.
On the commissioned Unraid Intel i915 host, VAAPI is the stable default and
physically passes completed-recording controls plus repeated live 2.1/5.1
changes through Android Media3, legacy ExoPlayer, and the tested GSY delegates.
The wrapper reports `backend=vaapi`, `encoder=h264_vaapi`, software input
decode, and hardware encode. It preserves A/53 captions with `-a53cc 1`.
Completed MPEG-TS seek requests preserve SageTV's exact requested time by
default. The bounded input-preroll/output-offset workaround remains opt-in
because it shifted visible timeline and caption presentation by about five
seconds on the commissioned path.
The final exact 0.4.6 deployment passed the Android Media3 hardware Fixed gate
for the Meet the Press recording and four live 2.1/5.1 changes. Fail-closed
status evidence recorded fresh matching jobs, `state=stopped`, and
`activeJobs=[]`; see the Android repository artifact
`artifacts/firetv/fixed-mim-20260829_234208/FIXED_MIM_MATRIX.json`.

The latest exact 0.4.7 seven-selection hardware-only matrix is retained in the
Android repository at
`artifacts/firetv/fixed-mim-20260830_180555/FIXED_MIM_MATRIX.json`. The safe
completed-file warm probe is 512 KiB/500 ms/1024 packets; the old 64
KiB/100 ms/128 packet cache caused about five seconds of A/53 drift. Row-14
Fixed/MIM and Push screenshots at `20260830-190054` and `20260830-190557`
show the stable middle cue within one second of the STV timeline without
covering it. The deployed MIM wrapper SHA-256 is
`4b73733245dfe4ae83a17b90f6e315f7bf2a36daf52290671ad16e057b138993`.
The repeated Fixed/MIM FF, REW, and FF_2 gate also passes: 328-331 ms A/V and
caption recovery per operation, 4 ms final cadence drift, and retained
post-seek screenshot `20260830-191129_caption-media3-fixed-visible.png`.

Intel QSV is retained as an experimental option but is not the commissioned
default: direct stress runs reproducibly exited with return code 139 on this
host. `linux_preference=vaapi,qsv,nvenc,software` and
`hardware_decode=false` are therefore deliberate. A forced invalid render
device selected and reported `backend=software` / `encoder=libx264`; Media3
then passed completed and live gates. Both live config copies were restored to
`/dev/dri/renderD128`, and a post-restore dry run selected VAAPI again.

`MIM_ENABLED=false` remains the mandatory stable default. The former IJK
fourth-transition and legacy-Exo software pause/play failures now pass repeated
physical commissioning on the Intel host. The exact 0.4.7 component package
was installed on the isolated Unraid test server through the appdata-only
update path; health and rollback checks passed without restarting protected
production SageTV or OpenDCT. Real AMD VAAPI and NVIDIA NVENC devices remain
unavailable. Static MIM tests validate command construction for those backends
but are not physical compatibility evidence.

The runtime image installs Linux files only. Windows artifacts remain deliverables for native Windows SageTV.
