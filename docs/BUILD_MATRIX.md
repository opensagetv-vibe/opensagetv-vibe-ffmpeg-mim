# Build Matrix — v0.4.5

| Launcher | Linux x64 | Windows x64 | Builder image |
|---|---:|---:|---|
| `build_linux_sagetv_ffmpeg_static.sh` | Yes | No | `sagetv-ffmpeg-mim-builder:9.0.1-v5` |
| `build_windows_sagetv_ffmpeg_static.sh` | No | Yes | same image |
| `build_all_sagetv_ffmpeg_static.sh` | Yes | Yes | same image |
| `build_all_sagetv_ffmpeg_static.bat` | No | Yes | same image via WSL/Docker |

Win32/x86 is intentionally removed in v0.3.9. The project no longer builds, configures, tests, or packages a 32-bit target.

Outputs:

```text
output/
├── linux-x64/
│   ├── ffmpeg_MIM
│   ├── ffmpeg.real
│   ├── ffprobe
│   ├── ffmpeg.real.ini
│   ├── ffmpeg_init.sh
│   ├── build_report.txt
│   └── SHA256SUMS.txt
└── windows-x64/
    ├── SageTVTranscoder.exe
    ├── ffmpeg.real.exe
    ├── ffprobe.exe
    ├── ffmpeg.real.ini
    ├── build_report.txt
    └── SHA256SUMS.txt
```

## Runtime build container

All target selections use one named container: `sagetv-ffmpeg-mim-builder`. An `all` build executes both targets sequentially inside that one container.
