# Security policy

Security fixes are applied to the current `main` branch.

Report vulnerabilities through GitHub private vulnerability reporting. Do not
open a public issue containing credentials, private media paths, device data,
or exploit details. Include the affected version, reproduction steps, impact,
and suggested mitigation when available.

MIM launches FFmpeg and accepts command lines from SageTV. Changes must retain
argument-vector execution, strict option normalization, bounded process-group
teardown, parent-death handling, and log/status redaction. Generated binaries
must be reproduced from the pinned FFmpeg source and reviewed unified toolchain;
do not substitute an unverified executable.
