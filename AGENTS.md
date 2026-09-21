# OpenSageTV Vibe FFmpeg/MIM contributor rules

Read `README.md`, `HANDOFF.md`, `TASKS.md`, and `WORKFLOW.md` first. Use the
single unified builder and keep MIM disabled by default until physical Android
playback and all GPU gates pass. `TASKS.md` is the only local backlog; remove
completed items and update `CHANGELOG.md`/`HANDOFF.md` with evidence.

Preserve FFmpeg pins, Linux/Windows outputs, LF settings, growing-file behavior,
option ordering, rollback, and software fallback. Do not create standalone
builder images or per-version/prompt/review documents.


## Stock-server test-control policy

- For any new testing, commissioning, diagnostic, or automation control, first
  implement or extend the stock-compatible `opensagetv-vibe-core-MCP-Plugin`
  using supported `sage.SageTV.api`/`apiUI` calls and verify it against an
  unmodified stock SageTV server.
- Do not patch `Sage.jar`, add private MiniClient events, or change Core merely
  to make a test easier. Existing public APIs, the bounded MCP bridge, and
  external test tooling are the required first option.
- Change Core only when the required production runtime behavior cannot be
  expressed through the stock plugin/API boundary. Document the proven API
  gap, keep the extension optional and negotiated with a safe stock fallback,
  and verify older clients and installations remain unaffected.
