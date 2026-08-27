# Unified Docker Build — v0.4.5

FFmpeg/MIM is built in the one supported development image and reusable
container owned by the sibling build-environment repository:

```text
image:     opensagetv-vibe-build-env:u26-j11
container: opensagetv-vibe-dev
```

There is no separate FFmpeg/MIM Dockerfile, builder image, bootstrap cache, or
runtime build container. The build-environment Dockerfile keeps its Linux and
Windows cross-toolchains as private stages and loads only its final image.

## First-time image build

From `opensagetv-vibe-build-env`:

```bash
./opensagetv-vibe-dev.sh image
./opensagetv-vibe-dev.sh ffmpeg-info
```

On Windows Docker Desktop:

```powershell
.\opensagetv-vibe-dev.ps1 image
.\opensagetv-vibe-dev.ps1 ffmpeg-info
```

The image contains these isolated target trees:

```text
/opt/sagetv/targets/linux64
/opt/sagetv/targets/win64
```

FFmpeg `n9.0.1` is pinned to commit
`bf1b838f2ab88b4f8fd83443325c782ea0e0f7fa`. The BtbN base and both target
images are pinned by digest in the build-environment Dockerfile.

## Component launchers

The launchers retained in this repository delegate to the sibling unified
wrapper and reuse `opensagetv-vibe-dev`:

```bash
./build_linux_sagetv_ffmpeg_static.sh
./build_windows_sagetv_ffmpeg_static.sh
./build_all_sagetv_ffmpeg_static.sh
```

Equivalently, invoke the unified wrapper directly:

```bash
../opensagetv-vibe-build-env/opensagetv-vibe-dev.sh ffmpeg-linux
../opensagetv-vibe-build-env/opensagetv-vibe-dev.sh ffmpeg-windows
```

On Windows, `build_all_sagetv_ffmpeg_static.bat` preserves its historical
Windows-x64-only behavior but delegates directly to the PowerShell unified
wrapper; WSL is no longer required for that launcher.

Outputs remain under:

```text
output/linux-x64/
output/windows-x64/
```

## Why x86 was removed

Win32/x86 would require another compiler and dependency tree. The supported
targets remain Linux/amd64 and Windows/amd64 only.
