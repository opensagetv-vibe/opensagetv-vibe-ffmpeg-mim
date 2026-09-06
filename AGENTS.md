# OpenSageTV Vibe FFmpeg/MIM contributor rules

Read `README.md`, `HANDOFF.md`, `TASKS.md`, and `WORKFLOW.md` first. Use the
single unified builder and keep MIM disabled by default until physical Android
playback and all GPU gates pass. `TASKS.md` is the only local backlog; remove
completed items and update `CHANGELOG.md`/`HANDOFF.md` with evidence.

Preserve FFmpeg pins, Linux/Windows outputs, LF settings, growing-file behavior,
option ordering, rollback, and software fallback. Do not create standalone
builder images or per-version/prompt/review documents.
