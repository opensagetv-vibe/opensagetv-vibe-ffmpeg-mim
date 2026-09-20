#!/usr/bin/env python3
"""Create deterministic plugin-owned FFmpeg/MIM runtime archives."""

from __future__ import annotations

import argparse
import hashlib
import os
import stat
import zipfile
from pathlib import Path


PREFIX = Path("plugins") / "SageTVFFmpegPlugin" / "runtime"
ZIP_EPOCH = (1980, 1, 1, 0, 0, 0)


def require(path: Path) -> Path:
    if not path.is_file():
        raise SystemExit(f"required file missing: {path}")
    return path


def digest(path: Path, algorithm: str) -> str:
    value = hashlib.new(algorithm)
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def add_file(archive: zipfile.ZipFile, source: Path, destination: Path, executable: bool) -> None:
    info = zipfile.ZipInfo(destination.as_posix(), ZIP_EPOCH)
    mode = 0o755 if executable else 0o644
    info.create_system = 3
    info.external_attr = (stat.S_IFREG | mode) << 16
    info.compress_type = zipfile.ZIP_DEFLATED
    archive.writestr(info, source.read_bytes())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", required=True, choices=["linux-x64", "windows-x64"])
    parser.add_argument("--version", required=True)
    parser.add_argument("--repo", default=".")
    parser.add_argument("--output-dir", default="output/plugin")
    args = parser.parse_args()

    repo = Path(args.repo).resolve()
    built = repo / "output" / args.target
    output = (repo / args.output_dir).resolve()
    output.mkdir(parents=True, exist_ok=True)
    default_ini = require(repo / "ffmpeg.real.ini")

    if args.target == "linux-x64":
        files = [
            (require(built / "ffmpeg_MIM"), "ffmpeg_MIM", True),
            (require(built / "ffmpeg.real"), "ffmpeg.real", True),
            (require(built / "ffprobe"), "ffprobe", True),
        ]
        asset = output / f"OpenSageTVVibeMIMRuntimeLinux-{args.version}.zip"
    else:
        files = [
            (require(built / "SageTVTranscoder.exe"), "ffmpeg_MIM.exe", True),
            (require(built / "ffmpeg.real.exe"), "ffmpeg.real.exe", True),
            (require(built / "ffprobe.exe"), "ffprobe.exe", True),
        ]
        asset = output / f"OpenSageTVVibeMIMRuntimeWindowsx64-{args.version}.zip"

    files.append((default_ini, "ffmpeg.real.ini.default", False))
    notices = repo / "THIRD_PARTY_NOTICES.md"
    if notices.is_file():
        files.append((notices, notices.name, False))

    temporary = asset.with_suffix(asset.suffix + ".tmp")
    with zipfile.ZipFile(temporary, "w") as archive:
        for source, name, executable in sorted(files, key=lambda item: item[1]):
            add_file(archive, source, PREFIX / name, executable)
    os.replace(temporary, asset)

    print(asset)
    print("MD5", digest(asset, "md5"))
    print("SHA256", digest(asset, "sha256"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
