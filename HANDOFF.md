# Handoff

Current state: source and documentation extracted; fresh Linux amd64 and Windows amd64 outputs build successfully with the single BtbN-derived builder container. Generated artifacts and checksums live under `output/<target>` and are not committed.

The installer backup/rollback test passes. The broader MIM test currently fails when the fake FFmpeg child does not observe forwarded `videorateadapt` before `inactivefile`; prior commissioning also observed intermittent black video and initial stalls. Therefore `MIM_ENABLED=false` is the mandatory stable default. Do not promote it until real growing-live-TV fixtures pass repeated startup, switch, EOF, and teardown tests on Intel, AMD, and NVIDIA hardware.

The runtime image installs Linux files only. Windows artifacts remain deliverables for native Windows SageTV.
