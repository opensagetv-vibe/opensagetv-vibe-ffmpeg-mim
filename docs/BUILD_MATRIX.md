# Build Matrix — v0.4.5

| Launcher | Linux x64 | Windows x64 | Development image |
|---|---:|---:|---|
| `build_linux_sagetv_ffmpeg_static.sh` | Yes | No | `opensagetv-vibe-build-env:u26-j11` |
| `build_windows_sagetv_ffmpeg_static.sh` | No | Yes | same image |
| `build_all_sagetv_ffmpeg_static.sh` | Yes | Yes | same image |
| `build_all_sagetv_ffmpeg_static.bat` | No | Yes | same image via PowerShell/Docker |

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

## Reusable development container

All target selections use `opensagetv-vibe-dev`. An `all` component build
executes both targets sequentially in that existing container.
