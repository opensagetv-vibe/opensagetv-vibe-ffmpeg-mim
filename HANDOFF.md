# Handoff

## Standard takeover

Read `AGENTS.md`, `README.md`, `TASKS.md`, and `WORKFLOW.md`, then use the common
root commands. Changed-files packages live in `artifacts/downloads`. Install
means the non-Android MIM test suite and never enables MIM by default.

Current state: MIM 0.4.8 and FFmpeg `n9.0.1` build successfully for Linux amd64
and Windows amd64 in the single `opensagetv-vibe-dev` environment. Generated
artifacts and checksums live under `output/<target>` and are not committed.
The Linux/Windows toolchain Docker stages are owned by
`opensagetv-vibe-build-env`; this repository has no standalone Docker image or
container lifecycle.

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
