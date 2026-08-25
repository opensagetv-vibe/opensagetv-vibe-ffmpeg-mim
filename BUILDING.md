# Building

Docker is the only host requirement. Required outputs are Linux/amd64 and Windows/amd64 FFmpeg/MIM packages from one Linux builder container.

- Both: `./code/docker/run_unified_builder.sh all`
- Linux only: `./code/docker/run_unified_builder.sh linux`
- Windows only: `./code/docker/run_unified_builder.sh windows`
- Install/rollback test: run `code/mim/tests/run_init_tests.sh` inside the builder.
- MIM control test: run `code/mim/tests/run_mim_tests.sh` inside the builder.

Windows Docker Desktop users run the same shell entry points from WSL. Unraid should not compile: transfer the release archive/image from a faster amd64 Docker host, verify `SHA256SUMS.txt`, and load it on Unraid.
