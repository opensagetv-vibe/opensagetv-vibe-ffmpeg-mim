# Unified Docker Builder — v0.4.5

The project uses one reusable Docker image:

```text
opensagetv-vibe-ffmpeg-mim-builder:9.0.1-v5
```

It contains two isolated BtbN target environments:

```text
/opt/sagetv/targets/linux64
/opt/sagetv/targets/win64
```

## One runtime build container

Normal project builds use one named container for every mode:

```text
opensagetv-vibe-ffmpeg-mim-builder
```

The image and container are different Docker objects:

```text
image:     opensagetv-vibe-ffmpeg-mim-builder:9.0.1-v5
container: opensagetv-vibe-ffmpeg-mim-builder
```

For an `all` build, that one container executes both targets sequentially:

```text
opensagetv-vibe-ffmpeg-mim-builder
    ├── linux-x64
    └── windows-x64
```

No target-specific runtime containers are created. The build container is started with `--rm`, so it is removed automatically at the end of the build.

The image is assembled from BtbN's actual FFmpeg-Builds environments:

```text
ghcr.io/btbn/ffmpeg-builds/base:latest
ghcr.io/btbn/ffmpeg-builds/linux64-gpl-9.0:latest
ghcr.io/btbn/ffmpeg-builds/win64-gpl-9.0:latest
```

Those BtbN images are referenced as temporary BuildKit stages. The bootstrap script does not intentionally `docker pull` or retain them as normal Docker Desktop image tags. The dedicated BuildKit bootstrap instance/cache is removed after the unified image is loaded unless `--keep-cache` is requested.

## Why x86 was removed

Win32/x86 added a separate compiler/toolchain/dependency environment and substantially increased image complexity and disk usage while modern hardware decode/encode support is primarily useful on 64-bit systems. v0.4.5 continues to support only Linux x64 and Windows x64.

There is no Win32 build stage, no `base-win32` build dependency, no Win32 FFmpeg output, and no Win32 MIM output.

## First-time image build

```bash
chmod +x *.sh code/docker/*.sh code/mim/tests/*.sh code/tools/*.py
./build_opensagetv_vibe_builder_image.sh
```

Force a rebuild after changing the Docker definition:

```bash
./build_opensagetv_vibe_builder_image.sh --rebuild
```

## Build Linux only

```bash
./build_linux_sagetv_ffmpeg_static.sh
```

This command **does not build/rebuild the Docker builder image**. It requires the existing `opensagetv-vibe-ffmpeg-mim-builder:9.0.1-v5` image and fails with a clear error if that image is missing. Only `build_opensagetv_vibe_builder_image.sh` changes/creates the builder image.

## Build both supported targets

```bash
./build_all_sagetv_ffmpeg_static.sh
```

This builds:

```text
linux-x64
windows-x64
```

## Build Windows x64 only from Linux/WSL

```bash
./build_windows_sagetv_ffmpeg_static.sh
```

From Windows Command Prompt/PowerShell, the `.bat` launcher enters WSL and uses the same Docker builder:

```bat
build_all_sagetv_ffmpeg_static.bat
```

## Removing images from older versions

After the v0.4.5 project is used with the existing v5 unified image, the bootstrap attempts to remove BtbN/source tags and old SageTV builder tags from previous versions, including legacy Win32 tags. If any remain visible in Docker Desktop, remove them manually with:

```bash
./cleanup_old_opensagetv_vibe_build_images.sh
```

That helper intentionally knows the old Win32 image names only so it can delete them.
