# Common project workflow

Run `dev.cmd` or `./dev.sh` with `test`, `validate`, `build`, `install`, or
`all`. Build creates Linux and Windows outputs. Install means the non-Android
MIM lifecycle/media suite; it does not enable MIM in a server.

Put changed-files ZIPs in `artifacts/downloads`, use `update.cmd`/`update.sh`,
and create handoff packages with `create_ai_handoff_zip.cmd`. The sibling build
environment's `WORKFLOW.md` defines package verification and resume behavior.
