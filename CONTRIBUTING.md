# Contributing to OpenSageTV Vibe FFmpeg/MIM

Read `AGENTS.md`, `README.md`, `HANDOFF.md`, `TASKS.md`, and `WORKFLOW.md`
before changing the project. `TASKS.md` is the only active backlog; completed
work belongs in `CHANGELOG.md` and current resume state belongs in `HANDOFF.md`.

Use the sibling unified development environment:

```text
dev.cmd test
dev.cmd validate
dev.cmd build
dev.cmd install
```

On Linux or WSL, use the equivalent `./dev.sh` commands. Do not add or publish
a component-specific builder image. Preserve both Linux/amd64 and
Windows/amd64 output contracts, LF configuration, FFmpeg source pins, option
ordering, growing-file behavior, process containment, hardware preflight, and
software fallback. MIM must remain disabled by default until all physical
promotion gates pass.

Never commit generated binaries, test media, credentials, private device data,
or runtime configuration. A hardware-acceleration claim requires runtime
backend/encoder evidence; CPU utilization alone is not sufficient.
